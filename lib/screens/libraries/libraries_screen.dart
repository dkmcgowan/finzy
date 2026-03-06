import 'package:flutter/material.dart';
import 'package:finzy/widgets/app_icon.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../focus/dpad_navigator.dart';
import '../../focus/input_mode_tracker.dart';
import '../../mixins/tab_navigation_mixin.dart';
import '../../../services/jellyfin_client.dart';
import '../../models/hub.dart';
import '../../models/media_library.dart';
import '../../models/media_metadata.dart';
import '../../models/library_sort.dart';
import '../../providers/hidden_libraries_provider.dart';
import '../../providers/libraries_provider.dart';
import '../../providers/multi_server_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../providers/server_state_provider.dart';
import '../../providers/playback_state_provider.dart';
import '../../utils/app_logger.dart';
import '../../utils/platform_detector.dart';
import '../../utils/provider_extensions.dart';
import '../../utils/content_utils.dart';
import '../../utils/dialogs.dart';
import '../../widgets/focusable_tab_chip.dart';
import '../../widgets/hub_section.dart';
import '../../widgets/overlay_sheet.dart';
import '../../services/storage_service.dart';
import '../../mixins/refreshable.dart';
import '../../mixins/item_updatable.dart';
import '../../i18n/strings.g.dart';
import '../../constants/library_constants.dart';
import '../../utils/error_message_utils.dart';
import '../auth_screen.dart';
import '../main_screen.dart';
import '../profile/jellyfin_profile_switch_screen.dart';
import '../../widgets/profile_app_bar_button.dart';
import 'state_messages.dart';
import 'tabs/library_browse_tab.dart';
import 'tabs/library_recommended_tab.dart';
import 'tabs/library_genre_tab.dart';
import 'tabs/library_collections_tab.dart';
import 'tabs/library_favorites_tab.dart';
import 'tabs/library_playlists_tab.dart';

class LibrariesScreen extends StatefulWidget {
  final VoidCallback? onLibraryOrderChanged;

  const LibrariesScreen({super.key, this.onLibraryOrderChanged});

  @override
  State<LibrariesScreen> createState() => _LibrariesScreenState();
}

class _LibrariesScreenState extends State<LibrariesScreen>
    with
        Refreshable,
        FullRefreshable,
        FocusableTab,
        LibraryLoadable,
        ItemUpdatable,
        TickerProviderStateMixin,
        TabNavigationMixin {
  @override
  JellyfinClient get client {
    final multiServerProvider = Provider.of<MultiServerProvider>(context, listen: false);
    if (!multiServerProvider.hasConnectedServers) {
      throw Exception(t.errors.noClientAvailable);
    }
    return context.getClientForServer(multiServerProvider.onlineServerIds.first);
  }

  // GlobalKeys for tabs to enable refresh
  final _recommendedTabKey = GlobalKey();
  final _browseTabKey = GlobalKey();
  final _genreTabKey = GlobalKey();
  final _favoritesTabKey = GlobalKey();
  final _collectionsTabKey = GlobalKey();
  final _playlistsTabKey = GlobalKey();

  String? _errorMessage;
  String? _selectedLibraryGlobalKey;
  bool _isInitialLoad = true;

  Map<String, String> _selectedFilters = {};
  LibrarySort? _selectedSort;
  bool _isSortDescending = false;
  List<MediaMetadata> _items = [];
  int _currentPage = 0;
  bool _hasMoreItems = true;
  CancelToken? _cancelToken;
  int _requestId = 0;
  static const int _pageSize = 1000;

  /// Flag to prevent onTabChanged from focusing when we're programmatically changing tabs
  bool _isRestoringTab = false;

  /// Track which tabs have loaded data (used to trigger focus after tab restore)
  final Set<int> _loadedTabs = {};


  /// Effective number of tabs for the selected library (4 for movie/show, 1 for collection/playlist).
  int _effectiveTabCount = 5;

  /// Key for the library dropdown popup menu button
  final _libraryDropdownKey = GlobalKey<PopupMenuButtonState<String>>();

  /// Key for the profile menu (used to open programmatically on D-pad Select)
  final _profileMenuKey = GlobalKey<PopupMenuButtonState<String>>();

  // Focus nodes for tab chips (order depends on _effectiveTabCount)
  final _recommendedTabChipFocusNode = FocusNode(debugLabel: 'tab_chip_recommended');
  final _browseTabChipFocusNode = FocusNode(debugLabel: 'tab_chip_browse');
  final _genreTabChipFocusNode = FocusNode(debugLabel: 'tab_chip_genre');
  final _favoritesTabChipFocusNode = FocusNode(debugLabel: 'tab_chip_favorites');
  final _collectionsTabChipFocusNode = FocusNode(debugLabel: 'tab_chip_collections');
  final _playlistsTabChipFocusNode = FocusNode(debugLabel: 'tab_chip_playlists');

  @override
  List<FocusNode> get tabChipFocusNodes {
    if (_effectiveTabCount == 4) {
      return [
        _recommendedTabChipFocusNode,
        _browseTabChipFocusNode,
        _favoritesTabChipFocusNode,
        _genreTabChipFocusNode,
      ];
    }
    if (_effectiveTabCount == 3) {
      return [
        _recommendedTabChipFocusNode,
        _browseTabChipFocusNode,
        _favoritesTabChipFocusNode,
      ];
    }
    if (_effectiveTabCount == 1) {
      return [_browseTabChipFocusNode];
    }
    return [
      _recommendedTabChipFocusNode,
      _browseTabChipFocusNode,
      _favoritesTabChipFocusNode,
      _collectionsTabChipFocusNode,
      _playlistsTabChipFocusNode,
    ];
  }

  /// Tab count for the given library and client.
  int _getEffectiveTabCount(JellyfinClient client, MediaLibrary library) {
    final t = library.type.toLowerCase();
    if (t == 'movie' || t == 'show') return 4;
    if (t == 'collection' || t == 'playlist' || t == 'playlists') return 1;
    return 5;
  }

  // App bar action button focus
  late FocusNode _refreshButtonFocusNode;
  late FocusNode _profileButtonFocusNode;
  bool _isRefreshFocused = false;
  bool _isProfileFocused = false;

  // Scroll controller for the outer CustomScrollView
  final ScrollController _outerScrollController = ScrollController();

  /// Global Favorites view: one hub per library.
  List<Hub> _globalFavoritesHubs = [];
  bool _areGlobalFavoritesLoading = false;

  /// Keys for HubSections in global Favorites view (for D-pad focus when DOWN from app bar).
  final List<GlobalKey<HubSectionState>> _globalFavoritesHubKeys = [];
  String? _globalFavoritesError;

  @override
  void initState() {
    super.initState();
    initTabNavigation();

    // Initialize action button focus nodes
    _refreshButtonFocusNode = FocusNode(debugLabel: 'RefreshButton');
    _profileButtonFocusNode = FocusNode(debugLabel: 'ProfileButton');
    _refreshButtonFocusNode.addListener(_onRefreshFocusChange);
    _profileButtonFocusNode.addListener(_onProfileFocusChange);

    // Initialize with libraries from the provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWithLibraries();
    });
  }

  /// Initialize the screen with libraries from the provider.
  /// This handles initial library selection and content loading.
  Future<void> _initializeWithLibraries() async {
    final librariesProvider = context.read<LibrariesProvider>();
    final hiddenLibrariesProvider = context.read<HiddenLibrariesProvider>();
    final allLibraries = librariesProvider.libraries;

    if (allLibraries.isEmpty) {
      return;
    }

    // Compute visible libraries for initial load
    final hiddenKeys = hiddenLibrariesProvider.hiddenLibraryKeys;
    final visibleLibraries = allLibraries.where((lib) => !hiddenKeys.contains(lib.globalKey)).toList();

    // Load saved preferences
    final storage = await StorageService.getInstance();
    final savedLibraryKey = storage.getSelectedLibraryKey();

    // Find the library by key in visible libraries (or Favorites when visible)
    String? libraryGlobalKeyToLoad;
    if (savedLibraryKey != null) {
      final libraryExists = visibleLibraries.any((lib) => lib.globalKey == savedLibraryKey);
      final isFavoritesAndVisible = savedLibraryKey == kJellyfinFavoritesKey &&
          !hiddenKeys.contains(kJellyfinFavoritesKey);
      if (libraryExists || isFavoritesAndVisible) {
        libraryGlobalKeyToLoad = savedLibraryKey;
      }
    }

    // Fallback to first visible library if saved key not found
    if (libraryGlobalKeyToLoad == null && visibleLibraries.isNotEmpty) {
      libraryGlobalKeyToLoad = visibleLibraries.first.globalKey;
    }

    if (libraryGlobalKeyToLoad != null && mounted) {
      final savedFilters = storage.getLibraryFilters(sectionId: libraryGlobalKeyToLoad);
      if (savedFilters.isNotEmpty) {
        _selectedFilters = Map.from(savedFilters);
      }
      _loadLibraryContent(libraryGlobalKeyToLoad);
    }
  }

  @override
  void onTabChanged() {
    if (_selectedLibraryGlobalKey != null && !tabController.indexIsChanging) {
      if (!_isRestoringTab) {
        // Focus first item in the current tab (only for user-initiated changes)
        // But not when navigating via tab bar (suppressAutoFocus is true)
        if (!suppressAutoFocus) {
          _focusCurrentTab();
        }
      }
    }
    // Rebuild to update chip selection state
    super.onTabChanged();
  }

  /// Focus the first item in the currently active tab.
  /// Used for initial load and tab switching - focuses the grid content directly.
  void _focusCurrentTab() {
    // Don't focus during tab animations
    if (tabController.indexIsChanging) return;

    // Global Favorites: skip if data hasn't loaded yet.
    // The post-load callback in _loadGlobalFavorites handles focus once ready.
    if (_selectedLibraryGlobalKey == kJellyfinFavoritesKey && _areGlobalFavoritesLoading) return;

    // Re-enable auto-focus since user is navigating into tab content
    if (suppressAutoFocus) {
      setState(() {
        suppressAutoFocus = false;
      });
    }

    // Scroll to top so tab content is visible when focusing from app bar
    if (_outerScrollController.hasClients && _outerScrollController.offset > 0) {
      _outerScrollController.jumpTo(0);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Global Favorites view: focus first HubSection directly
      if (_selectedLibraryGlobalKey == kJellyfinFavoritesKey) {
        _focusFirstGlobalFavoritesHub();
        return;
      }

      final tabState = _getTabState(tabController.index);
      if (tabState != null) {
        (tabState as dynamic).focusFirstItem();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _focusCurrentTabImmediate();
        });
      }
    });
  }

  /// Focus the first HubSection in the global Favorites view.
  /// Uses memory to restore the user's last position within the hub.
  void _focusFirstGlobalFavoritesHub() {
    if (_globalFavoritesHubKeys.isEmpty || _globalFavoritesHubs.isEmpty) return;
    _globalFavoritesHubKeys.first.currentState?.requestFocusFromMemory();
  }

  bool _handleGlobalFavoritesVerticalNav(int hubIndex, bool isUp) {
    final targetIndex = isUp ? hubIndex - 1 : hubIndex + 1;
    if (targetIndex < 0) return false;
    if (targetIndex >= _globalFavoritesHubKeys.length) return true;
    final targetState = _globalFavoritesHubKeys[targetIndex].currentState;
    if (targetState != null) {
      targetState.requestFocusFromMemory();
      return true;
    }
    return false;
  }

  /// Focus without additional frame delay (used for retry)
  void _focusCurrentTabImmediate() {
    final tabState = _getTabState(tabController.index);
    if (tabState != null) {
      (tabState as dynamic).focusFirstItem();
    }
  }

  /// UP from first row: focus tab bar when there are focusable tab chips,
  /// otherwise focus refresh button (for Favorites or single-tab libraries).
  void _onContentNavigateUp() {
    if (_effectiveTabCount > 1 && _selectedLibraryGlobalKey != kJellyfinFavoritesKey) {
      focusTabBar();
    } else {
      _scrollOuterToTopIfNeeded();
      _refreshButtonFocusNode.requestFocus();
    }
  }

  /// BACK key from content: focus sidebar (navigation). Most users want this.
  void _onContentBack() {
    MainScreenFocusScope.of(context)?.focusSidebar();
  }

  /// Focus tab content when navigating DOWN from the tab bar.
  /// Focuses the first item in the tab (grid, hub, etc.) for consistent keyboard/dpad UX.
  void _focusCurrentTabFromTabBar() {
    if (tabController.indexIsChanging) {
      return;
    }

    if (suppressAutoFocus) {
      setState(() {
        suppressAutoFocus = false;
      });
    }

    // Unfocus the tab chip first so the content can receive focus (avoids focus "stuck" on tab bar)
    getTabChipFocusNode(tabController.index).unfocus();

    // Scroll outer view to top to ensure tab content is visible
    if (_outerScrollController.hasClients && _outerScrollController.offset > 0) {
      _outerScrollController.jumpTo(0);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final tabState = _getTabState(tabController.index);
      if (tabState != null) {
        (tabState as dynamic).focusFirstItem();
      }
    });
  }

  /// Scroll the outer CustomScrollView to top when opening an inline view.
  /// Ensures header and content are visible (avoids cut-off from prior scroll offset).
  void _scrollOuterToTopIfNeeded() {
    final disableAnimations = context.read<SettingsProvider>().disableAnimations;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_outerScrollController.hasClients) return;
      if (_outerScrollController.offset > 0) {
        if (disableAnimations) {
          _outerScrollController.jumpTo(0);
        } else {
          _outerScrollController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        }
      }
    });
  }

  MediaLibrary? _getSelectedLibrary() {
    if (_selectedLibraryGlobalKey == null) return null;
    final list = context.read<LibrariesProvider>().libraries.where((l) => l.globalKey == _selectedLibraryGlobalKey).toList();
    return list.isNotEmpty ? list.first : null;
  }

  /// Get the state for a tab by index (respects _effectiveTabCount; when 1 tab, index 0 is Collections or Playlists).
  State? _getTabState(int index) {
    if (_effectiveTabCount == 1 && index == 0) {
      final lib = _getSelectedLibrary();
      if (lib != null) {
        return (lib.type.toLowerCase() == 'collection' ? _collectionsTabKey : _playlistsTabKey).currentState;
      }
    }
    switch (index) {
      case 0: return _browseTabKey.currentState;
      case 1: return _recommendedTabKey.currentState;
      case 2: return _favoritesTabKey.currentState;
      case 3: return _effectiveTabCount == 4 ? _genreTabKey.currentState : _collectionsTabKey.currentState;
      case 4: return _playlistsTabKey.currentState;
      default: return null;
    }
  }

  /// Handle when a tab's data has finished loading
  void _handleTabDataLoaded(int tabIndex) {
    // Track that this tab has loaded
    _loadedTabs.add(tabIndex);

    // Don't auto-focus if suppressed or not using keyboard
    if (suppressAutoFocus) return;

    // Only focus if this is the currently active tab and in keyboard mode
    if (tabController.index == tabIndex && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && tabController.index == tabIndex && !suppressAutoFocus && InputModeTracker.isKeyboardMode(context)) {
          _focusCurrentTab();
        }
      });
    }
  }

  /// Called by parent when the Libraries screen becomes visible.
  /// If the active tab has already loaded data (often the case after preloading
  /// while on another main tab), re-request focus so the first item is focused
  /// once the screen is actually shown.
  @override
  void focusActiveTabIfReady() {
    if (_selectedLibraryGlobalKey == null) return;
    _focusCurrentTab();
  }

  void _onRefreshFocusChange() {
    if (mounted) {
      setState(() => _isRefreshFocused = _refreshButtonFocusNode.hasFocus);
    }
  }

  void _onProfileFocusChange() {
    if (mounted) {
      setState(() => _isProfileFocused = _profileButtonFocusNode.hasFocus);
    }
  }

  /// Down from app bar actions: go to tab bar when tabs exist, content otherwise.
  void _navigateDownFromAppBar() {
    if (_selectedLibraryGlobalKey == kJellyfinFavoritesKey) {
      _focusFirstGlobalFavoritesHub();
    } else if (_effectiveTabCount > 1) {
      focusTabBar();
    } else {
      // Single-tab libraries (Collections/Playlists): focus content directly
      final tabState = _getTabState(0);
      if (tabState != null) {
        (tabState as dynamic).focusFirstItem();
      }
    }
  }

  /// Handle key events for the refresh button in app bar
  KeyEventResult _handleRefreshKeyEvent(FocusNode _, KeyEvent event) {
    if (!event.isActionable) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key.isLeftKey) {
      if (_effectiveTabCount > 1 && _selectedLibraryGlobalKey != kJellyfinFavoritesKey) {
        getTabChipFocusNode(_effectiveTabCount - 1).requestFocus();
      } else {
        MainScreenFocusScope.of(context)?.focusSidebar();
      }
      return KeyEventResult.handled;
    }
    if (key.isRightKey) {
      _profileButtonFocusNode.requestFocus();
      return KeyEventResult.handled;
    }
    if (key.isUpKey) {
      return KeyEventResult.handled; // Block at boundary
    }
    if (key.isDownKey) {
      _navigateDownFromAppBar();
      return KeyEventResult.handled;
    }
    if (key.isSelectKey) {
      if (_selectedLibraryGlobalKey == kJellyfinFavoritesKey) {
        _loadGlobalFavorites();
      } else {
        _refreshCurrentTab();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Handle key events for the profile button in app bar (D-pad nav; select opens menu)
  KeyEventResult _handleProfileKeyEvent(FocusNode _, KeyEvent event) {
    if (!event.isActionable) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key.isLeftKey) {
      _refreshButtonFocusNode.requestFocus();
      return KeyEventResult.handled;
    }
    if (key.isRightKey || key.isUpKey) {
      return KeyEventResult.handled;
    }
    if (key.isDownKey) {
      _navigateDownFromAppBar();
      return KeyEventResult.handled;
    }
    if (key.isSelectKey) {
      _profileMenuKey.currentState?.showButtonMenu();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _handleJellyfinSwitchProfile(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const JellyfinProfileSwitchScreen()));
  }

  Future<void> _handleLogout() async {
    final confirm = await showConfirmDialog(
      context,
      title: t.common.logout,
      message: t.messages.logoutConfirm,
      confirmText: t.common.logout,
      isDestructive: true,
    );

    if (confirm && mounted) {
      final userProfileProvider = context.read<UserProfileProvider>();
      final multiServerProvider = context.read<MultiServerProvider>();
      final serverStateProvider = context.read<ServerStateProvider>();
      final hiddenLibrariesProvider = context.read<HiddenLibrariesProvider>();
      final playbackStateProvider = context.read<PlaybackStateProvider>();

      await userProfileProvider.logout();
      multiServerProvider.clearAllConnections();
      serverStateProvider.reset();
      await hiddenLibrariesProvider.refresh();
      playbackStateProvider.clearShuffle();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _outerScrollController.dispose();
    _recommendedTabChipFocusNode.dispose();
    _browseTabChipFocusNode.dispose();
    _genreTabChipFocusNode.dispose();
    _favoritesTabChipFocusNode.dispose();
    _collectionsTabChipFocusNode.dispose();
    _playlistsTabChipFocusNode.dispose();
    _refreshButtonFocusNode.removeListener(_onRefreshFocusChange);
    _refreshButtonFocusNode.dispose();
    _profileButtonFocusNode.removeListener(_onProfileFocusChange);
    _profileButtonFocusNode.dispose();
    disposeTabNavigation();
    super.dispose();
  }

  void _updateState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  /// Helper method to get user-friendly error message from exception
  String _getErrorMessage(dynamic error, String context) {
    if (error is DioException) {
      return mapDioErrorToMessage(error, context: context);
    }

    return mapUnexpectedErrorToMessage(error, context: context);
  }

  /// Check if libraries come from multiple servers
  bool _hasMultipleServers(List<MediaLibrary> libraries) {
    final uniqueServerIds = libraries.where((lib) => lib.serverId != null).map((lib) => lib.serverId).toSet();
    return uniqueServerIds.length > 1;
  }

  /// Public method to load a library by key (called from MainScreen side nav)
  @override
  void loadLibraryByKey(String libraryGlobalKey) {
    _loadLibraryContent(libraryGlobalKey);
  }

  Future<void> _loadLibraryContent(String libraryGlobalKey) async {
    // Global Favorites view (sidebar "Favorites" item)
    if (libraryGlobalKey == kJellyfinFavoritesKey) {
      _updateState(() {
        _selectedLibraryGlobalKey = kJellyfinFavoritesKey;
        _errorMessage = null;
      });
      if (_isInitialLoad) _isInitialLoad = false;
      final storage = await StorageService.getInstance();
      await storage.saveSelectedLibraryKey(libraryGlobalKey);
      _loadGlobalFavorites();
      return;
    }

    // Get libraries from provider
    final librariesProvider = context.read<LibrariesProvider>();
    final allLibraries = librariesProvider.libraries;

    // Compute visible libraries based on current provider state
    final hiddenLibrariesProvider = Provider.of<HiddenLibrariesProvider>(context, listen: false);
    final hiddenKeys = hiddenLibrariesProvider.hiddenLibraryKeys;
    final visibleLibraries = allLibraries.where((lib) => !hiddenKeys.contains(lib.globalKey)).toList();

    // Find the library by key
    final libraryIndex = visibleLibraries.indexWhere((lib) => lib.globalKey == libraryGlobalKey);
    if (libraryIndex == -1) return; // Library not found or hidden

    final library = visibleLibraries[libraryIndex];

    final isChangingLibrary = !_isInitialLoad && _selectedLibraryGlobalKey != libraryGlobalKey;

    // When switching library, persist current library's tab so each library remembers its own tab
    if (isChangingLibrary && _selectedLibraryGlobalKey != null) {
      final storage = await StorageService.getInstance();
      await storage.saveLibraryTab(_selectedLibraryGlobalKey!, tabController.index);
    }
    if (!mounted) return;

    // Get the correct client for this library's server
    final client = context.getClientForLibrary(library);

    final newTabCount = _getEffectiveTabCount(client, library);

    TabController? oldController;
    if (newTabCount != _effectiveTabCount) {
      oldController = tabController;
      tabController = TabController(length: newTabCount, vsync: this);
      tabController.addListener(onTabChanged);
    }

    _updateState(() {
      _selectedLibraryGlobalKey = libraryGlobalKey;
      _errorMessage = null;
      _loadedTabs.clear();
      if (isChangingLibrary) _selectedFilters.clear();
      if (newTabCount != _effectiveTabCount) _effectiveTabCount = newTabCount;
    });

    // Dispose previous controller after the frame so TabBarView has switched to the new one
    if (oldController != null) {
      final toDispose = oldController;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        toDispose.removeListener(onTabChanged);
        toDispose.dispose();
      });
    }

    if (_isInitialLoad) _isInitialLoad = false;

    final storage = await StorageService.getInstance();
    await storage.saveSelectedLibraryKey(libraryGlobalKey);

    // Always start at first tab (Browse/Suggestions)
    if (tabController.index != 0) {
      _isRestoringTab = true;
      tabController.animateTo(0, duration: Duration.zero);
      _isRestoringTab = false;
    }

    // Focus is handled by onDataLoaded callbacks from each tab.
    // However, on first load the tab might finish loading before the tab index
    // is restored. Check if the current tab has already loaded and focus if so.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _selectedLibraryGlobalKey == libraryGlobalKey && _loadedTabs.contains(tabController.index) && InputModeTracker.isKeyboardMode(context)) {
        _focusCurrentTab();
      }
    });

    // Cancel any existing requests
    _cancelToken?.cancel();
    _cancelToken = CancelToken();
    final currentRequestId = ++_requestId;

    _updateState(() {
      _currentPage = 0;
      _hasMoreItems = true;
      _items = [];
    });

    try {
      // For Jellyfin Collections/Playlists library (single-tab view), skip browse content load
      if (newTabCount > 1) {
        await _loadSortOptions(library);
        final filtersWithSort = _buildFiltersWithSort();
        await _loadAllPagesSequentially(library, filtersWithSort, currentRequestId, client);
      }
    } catch (e) {
      // Ignore cancellation errors
      if (e is DioException && e.type == DioExceptionType.cancel) {
        return;
      }

      _updateState(() {
        _errorMessage = _getErrorMessage(e, 'library content');
      });
    }
  }

  /// Load favorites per library for the global Favorites view.
  Future<void> _loadGlobalFavorites() async {
    _updateState(() {
      _areGlobalFavoritesLoading = true;
      _globalFavoritesError = null;
    });

    try {
      final librariesProvider = context.read<LibrariesProvider>();
      final hiddenLibrariesProvider = context.read<HiddenLibrariesProvider>();
      final allLibraries = librariesProvider.libraries;
      final hiddenKeys = hiddenLibrariesProvider.hiddenLibraryKeys;
      final visibleLibraries = allLibraries
          .where((lib) => !hiddenKeys.contains(lib.globalKey))
          .where((lib) {
            final t = lib.type.toLowerCase();
            return t == 'movie' || t == 'show';
          })
          .toList();

      final hubs = <Hub>[];
      for (final lib in visibleLibraries) {
        if (!mounted) return;
        final client = context.getClientForLibrary(lib);
        try {
          final items = await client.getLibraryFavorites(lib.key, limit: 20);
          final tagged = items
              .map((item) => item.copyWith(serverId: lib.serverId, serverName: lib.serverName))
              .toList();
          if (tagged.isNotEmpty) {
            hubs.add(Hub(
              hubKey: 'favorites_${lib.globalKey}',
              title: lib.title,
              type: lib.type,
              size: tagged.length,
              more: tagged.length >= 20,
              items: tagged,
              serverId: lib.serverId,
              serverName: lib.serverName,
            ));
          }
        } catch (e) {
          appLogger.w('Failed to load favorites for ${lib.title}', error: e);
        }
      }

      if (!mounted) return;
      _updateState(() {
        _globalFavoritesHubs = hubs;
        _areGlobalFavoritesLoading = false;
        _globalFavoritesError = null;
      });
      // Focus the first hub after data loads and widgets are built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedLibraryGlobalKey == kJellyfinFavoritesKey && !suppressAutoFocus && InputModeTracker.isKeyboardMode(context)) {
          _focusFirstGlobalFavoritesHub();
        }
      });
    } catch (e) {
      if (!mounted) return;
      _updateState(() {
        _globalFavoritesError = _getErrorMessage(e, 'favorites');
        _areGlobalFavoritesLoading = false;
      });
    }
  }

  /// Load all pages sequentially until all items are fetched
  Future<void> _loadAllPagesSequentially(
    MediaLibrary library,
    Map<String, String> filtersWithSort,
    int requestId,
    JellyfinClient client,
  ) async {
    while (_hasMoreItems && requestId == _requestId) {
      try {
        final items = await client.getLibraryContent(
          library.key,
          start: _currentPage * _pageSize,
          size: _pageSize,
          filters: filtersWithSort,
          cancelToken: _cancelToken,
        );

        // Tag items with server info for multi-server support
        final taggedItems = items
            .map((item) => item.copyWith(serverId: library.serverId, serverName: library.serverName))
            .toList();

        // Check if request is still valid
        if (requestId != _requestId) {
          return; // Request was superseded
        }

        _updateState(() {
          _items.addAll(taggedItems);
          _currentPage++;
          _hasMoreItems = taggedItems.length >= _pageSize;
        });
      } catch (e) {
        // Check if it's a cancellation
        if (e is DioException && e.type == DioExceptionType.cancel) {
          return;
        }

        // For other errors, update state and rethrow
        _updateState(() {
          _hasMoreItems = false;
        });
        rethrow;
      }
    }
  }

  Future<void> _loadSortOptions(MediaLibrary library) async {
    try {
      final client = context.getClientForLibrary(library);

      final sortOptions = await client.getLibrarySorts(library.key, libraryType: library.type);

      // Load saved sort preference for this library
      final storage = await StorageService.getInstance();
      final savedSortData = storage.getLibrarySort(library.globalKey);

      // Find the saved sort in the options
      LibrarySort? savedSort;
      bool descending = false;

      if (savedSortData != null) {
        final sortKey = savedSortData['key'] as String?;
        if (sortKey != null) {
          savedSort = sortOptions.firstWhere((s) => s.key == sortKey, orElse: () => sortOptions.first);
          descending = (savedSortData['descending'] as bool?) ?? false;
        } else {
          savedSort = sortOptions.first;
        }
      } else {
        savedSort = sortOptions.first;
      }

      _updateState(() {
        _selectedSort = savedSort;
        _isSortDescending = descending;
      });
    } catch (e) {
      _updateState(() {
        _selectedSort = null;
        _isSortDescending = false;
      });
    }
  }

  Map<String, String> _buildFiltersWithSort() {
    final filtersWithSort = Map<String, String>.from(_selectedFilters);
    if (_selectedSort != null) {
      filtersWithSort['sort'] = _selectedSort!.getSortKey(descending: _isSortDescending);
    }
    return filtersWithSort;
  }

  @override
  void updateItemInLists(String itemId, MediaMetadata updatedMetadata) {
    final index = _items.indexWhere((item) => item.itemId == itemId);
    if (index != -1) {
      _items[index] = updatedMetadata;
    }
  }

  // Public method to refresh content (for normal navigation)
  @override
  void refresh() {
    // Reinitialize with current libraries
    _initializeWithLibraries();
  }

  void _refreshCurrentTab() {
    if (_effectiveTabCount == 1 && tabController.index == 0) {
      final lib = _getSelectedLibrary();
      if (lib != null) {
        final key = lib.type.toLowerCase() == 'collection' ? _collectionsTabKey : _playlistsTabKey;
        (key.currentState as dynamic)?.refresh();
      }
      return;
    }
    final key = switch (tabController.index) {
      0 => _browseTabKey,
      1 => _recommendedTabKey,
      2 => _favoritesTabKey,
      3 => _effectiveTabCount == 4 ? _genreTabKey : _collectionsTabKey,
      4 => _playlistsTabKey,
      _ => null,
    };
    (key?.currentState as dynamic)?.refresh();
  }

  // Public method to fully reload all content (for profile switches)
  @override
  void fullRefresh() {
    appLogger.d('LibrariesScreen.fullRefresh() called - reloading all content');
    setState(() {
      _selectedLibraryGlobalKey = null;
      _selectedFilters.clear();
      _items.clear();
      _errorMessage = null;
    });

    // Reinitialize with current libraries from provider
    _initializeWithLibraries();
  }

  /// Get set of library names that appear more than once (not globally unique)
  Set<String> _getNonUniqueLibraryNames(List<MediaLibrary> libraries) {
    final nameCounts = <String, int>{};
    for (final lib in libraries) {
      nameCounts[lib.title] = (nameCounts[lib.title] ?? 0) + 1;
    }
    return nameCounts.entries.where((e) => e.value > 1).map((e) => e.key).toSet();
  }

  /// Build dropdown menu items with server subtitle for non-unique names
  List<PopupMenuEntry<String>> _buildGroupedLibraryMenuItems(List<MediaLibrary> visibleLibraries) {
    // Find which library names are not unique
    final nonUniqueNames = _getNonUniqueLibraryNames(visibleLibraries);

    return visibleLibraries.map((library) {
      final isSelected = library.globalKey == _selectedLibraryGlobalKey;
      final showServerName = nonUniqueNames.contains(library.title) && library.serverName != null;

      return PopupMenuItem<String>(
        value: library.globalKey,
        child: Row(
          children: [
            AppIcon(
              ContentTypeHelper.getLibraryIcon(library.type),
              fill: 1,
              size: 20,
              color: isSelected ? Theme.of(context).colorScheme.primary : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    library.title,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? Theme.of(context).colorScheme.primary : null,
                    ),
                  ),
                  if (showServerName)
                    Text(
                      library.serverName!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildTabChip(String label, int index) {
    final isSelected = tabController.index == index;

    return FocusableTabChip(
      label: label,
      isSelected: isSelected,
      focusNode: getTabChipFocusNode(index),
      onSelect: () {
        if (isSelected) {
          _focusCurrentTab();
        } else {
          setState(() => tabController.index = index);
        }
      },
      onNavigateLeft: index > 0
          ? () {
              final newIndex = index - 1;
              setState(() {
                suppressAutoFocus = true;
                tabController.index = newIndex;
              });
              getTabChipFocusNode(newIndex).requestFocus();
            }
          : onTabBarBack,
      onNavigateRight: index < tabCount - 1
          ? () {
              final newIndex = index + 1;
              setState(() {
                suppressAutoFocus = true;
                tabController.index = newIndex;
              });
              getTabChipFocusNode(newIndex).requestFocus();
            }
          : () {
              _refreshButtonFocusNode.requestFocus();
            },
      onNavigateDown: _focusCurrentTabFromTabBar,
      onNavigateUp: () {
        _scrollOuterToTopIfNeeded();
        _refreshButtonFocusNode.requestFocus();
      },
      onBack: onTabBarBack,
    );
  }

  String _browseTabLabel(MediaLibrary library) {
    final lt = library.type.toLowerCase();
    if (lt == 'movie') return t.libraries.tabs.movies;
    if (lt == 'show') return t.libraries.tabs.shows;
    return t.libraries.tabs.browse;
  }

  List<Widget> _buildTabChipsForCurrentLibrary(MediaLibrary selectedLibrary) {
    if (_effectiveTabCount == 4) {
      return [
        _buildTabChip(_browseTabLabel(selectedLibrary), 0),
        const SizedBox(width: 8),
        _buildTabChip(t.libraries.tabs.suggestions, 1),
        const SizedBox(width: 8),
        _buildTabChip(t.libraries.tabs.favorites, 2),
        const SizedBox(width: 8),
        _buildTabChip(t.libraries.tabs.genres, 3),
      ];
    }
    if (_effectiveTabCount == 3) {
      return [
        _buildTabChip(_browseTabLabel(selectedLibrary), 0),
        const SizedBox(width: 8),
        _buildTabChip(t.libraries.tabs.suggestions, 1),
        const SizedBox(width: 8),
        _buildTabChip(t.libraries.tabs.favorites, 2),
      ];
    }
    if (_effectiveTabCount == 1) {
      final isCollection = selectedLibrary.type.toLowerCase() == 'collection';
      return [
        Text(
          isCollection ? t.libraries.tabs.collections : t.libraries.tabs.playlists,
          style: Theme.of(context).appBarTheme.titleTextStyle ?? Theme.of(context).textTheme.titleLarge,
        ),
      ];
    }
    return [
      _buildTabChip(_browseTabLabel(selectedLibrary), 0),
      const SizedBox(width: 8),
      _buildTabChip(t.libraries.tabs.suggestions, 1),
      const SizedBox(width: 8),
      _buildTabChip(t.libraries.tabs.favorites, 2),
      const SizedBox(width: 8),
      _buildTabChip(t.libraries.tabs.collections, 3),
      const SizedBox(width: 8),
      _buildTabChip(t.libraries.tabs.playlists, 4),
    ];
  }

  List<Widget> _buildTabViewChildren(MediaLibrary selectedLibrary) {
    if (_effectiveTabCount == 4) {
      return [
        LibraryBrowseTab(
          key: _browseTabKey,
          library: selectedLibrary,
          isActive: tabController.index == 0,
          suppressAutoFocus: suppressAutoFocus,
          onDataLoaded: () => _handleTabDataLoaded(0),
          onBack: _onContentNavigateUp,
        ),
        LibraryRecommendedTab(
          key: _recommendedTabKey,
          library: selectedLibrary,
          isActive: tabController.index == 1,
          suppressAutoFocus: suppressAutoFocus,
          onDataLoaded: () => _handleTabDataLoaded(1),
          onBack: _onContentNavigateUp,
        ),
        LibraryFavoritesTab(
          key: _favoritesTabKey,
          library: selectedLibrary,
          isActive: tabController.index == 2,
          suppressAutoFocus: suppressAutoFocus,
          onDataLoaded: () => _handleTabDataLoaded(2),
          onBack: _onContentNavigateUp,
          onBackToNavigation: _onContentBack,
        ),
        LibraryGenreTab(
          key: _genreTabKey,
          library: selectedLibrary,
          isActive: tabController.index == 3,
          suppressAutoFocus: suppressAutoFocus,
          onDataLoaded: () => _handleTabDataLoaded(3),
          onBack: _onContentNavigateUp,
        ),
      ];
    }
    if (_effectiveTabCount == 3) {
      return [
        LibraryBrowseTab(
          key: _browseTabKey,
          library: selectedLibrary,
          isActive: tabController.index == 0,
          suppressAutoFocus: suppressAutoFocus,
          onDataLoaded: () => _handleTabDataLoaded(0),
          onBack: _onContentNavigateUp,
        ),
        LibraryRecommendedTab(
          key: _recommendedTabKey,
          library: selectedLibrary,
          isActive: tabController.index == 1,
          suppressAutoFocus: suppressAutoFocus,
          onDataLoaded: () => _handleTabDataLoaded(1),
          onBack: _onContentNavigateUp,
        ),
        LibraryFavoritesTab(
          key: _favoritesTabKey,
          library: selectedLibrary,
          isActive: tabController.index == 2,
          suppressAutoFocus: suppressAutoFocus,
          onDataLoaded: () => _handleTabDataLoaded(2),
          onBack: _onContentNavigateUp,
          onBackToNavigation: _onContentBack,
        ),
      ];
    }
    if (_effectiveTabCount == 1) {
      final isCollection = selectedLibrary.type.toLowerCase() == 'collection';
      return [
        if (isCollection)
          LibraryCollectionsTab(
            key: _collectionsTabKey,
            library: selectedLibrary,
            isActive: true,
            suppressAutoFocus: suppressAutoFocus,
            onDataLoaded: () => _handleTabDataLoaded(0),
            onBack: _onContentNavigateUp,
            onBackToNavigation: _onContentBack,
          )
        else
          LibraryPlaylistsTab(
            key: _playlistsTabKey,
            library: selectedLibrary,
            isActive: true,
            suppressAutoFocus: suppressAutoFocus,
            onDataLoaded: () => _handleTabDataLoaded(0),
            onBack: _onContentNavigateUp,
            onBackToNavigation: _onContentBack,
          ),
      ];
    }
    return [
      LibraryBrowseTab(
        key: _browseTabKey,
        library: selectedLibrary,
        isActive: tabController.index == 0,
        suppressAutoFocus: suppressAutoFocus,
        onDataLoaded: () => _handleTabDataLoaded(0),
        onBack: _onContentNavigateUp,
      ),
      LibraryRecommendedTab(
        key: _recommendedTabKey,
        library: selectedLibrary,
        isActive: tabController.index == 1,
        suppressAutoFocus: suppressAutoFocus,
        onDataLoaded: () => _handleTabDataLoaded(1),
        onBack: _onContentNavigateUp,
      ),
      LibraryFavoritesTab(
        key: _favoritesTabKey,
        library: selectedLibrary,
        isActive: tabController.index == 2,
        suppressAutoFocus: suppressAutoFocus,
        onDataLoaded: () => _handleTabDataLoaded(2),
        onBack: _onContentNavigateUp,
        onBackToNavigation: _onContentBack,
      ),
      LibraryCollectionsTab(
        key: _collectionsTabKey,
        library: selectedLibrary,
        isActive: tabController.index == 3,
        suppressAutoFocus: suppressAutoFocus,
        onDataLoaded: () => _handleTabDataLoaded(3),
        onBack: _onContentNavigateUp,
        onBackToNavigation: _onContentBack,
      ),
      LibraryPlaylistsTab(
        key: _playlistsTabKey,
        library: selectedLibrary,
        isActive: tabController.index == 4,
        suppressAutoFocus: suppressAutoFocus,
        onDataLoaded: () => _handleTabDataLoaded(4),
        onBack: _onContentNavigateUp,
        onBackToNavigation: _onContentBack,
      ),
    ];
  }

  /// Build the app bar title - either dropdown on mobile or tab chips on desktop
  Widget _buildAppBarTitle(List<MediaLibrary> visibleLibraries, MediaLibrary? selectedLibrary) {
    if (visibleLibraries.isEmpty || _selectedLibraryGlobalKey == null) {
      return Text(
        t.libraries.title,
        style: Theme.of(context).appBarTheme.titleTextStyle ?? Theme.of(context).textTheme.titleLarge,
      );
    }

    if (_selectedLibraryGlobalKey == kJellyfinFavoritesKey) {
      return Text(
        t.libraries.tabs.favorites,
        style: Theme.of(context).appBarTheme.titleTextStyle ?? Theme.of(context).textTheme.titleLarge,
      );
    }

    if (PlatformDetector.shouldUseSideNavigation(context)) {
      final titleStyle = Theme.of(context).appBarTheme.titleTextStyle ?? Theme.of(context).textTheme.titleLarge;
      if (_effectiveTabCount == 1) {
        final isCollection = selectedLibrary?.type.toLowerCase() == 'collection';
        return Text(
          isCollection ? t.libraries.tabs.collections : t.libraries.tabs.playlists,
          style: titleStyle,
        );
      }
      // Movies/Shows: tabs only (no library title)
      final chips = <Widget>[];
      if (_effectiveTabCount == 4) {
        chips.addAll([
          _buildTabChip(_browseTabLabel(selectedLibrary!), 0),
          const SizedBox(width: 8),
          _buildTabChip(t.libraries.tabs.suggestions, 1),
          const SizedBox(width: 8),
          _buildTabChip(t.libraries.tabs.favorites, 2),
          const SizedBox(width: 8),
          _buildTabChip(t.libraries.tabs.genres, 3),
        ]);
      } else if (_effectiveTabCount == 3) {
        chips.addAll([
          _buildTabChip(_browseTabLabel(selectedLibrary!), 0),
          const SizedBox(width: 8),
          _buildTabChip(t.libraries.tabs.suggestions, 1),
          const SizedBox(width: 8),
          _buildTabChip(t.libraries.tabs.favorites, 2),
        ]);
      } else {
        chips.addAll([
          _buildTabChip(_browseTabLabel(selectedLibrary!), 0),
          const SizedBox(width: 8),
          _buildTabChip(t.libraries.tabs.suggestions, 1),
          const SizedBox(width: 8),
          _buildTabChip(t.libraries.tabs.favorites, 2),
          const SizedBox(width: 8),
          _buildTabChip(t.libraries.tabs.collections, 3),
          const SizedBox(width: 8),
          _buildTabChip(t.libraries.tabs.playlists, 4),
        ]);
      }
      return Row(mainAxisSize: MainAxisSize.min, children: chips);
    }

    return _buildLibraryDropdownTitle(visibleLibraries);
  }

  Widget _buildLibraryDropdownTitle(List<MediaLibrary> visibleLibraries) {
    final selectedLibrary = visibleLibraries.firstWhere(
      (lib) => lib.globalKey == _selectedLibraryGlobalKey,
      orElse: () => visibleLibraries.first,
    );

    return Semantics(
      label: t.libraries.selectLibrary,
      button: true,
      excludeSemantics: true,
      child: PopupMenuButton<String>(
        key: _libraryDropdownKey,
        offset: const Offset(0, 48),
        tooltip: null,
        onSelected: (libraryGlobalKey) {
          _loadLibraryContent(libraryGlobalKey);
        },
        itemBuilder: (context) => _buildGroupedLibraryMenuItems(visibleLibraries),
        child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(ContentTypeHelper.getLibraryIcon(selectedLibrary.type), fill: 1, size: 20),
            const SizedBox(width: 8),
            if (_hasMultipleServers(visibleLibraries) && selectedLibrary.serverName != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(selectedLibrary.title, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    selectedLibrary.serverName!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              )
            else
              Text(selectedLibrary.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(width: 4),
            const AppIcon(Symbols.arrow_drop_down_rounded, fill: 1, size: 24),
          ],
        ),
      ),
    ),
    );
  }

  /// Slivers for the global Favorites view: title + one row per library.
  List<Widget> _buildGlobalFavoritesSlivers() {
    if (_areGlobalFavoritesLoading) {
      return [const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))];
    }
    if (_globalFavoritesError != null) {
      return [
        SliverFillRemaining(
          child: ErrorStateWidget(
            message: _globalFavoritesError!,
            icon: Symbols.error_outline_rounded,
            onRetry: _loadGlobalFavorites,
          ),
        ),
      ];
    }
    if (_globalFavoritesHubs.isEmpty) {
      return [
        SliverFillRemaining(
          child: Center(
            child: EmptyStateWidget(
              message: t.libraries.noFavorites,
              icon: Symbols.favorite_rounded,
            ),
          ),
        ),
      ];
    }
    // Ensure we have keys for each hub (for D-pad focus)
    while (_globalFavoritesHubKeys.length < _globalFavoritesHubs.length) {
      _globalFavoritesHubKeys.add(GlobalKey<HubSectionState>());
    }
    if (_globalFavoritesHubKeys.length > _globalFavoritesHubs.length) {
      _globalFavoritesHubKeys.length = _globalFavoritesHubs.length;
    }

    return [
      for (var i = 0; i < _globalFavoritesHubs.length; i++) ...[
        SliverToBoxAdapter(
          child: HubSection(
            key: _globalFavoritesHubKeys[i],
            hub: _globalFavoritesHubs[i],
            icon: _globalFavoritesHubs[i].type.toLowerCase() == 'movie' ? Symbols.movie_rounded : Symbols.tv_rounded,
            onRefresh: (_) => _loadGlobalFavorites(),
            // No onHeaderTap: uses default HubSection behavior → push HubDetailScreen (full-screen, like home)
            onVerticalNavigation: (isUp) => _handleGlobalFavoritesVerticalNav(i, isUp),
            onNavigateUp: i == 0 ? () => _refreshButtonFocusNode.requestFocus() : null,
            onNavigateToSidebar: () => MainScreenFocusScope.of(context)?.focusSidebar(),
          ),
        ),
      ],
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Watch libraries provider for updates
    final librariesProvider = context.watch<LibrariesProvider>();
    final allLibraries = librariesProvider.libraries;
    final isLoadingLibraries = librariesProvider.isLoading;

    // Watch for hidden libraries changes to trigger rebuild
    final hiddenLibrariesProvider = context.watch<HiddenLibrariesProvider>();
    final hiddenKeys = hiddenLibrariesProvider.hiddenLibraryKeys;

    final visibleLibraries = allLibraries.where((lib) => !hiddenKeys.contains(lib.globalKey)).toList();
    MediaLibrary? selectedLibrary;
    if (_selectedLibraryGlobalKey != null) {
      final list = allLibraries.where((l) => l.globalKey == _selectedLibraryGlobalKey).toList();
      selectedLibrary = list.isNotEmpty ? list.first : null;
    }

    return OverlaySheetHost(
      child: Scaffold(
        body: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: CustomScrollView(
            controller: _outerScrollController,
            slivers: [
              // Match Home (Discover) app bar layout on desktop/TV; tighter on mobile
              Builder(
                builder: (context) {
                  final isPhone = PlatformDetector.isPhone(context);
                  final useSideNav = PlatformDetector.shouldUseSideNavigation(context);
                  // Header-only (Favorites, Collections, Playlists): use tighter height to reduce gap
                  final hasHeaderOnly = useSideNav &&
                      (selectedLibrary == null ||
                          _selectedLibraryGlobalKey == kJellyfinFavoritesKey ||
                          _effectiveTabCount == 1);
                  final toolbarContentHeight = isPhone ? 56.0 : (hasHeaderOnly ? 56.0 : 72.0);
                  final barPadding = isPhone ? 4.0 : (hasHeaderOnly ? 4.0 : 8.0);
                  return SliverAppBar(
                    pinned: true,
                    toolbarHeight: MediaQuery.of(context).padding.top + toolbarContentHeight,
                    title: null,
                    leading: null,
                    leadingWidth: 0,
                    automaticallyImplyLeading: false,
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    surfaceTintColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    scrolledUnderElevation: 0,
                    flexibleSpace: Padding(
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top,
                        left: 16,
                        right: 16,
                        bottom: barPadding,
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: barPadding),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildAppBarTitle(visibleLibraries, selectedLibrary),
                            ),
                            Focus(
                              focusNode: _refreshButtonFocusNode,
                              onKeyEvent: _handleRefreshKeyEvent,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _isRefreshFocused ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
                                  borderRadius: const BorderRadius.all(Radius.circular(20)),
                                ),
                                child: Semantics(
                                  label: t.common.refresh,
                                  button: true,
                                  excludeSemantics: true,
                                  child: IconButton(
                                    icon: const AppIcon(Symbols.refresh_rounded, fill: 1),
                                    tooltip: null,
                                    onPressed: () {
                                      if (_selectedLibraryGlobalKey == kJellyfinFavoritesKey) {
                                        _loadGlobalFavorites();
                                      } else {
                                        _refreshCurrentTab();
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                            Focus(
                              focusNode: _profileButtonFocusNode,
                              onKeyEvent: _handleProfileKeyEvent,
                              child: Builder(
                                builder: (context) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: _isProfileFocused ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
                                      borderRadius: const BorderRadius.all(Radius.circular(20)),
                                    ),
                                    child: ProfileAppBarButton(
                                      menuKey: _profileMenuKey,
                                      onSwitchProfile: () => _handleJellyfinSwitchProfile(context),
                                      onLogout: _handleLogout,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (isLoadingLibraries)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              else if (_errorMessage != null && visibleLibraries.isEmpty)
                SliverFillRemaining(
                  child: ErrorStateWidget(
                    message: _errorMessage!,
                    icon: Symbols.error_outline_rounded,
                    onRetry: () {
                      final librariesProvider = context.read<LibrariesProvider>();
                      librariesProvider.refresh();
                    },
                  ),
                )
              else if (visibleLibraries.isEmpty)
                SliverFillRemaining(
                  child: EmptyStateWidget(message: t.libraries.noLibrariesFound, icon: Symbols.video_library_rounded),
                )
              else ...[
                if (_selectedLibraryGlobalKey != null && selectedLibrary != null && !PlatformDetector.shouldUseSideNavigation(context))
                  SliverToBoxAdapter(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: PlatformDetector.isPhone(context) ? 4 : 8,
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _buildTabChipsForCurrentLibrary(selectedLibrary),
                        ),
                      ),
                    ),
                  ),

                if (_selectedLibraryGlobalKey == kJellyfinFavoritesKey)
                  ..._buildGlobalFavoritesSlivers()
                else if (_selectedLibraryGlobalKey != null && selectedLibrary != null)
                  SliverFillRemaining(
                    child: TabBarView(
                      key: ValueKey(_selectedLibraryGlobalKey),
                      controller: tabController,
                      physics: (PlatformDetector.isDesktop(context) || PlatformDetector.isTV()) ? const NeverScrollableScrollPhysics() : null,
                      children: _buildTabViewChildren(selectedLibrary),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
