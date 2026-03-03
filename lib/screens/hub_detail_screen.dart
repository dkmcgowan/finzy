import 'package:flutter/material.dart';
import 'package:finzy/widgets/app_icon.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import '../../services/jellyfin_client.dart';
import '../models/hub.dart';
import '../models/media_metadata.dart';
import '../models/library_sort.dart';
import '../providers/settings_provider.dart';
import '../services/settings_service.dart';
import '../utils/provider_extensions.dart';
import '../utils/app_logger.dart';
import '../utils/grid_size_calculator.dart';
import '../widgets/focusable_media_card.dart';
import '../widgets/media_grid_delegate.dart';
import '../widgets/desktop_app_bar.dart';
import '../widgets/overlay_sheet.dart';
import 'package:flutter/services.dart';
import '../focus/dpad_navigator.dart';
import '../focus/focus_theme.dart';
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

  /// Key for getting a context below OverlaySheetHost
  final GlobalKey _overlayChildKey = GlobalKey();

  /// Get the correct JellyfinClient for this hub's server
  JellyfinClient _getClientForHub() {
    return context.getClientForServer(widget.hub.serverId!);
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
    // No auto-focus: start with app bar (back button) focused. Down from app bar goes to grid.
  }

  @override
  void dispose() {
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
    if (targetIndex == 0) {
      _firstItemFocusNode.requestFocus();
    } else {
      getGridItemFocusNode(targetIndex, prefix: 'hub_detail_item').requestFocus();
    }
  }

  void _navigateToAppBar() {
    setState(() => _isAppBarFocused = true);
    // Focus back button first; Right from back goes to sort
    _backButtonFocusNode.requestFocus();
  }

  void _handleBackFromContent() {
    Navigator.pop(context);
  }

  KeyEventResult _handleBackButtonKeyEvent(FocusNode _, KeyEvent event) {
    final key = event.logicalKey;

    final backResult = handleBackOrLeftKeyAction(event, () => Navigator.pop(context));
    if (backResult != KeyEventResult.ignored) return backResult;

    if (event is! KeyDownEvent) return KeyEventResult.ignored;

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

  KeyEventResult _handleSortButtonKeyEvent(FocusNode _, KeyEvent event) {
    final key = event.logicalKey;

    final backResult = handleBackOrLeftKeyAction(event, () => Navigator.pop(context));
    if (backResult != KeyEventResult.ignored) return backResult;

    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (key.isDownKey) {
      _focusGrid();
      return KeyEventResult.handled;
    }
    if (key.isLeftKey) {
      _backButtonFocusNode.requestFocus();
      return KeyEventResult.handled;
    }
    if (key.isSelectKey) {
      _showSortBottomSheet();
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
    setState(() {
      _filteredItems = List.from(_items);

      // Apply sorting
      if (_selectedSort != null) {
        final sortKey = _selectedSort!.key;
        _filteredItems.sort((a, b) {
          int comparison = 0;

          switch (sortKey) {
            case 'titleSort':
            case 'title':
              comparison = a.title.compareTo(b.title);
              break;
            case 'addedAt':
              comparison = (a.addedAt ?? 0).compareTo(b.addedAt ?? 0);
              break;
            case 'originallyAvailableAt':
            case 'year':
              comparison = (a.year ?? 0).compareTo(b.year ?? 0);
              break;
            case 'rating':
              comparison = (a.rating ?? 0).compareTo(b.rating ?? 0);
              break;
            default:
              comparison = a.title.compareTo(b.title);
          }

          return _isSortDescending ? -comparison : comparison;
        });
      }
    });
  }

  void _showSortBottomSheet() {
    final overlayContext = _overlayChildKey.currentContext ?? context;
    OverlaySheetController.of(overlayContext).show(
      builder: (context) => SortBottomSheet(
        sortOptions: _sortOptions,
        selectedSort: _selectedSort,
        isSortDescending: _isSortDescending,
        onSortChanged: (sort, descending) {
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
      ),
    );
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
    final isKeyboardMode = InputModeTracker.isKeyboardMode(context);
    final sortButtonFocused = isKeyboardMode && _sortButtonFocusNode.hasFocus;

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
            if (event.logicalKey.isBackKey || event.logicalKey.isLeftKey) {
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
            clipBehavior: Clip.none,
            slivers: [
              CustomAppBar(
                title: Text(widget.hub.title),
                leading: Focus(
                  focusNode: _backButtonFocusNode,
                  onKeyEvent: _handleBackButtonKeyEvent,
                  child: IconButton(
                    icon: const AppIcon(Symbols.arrow_back_rounded, fill: 1),
                    onPressed: () => Navigator.pop(context),
                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  ),
                ),
                pinned: true,
                actions: [
                  Focus(
                    focusNode: _sortButtonFocusNode,
                    onKeyEvent: _handleSortButtonKeyEvent,
                    child: Container(
                      decoration: FocusTheme.focusBackgroundDecoration(isFocused: sortButtonFocused, borderRadius: 20),
                      child: IconButton(
                        icon: AppIcon(Symbols.swap_vert_rounded, fill: 1, semanticLabel: t.libraries.sort),
                        onPressed: _showSortBottomSheet,
                      ),
                    ),
                  ),
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

                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) {
                          final maxExtent = GridSizeCalculator.getMaxCrossAxisExtentWithPadding(
                            context,
                            settings.libraryDensity,
                            16,
                          );
                          final columnCount = GridSizeCalculator.getColumnCount(
                            constraints.crossAxisExtent,
                            useWideLayout ? maxExtent * 1.8 : maxExtent,
                          );

                          return SliverGrid(
                            gridDelegate: MediaGridDelegate.createDelegate(
                              context: context,
                              density: settings.libraryDensity,
                              usePaddingAware: true,
                              horizontalPadding: 16,
                              useWideAspectRatio: useWideLayout,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final item = _filteredItems[index];
                                final focusNode = index == 0
                                    ? _firstItemFocusNode
                                    : getGridItemFocusNode(index, prefix: 'hub_detail_item');
                                final isFirstRow = GridSizeCalculator.isFirstRow(index, columnCount);
                                final isFirstColumn = GridSizeCalculator.isFirstColumn(index, columnCount);

                                return FocusableMediaCard(
                                  focusNode: focusNode,
                                  item: item,
                                  onRefresh: _handleItemRefresh,
                                  onNavigateUp: isFirstRow ? _navigateToAppBar : null,
                                  onNavigateLeft: isFirstColumn ? _handleBackFromContent : null,
                                  onBack: _handleBackFromContent,
                                  onFocusChange: (hasFocus) => trackGridItemFocus(index, hasFocus),
                                  mixedHubContext: isMixedHub,
                                );
                              },
                              childCount: _filteredItems.length,
                            ),
                          );
                        },
                      ),
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
