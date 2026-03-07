import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:finzy/widgets/app_icon.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import '../../services/jellyfin_client.dart';
import '../models/hub.dart';
import '../models/media_metadata.dart';
import '../models/library_sort.dart';
import '../providers/settings_provider.dart';
import '../services/settings_service.dart' show EpisodePosterMode, ViewMode;
import '../utils/provider_extensions.dart';
import '../utils/app_logger.dart';
import '../utils/grid_size_calculator.dart';
import '../utils/layout_constants.dart';
import '../widgets/focusable_filter_chip.dart';
import '../widgets/focusable_media_card.dart';
import '../widgets/media_grid_delegate.dart';
import '../widgets/desktop_app_bar.dart';
import '../widgets/overlay_sheet.dart';
import '../focus/dpad_navigator.dart';
import '../focus/input_mode_tracker.dart';
import '../focus/key_event_utils.dart';
import '../mixins/grid_focus_node_mixin.dart';
import 'libraries/sort_bottom_sheet.dart';
import 'libraries/state_messages.dart';
import '../mixins/refreshable.dart';
import '../i18n/strings.g.dart';

/// Screen to display full content of a recommendation hub
class HubDetailScreen extends StatefulWidget {
  final Hub hub;

  const HubDetailScreen({super.key, required this.hub});

  @override
  State<HubDetailScreen> createState() => _HubDetailScreenState();
}

class _HubDetailScreenState extends State<HubDetailScreen> with Refreshable, GridFocusNodeMixin {
  JellyfinClient get client => _getClientForHub();

  List<MediaMetadata> _items = [];
  List<MediaMetadata> _filteredItems = [];
  List<LibrarySort> _sortOptions = [];
  LibrarySort? _selectedSort;
  bool _isSortDescending = false;
  bool _isLoading = false;
  String? _errorMessage;

  late final FocusNode _firstItemFocusNode = FocusNode(debugLabel: 'hub_detail_first_item');
  late final FocusNode _backButtonFocusNode = FocusNode(debugLabel: 'hub_detail_back');
  late final FocusNode _sortButtonFocusNode = FocusNode(debugLabel: 'hub_detail_sort');
  late final FocusNode _screenFocusNode = FocusNode(debugLabel: 'hub_detail_screen');
  bool _isAppBarFocused = false;
  final ScrollController _scrollController = ScrollController();

  /// Key for getting a context below OverlaySheetHost
  final GlobalKey _overlayChildKey = GlobalKey();

  /// Get the correct JellyfinClient for this hub's server
  JellyfinClient _getClientForHub() {
    return context.getClientWithFallback(widget.hub.serverId);
  }

  @override
  void initState() {
    super.initState();
    _backButtonFocusNode.addListener(_onAppBarFocusChange);
    _sortButtonFocusNode.addListener(_onAppBarFocusChange);
    // Start with items already loaded in the hub
    _items = widget.hub.items;
    _filteredItems = widget.hub.items;
    // Load more items if available
    if (widget.hub.more) {
      _loadMoreItems();
    }
    // Load sorts based on the library type
    _loadSorts();
    // Focus first grid item when screen opens (consistent with browse, favorites, etc.)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (InputModeTracker.isKeyboardMode(context) && _filteredItems.isNotEmpty) {
        _focusGridItem(0);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _backButtonFocusNode.removeListener(_onAppBarFocusChange);
    _sortButtonFocusNode.removeListener(_onAppBarFocusChange);
    _firstItemFocusNode.dispose();
    _backButtonFocusNode.dispose();
    _sortButtonFocusNode.dispose();
    _screenFocusNode.dispose();
    disposeGridFocusNodes();
    super.dispose();
  }

  void _onAppBarFocusChange() {
    if (!mounted) return;
    final hasFocus = _backButtonFocusNode.hasFocus || _sortButtonFocusNode.hasFocus;
    if (hasFocus && !_isAppBarFocused) {
      setState(() => _isAppBarFocused = true);
    } else if (!hasFocus && _isAppBarFocused) {
      setState(() => _isAppBarFocused = false);
    }
  }

  void _focusGrid() {
    if (_filteredItems.isEmpty) return;
    final targetIndex =
        shouldRestoreGridFocus && lastFocusedGridIndex! < _filteredItems.length ? lastFocusedGridIndex! : 0;
    _focusGridItem(targetIndex);
  }

  /// Estimate scroll offset to bring the grid/list item at [index] into view.
  double _estimateScrollOffsetForIndex(int index) {
    if (!mounted) return 0;
    final settings = context.read<SettingsProvider>();
    const topOffset = 72.0; // kToolbarHeight + SliverPadding top

    if (settings.viewMode == ViewMode.list) {
      const listRowHeight = 100.0; // Approximate height of list item (poster + text)
      return (topOffset + index * listRowHeight).clamp(0.0, double.infinity);
    }

    final density = settings.libraryDensity;
    final episodePosterMode = settings.episodePosterMode;
    final hasEpisodes = _filteredItems.any((item) => item.usesWideAspectRatio(episodePosterMode));
    final hasNonEpisodes = _filteredItems.any((item) => !item.usesWideAspectRatio(episodePosterMode));
    final isMixedHub = hasEpisodes && hasNonEpisodes;
    final isEpisodeOnlyHub = hasEpisodes && !hasNonEpisodes;
    final useWideLayout =
        episodePosterMode == EpisodePosterMode.episodeThumbnail && (isEpisodeOnlyHub || isMixedHub);

    final availableWidth = MediaQuery.of(context).size.width - 16;
    final maxExtent = GridSizeCalculator.getMaxCrossAxisExtent(context, density);
    final effectiveMaxExtent = useWideLayout ? maxExtent * 1.8 : maxExtent;
    final columnCount = GridSizeCalculator.getColumnCount(availableWidth, effectiveMaxExtent);
    final cellWidth = availableWidth / columnCount;
    final aspectRatio = useWideLayout ? GridLayoutConstants.episodeGridCellAspectRatio : GridLayoutConstants.posterAspectRatio;
    final cellHeight = cellWidth / aspectRatio;
    final rowHeight = cellHeight + GridLayoutConstants.mainAxisSpacing;
    final row = index ~/ columnCount;
    return (topOffset + row * rowHeight).clamp(0.0, double.infinity);
  }

  void _focusGridItem(int index) {
    if (index < 0 || index >= _filteredItems.length) return;

    void doFocus({int retryCount = 0}) {
      if (!mounted) return;
      final node = index == 0 ? _firstItemFocusNode : getGridItemFocusNode(index, prefix: 'hub_detail_item');
      final ctx = node.context;

      if (ctx == null && retryCount < 3 && _scrollController.hasClients) {
        final targetOffset = _estimateScrollOffsetForIndex(index);
        final maxExtent = _scrollController.position.maxScrollExtent;
        final clamped = targetOffset.clamp(0.0, maxExtent);
        appLogger.d('HubDetailScreen: _focusGridItem index=$index ctx=null retry=$retryCount scrollTo=$clamped maxExtent=$maxExtent');
        _scrollController.jumpTo(clamped);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) doFocus(retryCount: retryCount + 1);
        });
        return;
      }

      if (!node.hasFocus) node.requestFocus();
    }

    appLogger.d('HubDetailScreen: _focusGridItem index=$index');
    doFocus();
  }

  void _navigateToAppBar() {
    appLogger.d('HubDetailScreen: _navigateToAppBar (Up from first row)');
    setState(() => _isAppBarFocused = true);
    _backButtonFocusNode.requestFocus();
    final disableAnimations = context.read<SettingsProvider>().disableAnimations;
    if (disableAnimations) {
      _scrollController.jumpTo(0);
    } else {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  void _handleBackFromContent() {
    Navigator.pop(context);
  }

  KeyEventResult _handleBackButtonKeyEvent(FocusNode _, KeyEvent event) {
    final key = event.logicalKey;

    // Back key only (not Left) - fullscreen page, Left should not exit
    final backResult = handleBackOrLeftKeyAction(event, () => Navigator.pop(context));
    if (backResult != KeyEventResult.ignored) return backResult;

    if (!event.isActionable) return KeyEventResult.ignored;

    if (event is KeyDownEvent && key.isSelectKey) {
      Navigator.pop(context);
      return KeyEventResult.handled;
    }
    if (key.isDownKey && _filteredItems.isNotEmpty) {
      _focusGrid();
      return KeyEventResult.handled;
    }
    if (key.isRightKey) {
      _sortButtonFocusNode.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _loadSorts() async {
    try {
      final client = _getClientForHub();
      final hubType = widget.hub.type;

      final sorts = await client.getLibrarySorts('', libraryType: hubType);

      if (!mounted) return;
      setState(() {
        _sortOptions = sorts.isNotEmpty ? sorts : _getDefaultSortOptions();
      });
      appLogger.d('HubDetailScreen: loaded sorts=${_sortOptions.map((s) => s.key).join(', ')}');
    } catch (e) {
      appLogger.e('Failed to load sorts', error: e);
      if (!mounted) return;
      setState(() {
        _sortOptions = _getDefaultSortOptions();
      });
    }
  }

  List<LibrarySort> _getDefaultSortOptions() {
    return [
      LibrarySort(key: 'titleSort', title: t.hubDetail.title, defaultDirection: 'asc'),
      LibrarySort(key: 'year', descKey: 'year:desc', title: t.hubDetail.releaseYear, defaultDirection: 'desc'),
      LibrarySort(key: 'addedAt', descKey: 'addedAt:desc', title: t.hubDetail.dateAdded, defaultDirection: 'desc'),
      LibrarySort(key: 'rating', descKey: 'rating:desc', title: t.hubDetail.rating, defaultDirection: 'desc'),
    ];
  }

  void _applySort() {
    appLogger.d('HubDetailScreen: _applySort called sort=${_selectedSort?.key} desc=$_isSortDescending itemCount=${_items.length}');
    setState(() {
      _filteredItems = List.from(_items);

      // Apply sorting - support both legacy keys and Jellyfin API keys
      if (_selectedSort != null) {
        final sortKey = _selectedSort!.key;
        _filteredItems.sort((a, b) {
          int comparison = 0;

          switch (sortKey) {
            case 'titleSort':
            case 'title':
            case 'SortName':
              comparison = (a.titleSort ?? a.title).compareTo(b.titleSort ?? b.title);
              break;
            case 'addedAt':
            case 'DateCreated':
              comparison = (a.addedAt ?? 0).compareTo(b.addedAt ?? 0);
              break;
            case 'originallyAvailableAt':
            case 'year':
            case 'PremiereDate':
              comparison = (a.year ?? 0).compareTo(b.year ?? 0);
              break;
            case 'rating':
            case 'CommunityRating':
            case 'CriticRating':
              comparison = (a.rating ?? 0).compareTo(b.rating ?? 0);
              break;
            case 'DatePlayed':
              comparison = (a.lastPlayedAt ?? 0).compareTo(b.lastPlayedAt ?? 0);
              break;
            case 'PlayCount':
              comparison = (a.playCount ?? 0).compareTo(b.playCount ?? 0);
              break;
            case 'Runtime':
              comparison = (a.duration ?? 0).compareTo(b.duration ?? 0);
              break;
            case 'Random':
              comparison = 0; // Keep order, or use Random().nextDouble().sign
              break;
            default:
              comparison = a.title.compareTo(b.title);
          }

          return _isSortDescending ? -comparison : comparison;
        });
        appLogger.d('HubDetailScreen: sort applied, filteredCount=${_filteredItems.length}');
      } else {
        appLogger.d('HubDetailScreen: no sort selected, keeping original order');
      }
    });
  }

  void _showSortBottomSheet() {
    final overlayContext = _overlayChildKey.currentContext ?? context;
    final clearFocusNode = FocusNode(debugLabel: 'SortSheetClear');
    OverlaySheetController.of(overlayContext).show(
      initialFocusNode: clearFocusNode,
      builder: (context) => SortBottomSheet(
        sortOptions: _sortOptions,
        selectedSort: _selectedSort,
        isSortDescending: _isSortDescending,
        onSortChanged: (sort, descending) {
          appLogger.d('HubDetailScreen: onSortChanged sort=${sort.key} desc=$descending');
          setState(() {
            _selectedSort = sort;
            _isSortDescending = descending;
          });
          _applySort();
        },
        onClear: () {
          setState(() {
            // Reset to no sorting (original order)
            _selectedSort = null;
            _isSortDescending = false;
          });
          _applySort();
        },
        clearFocusNode: clearFocusNode,
      ),
    ).whenComplete(() {
      clearFocusNode.dispose();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_filteredItems.isNotEmpty) {
          _focusGrid();
        } else {
          _sortButtonFocusNode.requestFocus();
        }
      });
    });
  }

  Future<void> _loadMoreItems() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = _getClientForHub();

      final items = await client.getHubContent(widget.hub.hubKey, hubType: widget.hub.type);

      if (!mounted) return;
      if (items.isEmpty) {
        // Hub content endpoint returned nothing; keep initial items
        setState(() => _isLoading = false);
        return;
      }
      setState(() {
        _items = items;
        _filteredItems = items;
        _isLoading = false;
      });

      _applySort();

      appLogger.d('Loaded ${items.length} items for hub: ${widget.hub.title}');
    } catch (e) {
      appLogger.e('Failed to load hub content', error: e);
      if (!mounted) return;
      setState(() {
        _errorMessage = t.messages.errorLoading(error: e.toString());
        _isLoading = false;
      });
    }
  }

  void _handleItemRefresh(String itemId) {
    // Refresh the specific item in the list
    setState(() {
      final index = _items.indexWhere((item) => item.itemId == itemId);
      if (index != -1) {
        // The item will be refreshed by the MediaCard itself
        appLogger.d('Item refresh requested for: $itemId');
      }
    });
  }

  @override
  void refresh() {
    _loadMoreItems();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context);
      },
      child: OverlaySheetHost(
        child: Focus(
          focusNode: _screenFocusNode,
          autofocus: true,
          onKeyEvent: (node, event) {
            if (!event.isActionable) return KeyEventResult.ignored;
            if (event.logicalKey.isBackKey) {
              return handleBackOrLeftKeyAction(event, () => Navigator.pop(context));
            }
            if (event.logicalKey.isDownKey && _filteredItems.isNotEmpty) {
              _focusGrid();
              return KeyEventResult.handled;
            }
            if (event.logicalKey.isSelectKey && _filteredItems.isNotEmpty) {
              _focusGrid();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Scaffold(
          key: _overlayChildKey,
          body: CustomScrollView(
            controller: _scrollController,
            // ignore: deprecated_member_use
            cacheExtent: context.read<SettingsProvider>().gridPreloadCacheExtent,
            clipBehavior: Clip.none,
            slivers: [
              CustomAppBar(
                title: Text(widget.hub.title),
                leading: Focus(
                  focusNode: _backButtonFocusNode,
                  onKeyEvent: _handleBackButtonKeyEvent,
                  child: ListenableBuilder(
                    listenable: _backButtonFocusNode,
                    builder: (context, _) {
                      final isFocused = InputModeTracker.isKeyboardMode(context) && _backButtonFocusNode.hasFocus;
                      return Container(
                        decoration: isFocused
                            ? BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                shape: BoxShape.circle,
                              )
                            : null,
                        child: Semantics(
                          label: MaterialLocalizations.of(context).backButtonTooltip,
                          button: true,
                          excludeSemantics: true,
                          child: IconButton(
                            icon: const AppIcon(Symbols.arrow_back_rounded, fill: 1),
                            onPressed: () => Navigator.pop(context),
                            tooltip: null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                pinned: true,
                actions: [
                  const SizedBox(width: 8),
                  FocusableFilterChip(
                    focusNode: _sortButtonFocusNode,
                    icon: Symbols.sort_rounded,
                    label: _selectedSort?.title ?? t.libraries.sort,
                    onPressed: _showSortBottomSheet,
                    onNavigateDown: _filteredItems.isNotEmpty ? _focusGrid : null,
                    onNavigateLeft: () => _backButtonFocusNode.requestFocus(),
                    onBack: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
              if (_errorMessage != null)
                SliverFillRemaining(
                  child: ErrorStateWidget(
                    message: _errorMessage!,
                    icon: Symbols.error_outline_rounded,
                    onRetry: _loadMoreItems,
                  ),
                )
              else if (_filteredItems.isEmpty && _isLoading)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              else if (_filteredItems.isEmpty)
                SliverFillRemaining(child: Center(child: Text(t.hubDetail.noItemsFound)))
              else
                Builder(
                  builder: (context) {
                    final settings = context.watch<SettingsProvider>();
                    final episodePosterMode = settings.episodePosterMode;
                    final isListMode = settings.viewMode == ViewMode.list;

                    // Determine hub content type for layout decisions
                    final hasEpisodes = _filteredItems.any((item) => item.usesWideAspectRatio(episodePosterMode));
                    final hasNonEpisodes = _filteredItems.any((item) => !item.usesWideAspectRatio(episodePosterMode));

                    // Mixed hub = has both episodes AND non-episodes
                    final isMixedHub = hasEpisodes && hasNonEpisodes;

                    // Episode-only = all items are episodes with thumbnails
                    final isEpisodeOnlyHub = hasEpisodes && !hasNonEpisodes;

                    // Use 16:9 for episode-only hubs OR mixed hubs (with episode thumbnail mode)
                    final useWideLayout =
                        episodePosterMode == EpisodePosterMode.episodeThumbnail && (isEpisodeOnlyHub || isMixedHub);

                    Widget sliver;
                    if (isListMode) {
                      sliver = SliverList.builder(
                        itemCount: _filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = _filteredItems[index];
                          final focusNode = index == 0
                              ? _firstItemFocusNode
                              : getGridItemFocusNode(index, prefix: 'hub_detail_item');
                          final isFirstRow = index == 0;
                          final isLastRow = index == _filteredItems.length - 1;

                          return FocusableMediaCard(
                            focusNode: focusNode,
                            item: item,
                            onRefresh: _handleItemRefresh,
                            onNavigateUp: isFirstRow ? _navigateToAppBar : () => _focusGridItem(index - 1),
                            onNavigateDown: isLastRow ? null : () => _focusGridItem(index + 1),
                            onNavigateLeft: null,
                            onNavigateRight: null,
                            onBack: _handleBackFromContent,
                            onFocusChange: (hasFocus) => trackGridItemFocus(index, hasFocus),
                            mixedHubContext: isMixedHub,
                            autoScroll: true,
                            scrollTopOffset: isFirstRow ? 72 : null,
                          );
                        },
                      );
                    } else {
                      sliver = SliverLayoutBuilder(
                        builder: (context, constraints) {
                          final maxExtent = GridSizeCalculator.getMaxCrossAxisExtent(context, settings.libraryDensity);
                          final effectiveMaxExtent = useWideLayout ? maxExtent * 1.8 : maxExtent;
                          final columnCount = GridSizeCalculator.getColumnCount(
                            constraints.crossAxisExtent,
                            effectiveMaxExtent,
                          );

                          return SliverGrid(
                            gridDelegate: MediaGridDelegate.createDelegate(
                              context: context,
                              density: settings.libraryDensity,
                              useWideAspectRatio: useWideLayout,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final item = _filteredItems[index];
                                final focusNode = index == 0
                                    ? _firstItemFocusNode
                                    : getGridItemFocusNode(index, prefix: 'hub_detail_item');
                                final isFirstRow = GridSizeCalculator.isFirstRow(index, columnCount);
                                final belowIndex = index + columnCount;
                                final isLastRow = belowIndex >= _filteredItems.length;
                                final isFirstColumn = index % columnCount == 0;
                                final isLastColumn = index % columnCount == columnCount - 1;

                                return FocusableMediaCard(
                                  focusNode: focusNode,
                                  item: item,
                                  onRefresh: _handleItemRefresh,
                                  onNavigateUp: isFirstRow ? _navigateToAppBar : () => _focusGridItem(index - columnCount),
                                  onNavigateDown: isLastRow ? null : () => _focusGridItem(belowIndex),
                                  onNavigateLeft: isFirstColumn ? null : () => _focusGridItem(index - 1),
                                  onNavigateRight: isLastColumn ? null : () => _focusGridItem(index + 1),
                                  onBack: _handleBackFromContent,
                                  onFocusChange: (hasFocus) => trackGridItemFocus(index, hasFocus),
                                  mixedHubContext: isMixedHub,
                                  autoScroll: true,
                                  scrollTopOffset: isFirstRow ? 72 : null,
                                );
                              },
                              childCount: _filteredItems.length,
                            ),
                          );
                        },
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                      sliver: sliver,
                    );
                  },
                ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
