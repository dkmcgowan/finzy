import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../../focus/dpad_navigator.dart';
import '../../../../services/jellyfin_client.dart';
import '../../../models/media_metadata.dart';
import '../../../models/library_filter.dart';
import '../../../models/first_character.dart';
import '../../../models/library_sort.dart';
import '../../../providers/settings_provider.dart';
import '../../../utils/app_logger.dart';
import '../../../utils/error_message_utils.dart';
import '../../../utils/grid_size_calculator.dart';
import '../../../utils/layout_constants.dart';
import '../../../widgets/alpha_jump_bar.dart';
import '../../../widgets/alpha_jump_helper.dart';
import '../../../widgets/alpha_scroll_handle.dart';
import '../../../widgets/focusable_media_card.dart';
import '../../../widgets/focusable_filter_chip.dart';
import '../../../widgets/media_grid_delegate.dart';
import '../../../widgets/overlay_sheet.dart';
import '../../../mixins/library_tab_focus_mixin.dart';
import '../filters_bottom_sheet.dart';
import '../sort_bottom_sheet.dart';
import '../state_messages.dart';
import '../../../services/storage_service.dart';
import '../../../services/settings_service.dart' show ViewMode, EpisodePosterMode;
import '../../../mixins/grid_focus_node_mixin.dart';
import '../../../mixins/item_updatable.dart';
import '../../../mixins/deletion_aware.dart';
import '../../../utils/deletion_notifier.dart';
import '../../../utils/platform_detector.dart';
import '../../../i18n/strings.g.dart';
import '../../main_screen.dart';
import 'base_library_tab.dart';

/// Browse tab for library screen
/// Shows library items with grouping, filtering, and sorting
class LibraryBrowseTab extends BaseLibraryTab<MediaMetadata> {
  const LibraryBrowseTab({
    super.key,
    required super.library,
    super.viewMode,
    super.density,
    super.onDataLoaded,
    super.isActive,
    super.suppressAutoFocus,
    super.onBack,
  });

  @override
  State<LibraryBrowseTab> createState() => _LibraryBrowseTabState();
}

class _LibraryBrowseTabState extends BaseLibraryTabState<MediaMetadata, LibraryBrowseTab>
    with ItemUpdatable, LibraryTabFocusMixin, GridFocusNodeMixin, DeletionAware {
  @override
  JellyfinClient get client => getClientForLibrary();

  String _toGlobalKey(String itemId, {String? serverId}) =>
      '${serverId ?? widget.library.serverId ?? ''}:$itemId';

  @override
  String? get deletionServerId => widget.library.serverId;

  @override
  Set<String>? get deletionItemIds => items.map((e) => e.itemId).toSet();

  @override
  Set<String>? get deletionGlobalKeys {
    if (items.isEmpty) return <String>{};

    final keys = <String>{};
    for (final item in items) {
      final serverId = item.serverId ?? widget.library.serverId;
      if (serverId == null) return null;
      keys.add(_toGlobalKey(item.itemId, serverId: serverId));
    }
    return keys;
  }

  @override
  void onDeletionEvent(DeletionEvent event) {
    // If we have an item that matches the item ID exactly, then remove it from our list
    final index = items.indexWhere((e) => e.itemId == event.itemId);
    if (index != -1) {
      setState(() {
        items.removeAt(index);
      });
      return;
    }

    // If a child item was delete, then update our list to reflect that.
    // If all children were deleted, remove our item.
    // Otherwise, just update the counts.
    for (final parentKey in event.parentChain) {
      final parentIndex = items.indexWhere((e) => e.itemId == parentKey);
      if (parentIndex != -1) {
        final item = items[parentIndex];
        final newLeafCount = (item.leafCount ?? 1) - event.leafCount;
        if (newLeafCount <= 0) {
          setState(() {
            items.removeAt(parentIndex);
          });
        } else {
          setState(() {
            items[parentIndex] = item.copyWith(leafCount: newLeafCount);
          });
        }
        return;
      }
    }
  }

  @override
  String get focusNodeDebugLabel => 'browse_first_item';

  @override
  int get itemCount => items.length;

  @override
  void updateItemInLists(String itemId, MediaMetadata updatedMetadata) {
    setState(() {
      final index = items.indexWhere((item) => item.itemId == itemId);
      if (index != -1) {
        items[index] = updatedMetadata;
      }
    });
  }

  // Browse-specific state (not in base class)
  List<LibraryFilter> _filters = [];
  List<LibrarySort> _sortOptions = [];
  Map<String, String> _selectedFilters = {};
  LibrarySort? _selectedSort;
  bool _isSortDescending = false;
  String _selectedGrouping = 'all'; // all, seasons, episodes, folders

  // Alpha jump bar state
  List<FirstCharacter> _firstCharacters = [];
  AlphaJumpHelper _alphaHelper = AlphaJumpHelper(const []);
  int _currentFirstVisibleIndex = 0;
  int _currentColumnCount = 1;
  double _lastCrossAxisExtent = 0;
  bool _useWideAspectRatio = false;
  double _effectiveTopPadding = _gridTopPadding;
  /// Measured chips bar height (platform-dependent); falls back to constant if not yet measured.
  double _measuredChipsBarHeight = 48.0;
  /// Layout from the grid delegate — used for accurate scroll↔index mapping.
  SliverGridLayout? _gridLayout;
  final FocusNode _alphaJumpBarFocusNode = FocusNode(debugLabel: 'alpha_jump_bar');
  // When the user taps a letter, pin the highlight so scroll-based recalculation
  // doesn't immediately override it (e.g. when the letter has fewer items than a full row).
  bool _hasJumpPin = false;
  // True while a jump-triggered animateTo is in progress — suppresses all
  // scroll-based letter recalculation to prevent flashing.
  bool _isJumpScrolling = false;
  // Incremented on each jump so that overlapping animations don't clobber each other.
  int _jumpScrollGeneration = 0;

  // Scroll activity tracking (for phone scroll handle)
  bool _isScrollActive = false;
  Timer? _scrollActivityTimer;

  // Pagination state
  int _currentPage = 0;
  bool _hasMoreItems = true;
  CancelToken? _cancelToken;
  int _requestId = 0;
  static const int _pageSize = 500;

  // Focus nodes for filter chips
  final FocusNode _groupingChipFocusNode = FocusNode(debugLabel: 'grouping_chip');
  final FocusNode _filtersChipFocusNode = FocusNode(debugLabel: 'filters_chip');
  final FocusNode _sortChipFocusNode = FocusNode(debugLabel: 'sort_chip');

  // Scroll controller for the CustomScrollView
  final ScrollController _scrollController = ScrollController();

  final GlobalKey _chipsBarKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScrollChanged);
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _scrollActivityTimer?.cancel();
    _scrollLetterDebounce?.cancel();
    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
    _groupingChipFocusNode.dispose();
    _filtersChipFocusNode.dispose();
    _sortChipFocusNode.dispose();
    _alphaJumpBarFocusNode.dispose();
    disposeGridFocusNodes();
    super.dispose();
  }

  // Override loadData to use our custom _loadContent
  @override
  Future<List<MediaMetadata>> loadData() async {
    // This is called by base class loadItems(), but we override loadItems() entirely
    // So this just returns empty - actual loading is done in _loadContent
    return [];
  }

  // Override loadItems to use our custom loading with pagination
  @override
  Future<void> loadItems() async {
    await _loadContent();
  }

  // Required abstract implementations from base class
  @override
  IconData get emptyIcon => Symbols.folder_open_rounded;

  @override
  String get emptyMessage => t.libraries.thisLibraryIsEmpty;

  @override
  String get errorContext => t.libraries.content;

  // Override buildContent - not used since we override build()
  @override
  Widget buildContent(List<MediaMetadata> items) => const SizedBox.shrink();

  /// Focus the first item in the grid/list (for tab activation)
  @override
  void focusFirstItem() {
    if (items.isNotEmpty) {
      // Request immediately, then once more on the next frame to handle cases
      // where the grid/list attaches after the initial focus attempt.
      void request() {
        if (mounted && items.isNotEmpty && !firstItemFocusNode.hasFocus) {
          firstItemFocusNode.requestFocus();
        }
      }

      request();
      WidgetsBinding.instance.addPostFrameCallback((_) => request());
    }
  }

  /// Height of the chips bar (padding + chip + padding)
  static const double _chipsBarHeight = 48.0;

  /// Grouping chip is not used; always show filters/sort only.
  bool get _isGroupingChipVisible => false;

  /// First chip in the bar (grouping, or filters, or sort when grouping is hidden).
  FocusNode get _firstChipFocusNode {
    if (_isGroupingChipVisible) return _groupingChipFocusNode;
    if (_isFiltersChipVisible) return _filtersChipFocusNode;
    return _sortChipFocusNode;
  }

  /// Focus the chips bar (for navigating from tab bar to content).
  /// Called by libraries screen when pressing DOWN on tab bar.
  void focusChipsBar() {
    // If in folders mode, no chips to focus - go directly to folder tree
    if (_selectedGrouping == 'folders') {
      focusFirstItem();
      return;
    }
    _firstChipFocusNode.requestFocus();
  }

  Future<void> _loadContent() async {
    // Cancel any pending request
    _cancelToken?.cancel();
    _cancelToken = CancelToken();
    final currentRequestId = ++_requestId;

    // Extract context dependencies before async gap - use server-specific client
    final client = getClientForLibrary();

    setState(() {
      isLoading = true;
      errorMessage = null;
      items = [];
      _currentPage = 0;
      _hasMoreItems = true;
      // Clear filter/sort state while loading to prevent showing stale options
      _filters = [];
      _sortOptions = [];
      _selectedFilters = {};
      _selectedSort = null;
      _isSortDescending = false;
      _selectedGrouping = _getDefaultGrouping();
      _firstCharacters = [];
      _alphaHelper = AlphaJumpHelper(const []);
      _currentFirstVisibleIndex = 0;
    });

    try {
      // Load storage, filters, and sorts in parallel so browse appears faster
      final results = await Future.wait([
        StorageService.getInstance(),
        client.getLibraryFilters(widget.library.key, libraryType: widget.library.type),
        client.getLibrarySorts(widget.library.key, libraryType: widget.library.type),
      ]);
      final storage = results[0] as StorageService;
      final filters = results[1] as List<LibraryFilter>;
      final sorts = results[2] as List<LibrarySort>;

      // Load saved preferences
      final savedFilters = storage.getLibraryFilters(sectionId: widget.library.globalKey);
      final savedSort = storage.getLibrarySort(widget.library.globalKey);

      // Check if request was cancelled
      if (currentRequestId != _requestId) return;

      if (!mounted) return;
      setState(() {
        _filters = filters;
        _sortOptions = sorts;
        _selectedFilters = Map.from(savedFilters);
        _selectedGrouping = storage.getLibraryGrouping(widget.library.globalKey) ?? _getDefaultGrouping();

        // Restore sort
        if (savedSort != null) {
          final sortKey = savedSort['key'] as String?;
          if (sortKey != null) {
            final sort = sorts.where((s) => s.key == sortKey).firstOrNull;
            if (sort != null) {
              _selectedSort = sort;
              _isSortDescending = (savedSort['descending'] as bool?) ?? false;
            }
          }
        }
      });

      await _loadItems();
    } catch (e) {
      _handleLoadError(e, currentRequestId);
    }
  }

  Future<void> _loadItems({bool loadMore = false}) async {
    if (loadMore && isLoading) return;

    if (!loadMore) {
      _currentPage = 0;
      _hasMoreItems = true;
    }

    if (!_hasMoreItems) return;

    final currentRequestId = _requestId;
    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    setState(() {
      isLoading = true;
      if (!loadMore) {
        items = [];
        // Increment content version when loading fresh content
        // This invalidates the last focused index
        gridContentVersion++;
        cleanupGridFocusNodes(items.length);
      }
    });

    try {
      // Use server-specific client for this library
      final client = getClientForLibrary();

      // Build filter params
      final filterParams = Map<String, String>.from(_selectedFilters);

      final t = widget.library.type.toLowerCase();
      if (t == 'movie') {
        filterParams['type'] = '1';
      } else if (t == 'show') {
        filterParams['type'] = '2';
      }

      // Add sort
      if (_selectedSort != null) {
        filterParams['sort'] = _selectedSort!.getSortKey(descending: _isSortDescending);
      }

      appLogger.d('Library browse: getLibraryContent key=${widget.library.key} sort=${filterParams['sort']} type=${filterParams['type']} filters=${_selectedFilters.isEmpty ? "none" : _selectedFilters}');

      // Items are automatically tagged with server info by JellyfinClient
      final loadedItems = await client.getLibraryContent(
        widget.library.key,
        start: _currentPage * _pageSize,
        size: _pageSize,
        filters: filterParams,
        cancelToken: _cancelToken,
      );

      if (currentRequestId != _requestId) return;

      if (!mounted) return;
      setState(() {
        if (loadMore) {
          items.addAll(loadedItems);
        } else {
          items = loadedItems;
        }
        _hasMoreItems = loadedItems.length >= _pageSize;
        _currentPage++;
        isLoading = false;
      });

      // On initial load (not pagination), mark data as loaded and try to focus
      if (!loadMore) {
        hasLoadedData = true;
        tryFocus();

        // Build alpha bar data: compute locally when all items are loaded,
        // otherwise fall back to an API call for paginated libraries.
        if (!_hasMoreItems) {
          _computeFirstCharactersFromItems();
        } else {
          _loadFirstCharacters();
        }

        // Notify parent
        if (widget.onDataLoaded != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onDataLoaded!();
          });
        }
      }
    } catch (e) {
      _handleLoadError(e, currentRequestId);
    }
  }

  void _handleLoadError(dynamic error, int currentRequestId) {
    if (currentRequestId != _requestId) return;
    if (!mounted) return;

    setState(() {
      errorMessage = _getErrorMessage(error);
      isLoading = false;
    });
  }

  String _getDefaultGrouping() {
    final type = widget.library.type.toLowerCase();
    if (type == 'show') {
      return 'shows';
    } else if (type == 'movie') {
      return 'movies';
    }
    return 'all';
  }

  String _getGroupingTypeId() {
    switch (_selectedGrouping) {
      case 'movies':
        return '1';
      case 'shows':
        return '2';
      case 'seasons':
        return '3';
      case 'episodes':
        return '4';
      default:
        return '';
    }
  }

  List<String> _getGroupingOptions() {
    final type = widget.library.type.toLowerCase();
    if (type == 'show') {
      return ['shows', 'seasons', 'episodes', 'folders'];
    } else if (type == 'movie') {
      return ['movies', 'folders'];
    }
    // All library types support folder browsing
    return ['all', 'folders'];
  }

  String _getGroupingLabel(String grouping) {
    switch (grouping) {
      case 'movies':
        return t.libraries.groupings.movies;
      case 'shows':
        return t.libraries.groupings.shows;
      case 'seasons':
        return t.libraries.groupings.seasons;
      case 'episodes':
        return t.libraries.groupings.episodes;
      case 'folders':
        return t.libraries.groupings.folders;
      default:
        return t.libraries.groupings.all;
    }
  }

  String _getErrorMessage(dynamic error) {
    if (error is DioException) {
      return mapDioErrorToMessage(error, context: t.libraries.content);
    }
    return mapUnexpectedErrorToMessage(error, context: t.libraries.content);
  }

  void _showGroupingBottomSheet() {
    SelectKeyUpSuppressor.suppressSelectUntilKeyUp();
    var pendingGrouping = _selectedGrouping;
    OverlaySheetController.of(context)
        .show(
          builder: (sheetContext) {
            final options = _getGroupingOptions();
            return StatefulBuilder(
              builder: (context, setSheetState) {
                return RadioGroup<String>(
                  groupValue: pendingGrouping,
                  onChanged: (value) {
                    if (value == null) return;
                    setSheetState(() {
                      pendingGrouping = value;
                    });
                  },
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final grouping = options[index];
                      return RadioListTile<String>(
                        title: Text(_getGroupingLabel(grouping)),
                        value: grouping,
                      );
                    },
                  ),
                );
              },
            );
          },
        )
        .then((_) {
          if (!mounted) return;
          if (pendingGrouping == _selectedGrouping) return;
          setState(() {
            _selectedGrouping = pendingGrouping;
          });
          StorageService.getInstance().then((storage) {
            storage.saveLibraryGrouping(widget.library.globalKey, pendingGrouping);
          });
          _loadItems();
        });
  }

  void _showFiltersBottomSheet() {
    SelectKeyUpSuppressor.suppressSelectUntilKeyUp();
    OverlaySheetController.of(context).show(
      builder: (context) => FiltersBottomSheet(
        filters: _filters,
        selectedFilters: _selectedFilters,
        serverId: widget.library.serverId!,
        libraryKey: widget.library.globalKey,
        onFiltersChanged: (filters) async {
          setState(() {
            _selectedFilters.clear();
            _selectedFilters.addAll(filters);
          });

          // Save filters to storage
          final storage = await StorageService.getInstance();
          await storage.saveLibraryFilters(filters, sectionId: widget.library.globalKey);

          _loadItems();
        },
      ),
    );
  }

  void _showSortBottomSheet() {
    SelectKeyUpSuppressor.suppressSelectUntilKeyUp();
    // Track pending state in local variables so the callbacks don't trigger
    // setState/_loadItems while the sheet is open (which would steal focus).
    LibrarySort? pendingSort = _selectedSort;
    bool pendingDescending = _isSortDescending;
    bool pendingCleared = false;
    OverlaySheetController.of(context)
        .show(
          builder: (context) => SortBottomSheet(
            sortOptions: _sortOptions,
            selectedSort: _selectedSort,
            isSortDescending: _isSortDescending,
            onSortChanged: (sort, descending) {
              pendingSort = sort;
              pendingDescending = descending;
              pendingCleared = false;
            },
            onClear: () {
              pendingSort = null;
              pendingDescending = false;
              pendingCleared = true;
            },
          ),
        )
        .then((_) {
          if (!mounted) return;
          if (pendingCleared) {
            setState(() {
              _selectedSort = null;
              _isSortDescending = false;
            });
            StorageService.getInstance().then((storage) {
              storage.clearLibrarySort(widget.library.globalKey);
            });
            _loadItems();
          } else if (pendingSort != null &&
              (pendingSort!.key != _selectedSort?.key || pendingDescending != _isSortDescending)) {
            setState(() {
              _selectedSort = pendingSort;
              _isSortDescending = pendingDescending;
            });
            StorageService.getInstance().then((storage) {
              storage.saveLibrarySort(widget.library.globalKey, pendingSort!.key, descending: pendingDescending);
            });
            _loadItems();
          }
        });
  }

  /// Navigate focus from chips down to the grid item.
  /// Restores focus to the previously focused item if content hasn't changed.
  void _navigateToGrid() {
    if (items.isEmpty) return;

    final targetIndex = shouldRestoreGridFocus && lastFocusedGridIndex! < items.length ? lastFocusedGridIndex! : 0;

    // Use firstItemFocusNode for index 0 (matches _buildMediaCardItem)
    if (targetIndex == 0) {
      firstItemFocusNode.requestFocus();
    } else {
      getGridItemFocusNode(targetIndex, prefix: 'browse_grid_item').requestFocus();
    }
  }

  /// Navigate from the alpha jump bar to the nearest visible grid item.
  /// After a jump-scroll the previously focused item is off-screen (and its
  /// FocusNode detached), so we target the last-column item in the first
  /// visible row — the grid cell closest to the alpha bar.
  void _navigateToGridNearScroll() {
    if (items.isEmpty || _currentColumnCount < 1) return;

    final row = _currentFirstVisibleIndex ~/ _currentColumnCount;
    final targetIndex = ((row + 1) * _currentColumnCount - 1).clamp(0, items.length - 1);

    if (targetIndex == 0) {
      firstItemFocusNode.requestFocus();
    } else {
      getGridItemFocusNode(targetIndex, prefix: 'browse_grid_item').requestFocus();
    }
  }

  /// Navigate focus from grid up to the grouping chip
  void _navigateToChips() {
    _firstChipFocusNode.requestFocus();
  }

  /// Navigate focus to the sidebar
  void _navigateToSidebar() {
    MainScreenFocusScope.of(context)?.focusSidebar();
  }

  /// Navigate focus to the alpha jump bar
  void _navigateToAlphaJumpBar() {
    _alphaJumpBarFocusNode.requestFocus();
  }

  /// Whether the device is a phone (not tablet/desktop/TV).
  bool _isPhone(BuildContext context) => PlatformDetector.isPhone(context);

  /// The letter currently visible at the top of the grid.
  /// Uses the actual item's first char (stripping "The ", "A ", "An ") — matches sort order.
  String get _currentAlphaLetter {
    if (_currentFirstVisibleIndex >= items.length || items.isEmpty) return '#';
    final s = _sortKeyForAlpha(items[_currentFirstVisibleIndex]);
    if (s.isEmpty) return '#';
    final c = s[0].toUpperCase();
    return RegExp(r'[A-Z]').hasMatch(c) ? c : '#';
  }

  /// First character key for alpha grouping — strips leading articles to match sort order.
  static String _sortKeyForAlpha(MediaMetadata item) {
    var s = (item.titleSort ?? item.title).trim();
    if (s.isEmpty) return '';
    // Strip "The ", "A ", "An " at start (case-insensitive) — matches how titles sort
    final lower = s.toLowerCase();
    if (lower.startsWith('the ')) s = s.substring(4).trim();
    else if (lower.startsWith('a ')) s = s.substring(2).trim();
    else if (lower.startsWith('an ')) s = s.substring(3).trim();
    return s;
  }

  /// Whether the alpha jump bar should be shown.
  /// Only shown when sorting by title (titleSort) and not in folders mode.
  bool get _shouldShowAlphaJumpBar {
    if (_selectedGrouping == 'folders') return false;
    if (_firstCharacters.isEmpty) return false;
    // Show when no sort is selected (default is titleSort) or when explicitly sorting by title
    final sortKey = _selectedSort?.key ?? '';
    return sortKey.isEmpty || sortKey.startsWith('titleSort');
  }

  /// Compute first characters directly from loaded items (avoids extra API call)
  void _computeFirstCharactersFromItems() {
    final charCounts = <String, int>{};
    for (final item in items) {
      final sortKey = _sortKeyForAlpha(item);
      if (sortKey.isEmpty) continue;
      final firstChar = sortKey[0].toUpperCase();
      final key = RegExp(r'[A-Z]').hasMatch(firstChar) ? firstChar : '#';
      charCounts[key] = (charCounts[key] ?? 0) + 1;
    }

    final sortedKeys = charCounts.keys.toList()
      ..sort((a, b) {
        if (a == '#') return -1;
        if (b == '#') return 1;
        return a.compareTo(b);
      });

    final chars = sortedKeys
        .map((key) => FirstCharacter(key: key, title: key, size: charCounts[key]!))
        .toList();

    setState(() {
      _firstCharacters = chars;
      _alphaHelper = AlphaJumpHelper(chars);
    });
  }

  /// Fetch first characters via API (fallback for paginated libraries)
  Future<void> _loadFirstCharacters() async {
    final client = getClientForLibrary();
    final filterParams = Map<String, String>.from(_selectedFilters);
    final typeId = _getGroupingTypeId();

    try {
      final chars = await client.getFirstCharacters(
        widget.library.key,
        type: typeId.isNotEmpty ? int.tryParse(typeId) : null,
        filters: filterParams.isNotEmpty ? filterParams : null,
      );
      if (mounted) {
        setState(() {
          _firstCharacters = chars;
          _alphaHelper = AlphaJumpHelper(chars);
        });
      }
    } catch (_) {
      // Non-critical — hide the bar on failure
      if (mounted) {
        setState(() {
          _firstCharacters = [];
          _alphaHelper = AlphaJumpHelper(const []);
        });
      }
    }
  }

  Timer? _scrollLetterDebounce;

  /// Track scroll position to highlight the current letter in the jump bar
  void _onScrollChanged() {
    if (!_shouldShowAlphaJumpBar || _currentColumnCount < 1) return;

    // During a jump animation, skip all processing to avoid flashing.
    if (_isJumpScrolling) return;

    // If pinned from a completed jump, the next scroll event must be
    // user-initiated (touch drag, mouse wheel, etc.) — clear the pin
    // and resume normal tracking.
    if (_hasJumpPin) {
      _hasJumpPin = false;
    }

    // Debounce to avoid random jumps during scroll (e.g. to letter T)
    _scrollLetterDebounce?.cancel();
    _scrollLetterDebounce = Timer(const Duration(milliseconds: 80), () {
      if (mounted) _updateVisibleIndex();
    });
  }

  /// Recompute the first-visible-index from the current scroll offset.
  void _updateVisibleIndex() {
    if (!_scrollController.hasClients || !_scrollController.position.hasContentDimensions) return;
    final offset = _scrollController.offset;
    final firstVisibleIndex = _itemIndexFromScrollOffset(offset);
    if (firstVisibleIndex != _currentFirstVisibleIndex) {
      setState(() => _currentFirstVisibleIndex = firstVisibleIndex);
    }
  }

  /// Compute the first visible item index from a scroll offset.
  /// Grid scroll offset = viewport offset - top padding.
  int _itemIndexFromScrollOffset(double offset) {
    final layout = _gridLayout;
    if (layout == null || items.isEmpty) return 0;

    final gridScrollOffset = (offset - _effectiveTopPadding).clamp(0.0, double.infinity);
    final index = layout.getMinChildIndexForScrollOffset(gridScrollOffset);
    return index.clamp(0, items.length - 1);
  }

  /// Scroll to the item at [targetIndex], loading more pages if necessary.
  /// Uses actual item scan — API firstCharacter indices don't match content order.
  /// Prefers row-start index so the leftmost visible item is the target letter.
  void _jumpToIndex(int targetIndex) {
    final letter = _alphaHelper.currentLetter(targetIndex.clamp(0, items.length > 0 ? items.length - 1 : 0));
    var indexToUse = _indexOfFirstItemWithLetterAtRowStart(letter) ?? _indexOfFirstItemWithLetter(letter);

    if (indexToUse == null && _hasMoreItems) {
      // Letter not in loaded range — load until we find it
      _loadUntilLetterThenJump(letter);
      return;
    }
    indexToUse ??= targetIndex.clamp(0, items.length > 0 ? items.length - 1 : 0);

    _jumpScrollGeneration++;
    _isJumpScrolling = true;
    _hasJumpPin = true;
    setState(() => _currentFirstVisibleIndex = indexToUse!);

    void doJump() {
      if (indexToUse! < items.length) {
        _scrollToItemIndex(indexToUse!);
      } else {
        _loadUntilIndex(indexToUse!);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) doJump();
    });
  }

  /// Find the first item index whose sort key starts with [letter].
  int? _indexOfFirstItemWithLetter(String letter) {
    if (items.isEmpty) return null;
    for (var i = 0; i < items.length; i++) {
      final s = _sortKeyForAlpha(items[i]);
      if (s.isEmpty) continue;
      final c = s[0].toUpperCase();
      final key = RegExp(r'[A-Z]').hasMatch(c) ? c : '#';
      if (key == letter) return i;
    }
    return null;
  }

  /// Find the first item with [letter] that starts a row (leftmost visible).
  /// Prefer this so the user sees the target letter, not a previous letter in the same row.
  int? _indexOfFirstItemWithLetterAtRowStart(String letter) {
    if (items.isEmpty || _currentColumnCount < 1) return null;
    for (var i = 0; i < items.length; i++) {
      if (i % _currentColumnCount != 0) continue;
      final s = _sortKeyForAlpha(items[i]);
      if (s.isEmpty) continue;
      final c = s[0].toUpperCase();
      final key = RegExp(r'[A-Z]').hasMatch(c) ? c : '#';
      if (key == letter) return i;
    }
    return null;
  }

  /// Load pages until we find an item with [letter], then scroll to it.
  Future<void> _loadUntilLetterThenJump(String letter) async {
    _jumpScrollGeneration++;
    _isJumpScrolling = true;
    _hasJumpPin = true;

    while (_hasMoreItems && mounted) {
      await _loadItems(loadMore: true);
      final idx = _indexOfFirstItemWithLetterAtRowStart(letter) ?? _indexOfFirstItemWithLetter(letter);
      if (idx != null) {
        setState(() => _currentFirstVisibleIndex = idx);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToItemIndex(idx);
        });
        return;
      }
    }
    if (mounted) _isJumpScrolling = false;
  }

  /// Scroll the grid so that [index] is visible just below the chips bar.
  /// Uses the grid delegate's layout for accuracy.
  void _scrollToItemIndex(int index) {
    final layout = _gridLayout;
    if (layout == null ||
        !_scrollController.hasClients ||
        !_scrollController.position.hasContentDimensions) {
      _isJumpScrolling = false;
      return;
    }

    final geometry = layout.getGeometryForChildIndex(index);
    // Put item at top of viewport: offset = topPadding + gridScrollOffset
    // To place below chips bar: subtract chipsBarHeight so item appears at viewport Y = chipsBarHeight
    final offset = _effectiveTopPadding + geometry.scrollOffset - _measuredChipsBarHeight;

    final gen = _jumpScrollGeneration;
    final clampedOffset = offset.clamp(0.0, _scrollController.position.maxScrollExtent);

    _scrollController.animateTo(clampedOffset, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut).then((_) {
      if (mounted && gen == _jumpScrollGeneration) {
        _isJumpScrolling = false;
      }
    });
  }

  /// Load pages until [targetIndex] is loaded, then scroll to it
  Future<void> _loadUntilIndex(int targetIndex) async {
    while (items.length <= targetIndex && _hasMoreItems) {
      await _loadItems(loadMore: true);
    }
    if (mounted) {
      _scrollToItemIndex(targetIndex.clamp(0, items.length - 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return OverlaySheetHost(
      child: Stack(
        children: [
          // Grid fills the entire area, with top padding for chips bar
          Positioned.fill(child: _buildScrollableContent()),
          // Chips bar on top with solid background (measure height for alpha jump scroll math)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Builder(
              key: _chipsBarKey,
              builder: (context) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  final box = context.findRenderObject() as RenderBox?;
                  if (box != null && box.hasSize) {
                    final h = box.size.height;
                    if ((h - _measuredChipsBarHeight).abs() > 0.5) {
                      setState(() => _measuredChipsBarHeight = h);
                    }
                  }
                });
                return _buildChipsBar();
              },
            ),
          ),
          // Alpha jump bar / scroll handle on the right edge
          if (_shouldShowAlphaJumpBar)
            Positioned(
              top: _measuredChipsBarHeight,
              right: 0,
              bottom: 0,
              child: _isPhone(context)
                  ? AlphaScrollHandle(
                      firstCharacters: _firstCharacters,
                      onJump: _jumpToIndex,
                      currentLetter: _currentAlphaLetter,
                      isScrolling: _isScrollActive,
                    )
                  : AlphaJumpBar(
                      firstCharacters: _firstCharacters,
                      onJump: _jumpToIndex,
                      currentLetter: _currentAlphaLetter,
                      focusNode: _alphaJumpBarFocusNode,
                      onNavigateLeft: _navigateToGridNearScroll,
                      onBack: _navigateToGridNearScroll,
                    ),
            ),
        ],
      ),
    );
  }

  /// Builds the scrollable content (grid/list) with pagination support
  Widget _buildScrollableContent() {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 300 && _hasMoreItems && !isLoading) {
          _loadItems(loadMore: true);
        }
        // Track scroll activity for phone scroll handle.
        // Deferred via post-frame callback because scroll notifications can
        // fire during layout (e.g. when the alpha jump bar appears and the
        // viewport recomputes dimensions).
        if (notification is ScrollStartNotification) {
          _scrollActivityTimer?.cancel();
          if (!_isScrollActive) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_isScrollActive) setState(() => _isScrollActive = true);
            });
          }
        } else if (notification is ScrollEndNotification) {
          _scrollActivityTimer?.cancel();
          _scrollActivityTimer = Timer(const Duration(milliseconds: 100), () {
            if (mounted) setState(() => _isScrollActive = false);
          });
        }
        return false;
      },
      child: CustomScrollView(
        controller: _scrollController,
        // Allow focus decoration to render outside scroll bounds
        clipBehavior: Clip.none,
        slivers: _buildContentSlivers(),
      ),
    );
  }

  /// Whether the filters chip is visible
  bool get _isFiltersChipVisible => _filters.isNotEmpty && _selectedGrouping != 'folders';

  /// Whether the sort chip is visible
  bool get _isSortChipVisible => _sortOptions.isNotEmpty && _selectedGrouping != 'folders';

  /// Builds the chips bar widget
  Widget _buildChipsBar() {
    VoidCallback? groupingNavigateRight;
    if (_isFiltersChipVisible) {
      groupingNavigateRight = () => _filtersChipFocusNode.requestFocus();
    } else if (_isSortChipVisible) {
      groupingNavigateRight = () => _sortChipFocusNode.requestFocus();
    }

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Grouping chip not used; filters and sort only
          if (_isGroupingChipVisible) ...[
            FocusableFilterChip(
              focusNode: _groupingChipFocusNode,
              icon: Symbols.category_rounded,
              label: _getGroupingLabel(_selectedGrouping),
              onPressed: _showGroupingBottomSheet,
              onNavigateDown: _navigateToGrid,
              onNavigateUp: widget.onBack,
              onNavigateLeft: _navigateToSidebar,
              onNavigateRight: groupingNavigateRight,
              onBack: widget.onBack,
            ),
            const SizedBox(width: 8),
          ],
          // Filters chip
          if (_isFiltersChipVisible)
            FocusableFilterChip(
              focusNode: _filtersChipFocusNode,
              icon: Symbols.filter_alt_rounded,
              label: _selectedFilters.isEmpty
                  ? t.libraries.filters
                  : t.libraries.filtersWithCount(count: _selectedFilters.length),
              onPressed: _showFiltersBottomSheet,
              onNavigateDown: _navigateToGrid,
              onNavigateUp: widget.onBack,
              onNavigateLeft: _isGroupingChipVisible
                  ? () => _groupingChipFocusNode.requestFocus()
                  : _navigateToSidebar,
              onNavigateRight: _isSortChipVisible ? () => _sortChipFocusNode.requestFocus() : null,
              onBack: widget.onBack,
            ),
          if (_isFiltersChipVisible) const SizedBox(width: 8),
          // Sort chip
          if (_isSortChipVisible)
            FocusableFilterChip(
              focusNode: _sortChipFocusNode,
              icon: Symbols.sort_rounded,
              label: _selectedSort?.title ?? t.libraries.sort,
              onPressed: _showSortBottomSheet,
              onNavigateDown: _navigateToGrid,
              onNavigateUp: widget.onBack,
              onNavigateLeft: _isFiltersChipVisible
                  ? () => _filtersChipFocusNode.requestFocus()
                  : _isGroupingChipVisible
                      ? () => _groupingChipFocusNode.requestFocus()
                      : _navigateToSidebar,
              onBack: widget.onBack,
            ),
        ],
      ),
    );
  }

  /// Builds content as slivers for the CustomScrollView
  List<Widget> _buildContentSlivers() {
    if (isLoading && items.isEmpty) {
      return [const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))];
    }

    if (errorMessage != null && items.isEmpty) {
      return [
        SliverFillRemaining(
          child: ErrorStateWidget(
            message: errorMessage!,
            icon: Symbols.error_outline_rounded,
            onRetry: _loadContent,
            retryLabel: t.common.retry,
          ),
        ),
      ];
    }

    if (items.isEmpty) {
      return [
        SliverFillRemaining(
          child: EmptyStateWidget(message: t.libraries.thisLibraryIsEmpty, icon: Symbols.folder_open_rounded),
        ),
      ];
    }

    return [
      Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          return _buildItemsSliver(context, settingsProvider);
        },
      ),
    ];
  }

  // Top padding for grid content = chips bar height + extra space for focus decoration.
  // Chips bar is ~48px, focus ring extends ~6px beyond item bounds.
  // On phone there's no D-pad focus decoration so extra clearance is unnecessary.
  static const double _gridTopPadding = _chipsBarHeight + 12.0;
  static const double _gridTopPaddingPhone = _chipsBarHeight;

  /// Width of the alpha jump bar widget (desktop/tablet/TV)
  static const double _alphaJumpBarWidth = 28.0;

  /// Width reserved for alpha scroll handle on phone (touch target)
  static const double _alphaScrollHandleWidth = 48.0;

  /// Builds either a sliver list or sliver grid based on the view mode
  Widget _buildItemsSliver(BuildContext context, SettingsProvider settingsProvider) {
    final itemCount = items.length + (_hasMoreItems && isLoading ? 1 : 0);
    final isPhone = _isPhone(context);
    final topPadding = isPhone ? _gridTopPaddingPhone : _gridTopPadding;
    _effectiveTopPadding = topPadding;
    final rightPadding = _shouldShowAlphaJumpBar
        ? (isPhone ? _alphaScrollHandleWidth : _alphaJumpBarWidth)
        : 8.0;

    if (settingsProvider.viewMode == ViewMode.list) {
      _gridLayout = null;
      _lastCrossAxisExtent = 0;
      _currentColumnCount = 1;
      // In list view, all items are in a single column (first column)
      return SliverPadding(
        padding: EdgeInsets.fromLTRB(8, topPadding, rightPadding, 8),
        sliver: SliverList.builder(
          itemCount: itemCount,
          itemBuilder: (context, index) => _buildMediaCardItem(
            index,
            isFirstRow: index == 0,
            isFirstColumn: true, // List view = single column
          ),
        ),
      );
    } else {
      // In grid view, calculate columns and pass to item builder
      // Use 16:9 aspect ratio when browsing episodes with episode thumbnail mode
      final useWideRatio =
          _selectedGrouping == 'episodes' && settingsProvider.episodePosterMode == EpisodePosterMode.episodeThumbnail;
      final maxExtent = GridSizeCalculator.getMaxCrossAxisExtent(context, settingsProvider.libraryDensity);
      final effectiveMaxExtent = useWideRatio ? maxExtent * 1.8 : maxExtent;
      return SliverPadding(
        padding: EdgeInsets.fromLTRB(8, topPadding, rightPadding, 8),
        sliver: SliverLayoutBuilder(
          builder: (context, constraints) {
            final columnCount = GridSizeCalculator.getColumnCount(constraints.crossAxisExtent, effectiveMaxExtent);
            _lastCrossAxisExtent = constraints.crossAxisExtent;
            _currentColumnCount = columnCount;
            _useWideAspectRatio = useWideRatio;
            final delegate = MediaGridDelegate.createDelegate(
              context: context,
              density: settingsProvider.libraryDensity,
              useWideAspectRatio: useWideRatio,
            );
            _gridLayout = delegate.getLayout(constraints);
            return SliverGrid.builder(
              gridDelegate: MediaGridDelegate.createDelegate(
                context: context,
                density: settingsProvider.libraryDensity,
                useWideAspectRatio: useWideRatio,
              ),
              itemCount: itemCount,
              itemBuilder: (context, index) => _buildMediaCardItem(
                index,
                isFirstRow: GridSizeCalculator.isFirstRow(index, columnCount),
                isFirstColumn: GridSizeCalculator.isFirstColumn(index, columnCount),
                isLastColumn: (index % columnCount) == (columnCount - 1),
              ),
            );
          },
        ),
      );
    }
  }

  Widget _buildMediaCardItem(
    int index, {
    required bool isFirstRow,
    required bool isFirstColumn,
    bool isLastColumn = false,
  }) {
    if (index >= items.length) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final item = items[index];

    // Use firstItemFocusNode for index 0 to maintain compatibility with base class
    // All other items get managed focus nodes for restoration
    final focusNode = index == 0 ? firstItemFocusNode : getGridItemFocusNode(index, prefix: 'browse_grid_item');

    return FocusableMediaCard(
      key: Key(item.itemId),
      item: item,
      focusNode: focusNode,
      onRefresh: updateItem,
      onNavigateUp: isFirstRow ? _navigateToChips : null,
      onNavigateLeft: isFirstColumn ? _navigateToSidebar : null,
      onNavigateRight: isLastColumn && _shouldShowAlphaJumpBar && !_isPhone(context) ? _navigateToAlphaJumpBar : null,
      onBack: widget.onBack,
      onFocusChange: (hasFocus) => trackGridItemFocus(index, hasFocus),
      onListRefresh: _loadItems,
    );
  }
}
