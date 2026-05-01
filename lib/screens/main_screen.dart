import 'dart:async';
import 'dart:io' show Platform, exit;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyUpEvent, SystemNavigator;
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../../services/jellyfin_client.dart';
import '../i18n/strings.g.dart';
import '../utils/app_logger.dart';
import '../utils/dialogs.dart';

import '../utils/platform_detector.dart';
import '../utils/video_player_navigation.dart';
import '../main.dart';
import '../mixins/refreshable.dart';
import '../mixins/tab_visibility_aware.dart';
import '../navigation/navigation_tabs.dart';
import '../providers/multi_server_provider.dart';
import '../providers/server_state_provider.dart';
import '../providers/hidden_libraries_provider.dart';
import '../providers/libraries_provider.dart';
import '../providers/playback_state_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/jellyfin_profile_provider.dart';
import '../services/offline_watch_sync_service.dart';
import '../services/settings_service.dart';
import '../providers/offline_mode_provider.dart';

import '../services/server_registry.dart';
import '../services/storage_service.dart';
import '../screens/media_detail_screen.dart';
import '../constants/library_constants.dart';
import '../utils/desktop_window_padding.dart';
import '../widgets/overlay_sheet.dart';
import '../widgets/rotating_icon.dart';
import '../widgets/side_navigation_rail.dart';
import '../focus/dpad_navigator.dart';
import '../focus/key_event_utils.dart';
import 'discover_screen.dart';
import 'libraries/libraries_screen.dart';
import 'livetv/live_tv_screen.dart';
import 'search_screen.dart';
import 'downloads/downloads_screen.dart';
import 'settings/settings_screen.dart';

import 'profile/jellyfin_profile_switch_screen.dart';
import '../services/watch_next_service.dart';

/// Provides access to the main screen's focus control.
class MainScreenFocusScope extends InheritedWidget {
  final VoidCallback focusSidebar;
  final VoidCallback focusContent;
  final bool isSidebarFocused;

  const MainScreenFocusScope({
    super.key,
    required this.focusSidebar,
    required this.focusContent,
    required this.isSidebarFocused,
    required super.child,
  });

  static MainScreenFocusScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MainScreenFocusScope>();
  }

  @override
  bool updateShouldNotify(MainScreenFocusScope oldWidget) {
    return isSidebarFocused != oldWidget.isSidebarFocused;
  }
}

class MainScreen extends StatefulWidget {
  final JellyfinClient? client;
  final bool isOfflineMode;

  const MainScreen({super.key, this.client, this.isOfflineMode = false});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with RouteAware, WindowListener, WidgetsBindingObserver {
  late int _currentIndex;
  String? _selectedLibraryGlobalKey;

  /// Whether the app is in offline mode (no server connection)
  bool _isOffline = false;

  OfflineModeProvider? _offlineModeProvider;
  MultiServerProvider? _multiServerProvider;
  bool _lastHasLiveTv = false;

  /// Whether a reconnection attempt is in progress
  bool _isReconnecting = false;

  /// Cap how long the reconnect spinner can stay on screen, regardless of
  /// what the underlying reconnect future is doing. Without this the user can
  /// see the spinner for ~16s on a black-hole network — the reconnect itself
  /// keeps trying, but the UI gives up first.
  Timer? _reconnectingVisualTimer;

  /// Prevents double-pushing the profile selection screen
  bool _isShowingProfileSelection = false;

  late List<Widget> _screens;
  final GlobalKey<State<DiscoverScreen>> _discoverKey = GlobalKey();
  final GlobalKey<State<LibrariesScreen>> _librariesKey = GlobalKey();
  final GlobalKey<State<LiveTvScreen>> _liveTvKey = GlobalKey();
  final GlobalKey<State<SearchScreen>> _searchKey = GlobalKey();
  final GlobalKey<State<DownloadsScreen>> _downloadsKey = GlobalKey();
  final GlobalKey<State<SettingsScreen>> _settingsKey = GlobalKey();
  final GlobalKey<SideNavigationRailState> _sideNavKey = GlobalKey();

  // Focus management for sidebar/content switching
  final FocusScopeNode _sidebarFocusScope = FocusScopeNode(debugLabel: 'Sidebar');
  final FocusScopeNode _contentFocusScope = FocusScopeNode(debugLabel: 'Content');
  bool _isSidebarFocused = false;

  /// When true, show loading overlay to avoid flashing home before restoring to media detail.
  bool _isCheckingPendingReturn = false;

  @override
  void initState() {
    super.initState();
    _isOffline = widget.isOfflineMode;

    WidgetsBinding.instance.addObserver(this);

    // Sync sidebar focus state when focus moves via Tab or other means (not just our handlers).
    // On Windows, keyboard users can Tab from sidebar to content without triggering onNavigateRight.
    FocusManager.instance.addListener(_syncSidebarFocusFromPrimaryFocus);

    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      windowManager.addListener(this);
      windowManager.setPreventClose(true);
    }

    // Start on Downloads tab when in offline mode
    // In offline mode: visual index 0 = Downloads (screen 3), 1 = Settings (screen 4)
    // In online mode: indices match directly
    _currentIndex = 0;

    _screens = _buildScreens(_isOffline);

    // On TV when online: show loading until we check for pending external return
    if (!_isOffline && PlatformDetector.isTV()) {
      _isCheckingPendingReturn = true;
    }

    // Set up Watch Next deep link handling
    if (!_isOffline) {
      _setupWatchNextDeepLink();
    }

    // Set up Jellyfin profile and data invalidation (skip in offline mode)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_isOffline) {
        // Jellyfin: refresh profile list and set callback for switch profile
        final jellyfinProfileProvider = context.read<JellyfinProfileProvider>();
        await jellyfinProfileProvider.refresh();
        jellyfinProfileProvider.onAfterSwitch = _invalidateAllScreensForJellyfinSwitch;

        // On TV: check for pending external return while loading overlay is shown
        if (PlatformDetector.isTV()) {
          await _tryRestorePendingExternalReturn(
            onRestored: () {
              if (mounted) setState(() => _isCheckingPendingReturn = false);
            },
          );
        } else {
          _tryRestorePendingExternalReturn();
        }
      }

      // Focus content initially (replaces autofocus which caused focus stealing issues)
      // Skip if profile selection is on top — it manages its own focus.
      if (!_isSidebarFocused && !_isShowingProfileSelection) {
        _contentFocusScope.requestFocus();
      }
    });
  }

  /// Restore to media detail screen when returning from external app (e.g. trailer).
  /// Android TV often kills the process when opening YouTube; we save context before launch.
  /// [onRestored] is called when the overlay can be cleared (either after push, or when no restore).
  Future<void> _tryRestorePendingExternalReturn({VoidCallback? onRestored}) async {
    if (_isOffline || !mounted) {
      onRestored?.call();
      return;
    }
    try {
      final storage = await StorageService.getInstance();
      final pending = await storage.getPendingExternalReturn();
      if (pending == null || !mounted) {
        onRestored?.call();
        return;
      }
      await storage.clearPendingExternalReturn();
      if (!mounted) {
        onRestored?.call();
        return;
      }

      final multiServer = context.read<MultiServerProvider>();
      JellyfinClient? client;
      if (pending.serverId != null && pending.serverId!.isNotEmpty) {
        client = multiServer.getClientForServer(pending.serverId!);
      }
      client ??= multiServer.onlineServerIds.isNotEmpty
          ? multiServer.getClientForServer(multiServer.onlineServerIds.first)
          : null;
      if (client == null || !mounted) {
        onRestored?.call();
        return;
      }

      final metadata = await client.getMetadataWithImages(pending.itemId);
      if (metadata == null || !mounted) {
        onRestored?.call();
        return;
      }

      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, _, _) =>
              MediaDetailScreen(metadata: metadata, isOffline: false, onFirstBuild: onRestored),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    } catch (e) {
      appLogger.d('Pending external return restore failed: $e');
      onRestored?.call();
    }
  }

  /// Set up Watch Next deep link handling for Android TV launcher taps
  void _setupWatchNextDeepLink() {
    if (!Platform.isAndroid) return;

    final watchNext = WatchNextService();

    // Listen for deep links when app is already running (warm start)
    watchNext.onWatchNextTap = (contentId) {
      appLogger.d('Watch Next tap: $contentId');
      _handleWatchNextContentId(contentId);
    };

    // Check for pending deep link from cold start
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final contentId = await watchNext.getInitialDeepLink();
      if (contentId != null && mounted) {
        appLogger.d('Watch Next initial deep link: $contentId');
        _handleWatchNextContentId(contentId);
      }
    });
  }

  /// Handle a Watch Next content ID by fetching metadata and starting playback
  Future<void> _handleWatchNextContentId(String contentId) async {
    if (!mounted) return;

    final parsed = WatchNextService.parseContentId(contentId);
    if (parsed == null) {
      appLogger.w('Watch Next: invalid content ID: $contentId');
      return;
    }

    final (serverId, itemId) = parsed;

    try {
      final multiServer = context.read<MultiServerProvider>();
      final client = multiServer.getClientForServer(serverId);

      if (client == null) {
        appLogger.w('Watch Next: server $serverId not available');
        return;
      }

      final metadata = await client.getMetadataWithImages(itemId);

      if (metadata == null || !mounted) return;

      navigateToVideoPlayer(context, metadata: metadata);
    } catch (e) {
      appLogger.e('Watch Next: failed to navigate to media', error: e);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Listen for offline/online transitions to refresh navigation & screens
    // Note: We don't call _handleOfflineStatusChanged() immediately because
    // widget.isOfflineMode (from SetupScreen navigation) is authoritative for
    // initial state. The provider may not yet have received the server status
    // update due to initialization timing. The listener handles runtime changes.
    final provider = context.read<OfflineModeProvider?>();
    if (provider != null && provider != _offlineModeProvider) {
      _offlineModeProvider?.removeListener(_handleOfflineStatusChanged);
      _offlineModeProvider = provider;
      _offlineModeProvider!.addListener(_handleOfflineStatusChanged);
    }

    // Listen for Live TV / DVR availability changes
    final multiServer = context.read<MultiServerProvider>();
    if (multiServer != _multiServerProvider) {
      _multiServerProvider?.removeListener(_handleLiveTvChanged);
      _multiServerProvider = multiServer;
      _multiServerProvider!.addListener(_handleLiveTvChanged);
    }

    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_syncSidebarFocusFromPrimaryFocus);
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      windowManager.removeListener(this);
      windowManager.setPreventClose(false);
    }
    _offlineModeProvider?.removeListener(_handleOfflineStatusChanged);
    _multiServerProvider?.removeListener(_handleLiveTvChanged);
    _reconnectingVisualTimer?.cancel();
    _sidebarFocusScope.dispose();
    _contentFocusScope.dispose();

    super.dispose();
  }

  /// Sync _isSidebarFocused with actual focus. Called when focus moves via Tab or other
  /// means that don't go through _focusSidebar/_focusContent (e.g. Windows keyboard).
  void _syncSidebarFocusFromPrimaryFocus() {
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null || !mounted) return;

    final scope = primary.enclosingScope;
    if (scope == _contentFocusScope && _isSidebarFocused) {
      setState(() => _isSidebarFocused = false);
    } else if (scope == _sidebarFocusScope && !_isSidebarFocused) {
      setState(() => _isSidebarFocused = true);
    }
  }

  @override
  void onWindowClose() {
    exit(0);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isOffline && !_isShowingProfileSelection) {
      _showProfileSelectionOnResume();
    }
  }

  Future<void> _showProfileSelectionOnResume() async {
    final settingsService = await SettingsService.getInstance();
    if (!settingsService.getRequireProfileSelectionOnOpen()) return;
    if (!mounted) return;

    final jellyfinProfileProvider = context.read<JellyfinProfileProvider>();
    if (!jellyfinProfileProvider.hasMultipleUsers) return;

    _isShowingProfileSelection = true;
    await Navigator.of(context).push(MaterialPageRoute(builder: (context) => const JellyfinProfileSwitchScreen()));
    _isShowingProfileSelection = false;
  }

  List<Widget> _buildScreens(bool offline) {
    // In offline mode, only show Downloads and Settings
    if (offline) {
      return [DownloadsScreen(key: _downloadsKey), SettingsScreen(key: _settingsKey)];
    }

    final hasLiveTv = context.read<MultiServerProvider>().hasLiveTv;

    return [
      DiscoverScreen(key: _discoverKey, onBecameVisible: _onDiscoverBecameVisible),
      LibrariesScreen(
        key: _librariesKey,
        onLibraryOrderChanged: _onLibraryOrderChanged,
        onSelectedLibraryChanged: (key) {
          setState(() => _selectedLibraryGlobalKey = key);
        },
      ),
      if (hasLiveTv) LiveTvScreen(key: _liveTvKey),
      SearchScreen(key: _searchKey),
      DownloadsScreen(key: _downloadsKey),
      SettingsScreen(key: _settingsKey),
    ];
  }

  /// Normalize tab index when switching between offline/online modes.
  /// Preserves the current tab if it exists in the new mode, otherwise defaults to first tab.
  int _normalizeIndexForMode(int currentIndex, bool wasOffline, bool isOffline) {
    if (wasOffline == isOffline) return currentIndex;

    final oldTabs = _getVisibleTabs(wasOffline);
    final newTabs = _getVisibleTabs(isOffline);

    // Get the tab ID at the current index (or first tab if out of bounds)
    final currentTabId = currentIndex >= 0 && currentIndex < oldTabs.length
        ? oldTabs[currentIndex].id
        : oldTabs.first.id;

    // Find the same tab in the new mode's tab list
    final newIndex = newTabs.indexWhere((tab) => tab.id == currentTabId);
    return newIndex >= 0 ? newIndex : 0;
  }

  static const _reconnectVisualCap = Duration(seconds: 10);

  void _triggerReconnect() {
    // If already reconnecting, just extend the visual cap so a re-click
    // doesn't look like it cancelled (timer firing right after a click reads
    // as "my click did that"). Don't kick off a second underlying attempt —
    // the existing one is still in flight.
    if (_isReconnecting) {
      _reconnectingVisualTimer?.cancel();
      _reconnectingVisualTimer = Timer(_reconnectVisualCap, () {
        if (mounted && _isReconnecting) setState(() => _isReconnecting = false);
      });
      return;
    }

    // When forced offline, clear it first so reconnect can run
    final offlineProvider = context.read<OfflineModeProvider?>();
    if (offlineProvider?.isForcedOffline == true) {
      offlineProvider!.setForcedOffline(false);
    }

    setState(() => _isReconnecting = true);

    _reconnectingVisualTimer?.cancel();
    _reconnectingVisualTimer = Timer(_reconnectVisualCap, () {
      if (mounted && _isReconnecting) setState(() => _isReconnecting = false);
    });

    final serverManager = context.read<MultiServerProvider>().serverManager;
    serverManager.checkServerHealth();
    serverManager.reconnectOfflineServers().whenComplete(() {
      // Give a moment for status updates to propagate
      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted) return;
        _reconnectingVisualTimer?.cancel();
        if (_isReconnecting) setState(() => _isReconnecting = false);
      });
    });
  }

  void _handleGoOffline() {
    context.read<OfflineModeProvider>().setForcedOffline(true);
  }

  void _handleLiveTvChanged() {
    final hasLiveTv = _multiServerProvider?.hasLiveTv ?? false;
    if (hasLiveTv == _lastHasLiveTv) return;
    _lastHasLiveTv = hasLiveTv;

    setState(() {
      final currentTabId = _tabIdForIndex(_isOffline, _currentIndex);
      _screens = _buildScreens(_isOffline);
      // Restore the correct tab index after rebuilding
      final newIndex = NavigationTab.indexFor(currentTabId, isOffline: _isOffline, hasLiveTv: hasLiveTv);
      _currentIndex = newIndex >= 0 ? newIndex : 0;
    });
  }

  Future<void> _handleOfflineStatusChanged() async {
    final newOffline = _offlineModeProvider?.isOffline ?? widget.isOfflineMode;

    if (newOffline == _isOffline) return;

    final wasOffline = _isOffline;

    // When coming back online, refresh Live TV availability before rebuilding.
    // Fixes race: OfflineModeProvider notifies before checkLiveTvAvailability completes,
    // so _buildScreens would read hasLiveTv=false and omit the Live TV tab.
    if (!newOffline) {
      await context.read<MultiServerProvider>().checkLiveTvAvailability();
      if (!mounted) return;
    }

    setState(() {
      _isReconnecting = false;
      _isOffline = newOffline;
      _screens = _buildScreens(_isOffline);
      _selectedLibraryGlobalKey = _isOffline ? null : _selectedLibraryGlobalKey;

      if (_isOffline) {
        _currentIndex = _normalizeIndexForMode(_currentIndex, wasOffline, _isOffline);
      } else {
        // Coming back online: start at Home (consistent with cold start)
        _lastHasLiveTv = _multiServerProvider?.hasLiveTv ?? false;
        _currentIndex = 0;
      }
    });

    // Refresh sidebar focus after rebuilding navigation
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final activeKey = _getActiveSidebarKey();
        _sideNavKey.currentState?.focusActiveItem(targetKey: activeKey);
      });
    }
  }

  void _focusSidebar() {
    // Focus the item that represents the current view, not where the cursor was.
    // E.g. when viewing Collections, Back should land on Collections, not Movies.
    final activeKey = _getActiveSidebarKey();
    setState(() => _isSidebarFocused = true);
    _sidebarFocusScope.requestFocus();
    // Focus the active item after the focus scope has focus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sideNavKey.currentState?.focusActiveItem(targetKey: activeKey);
    });
  }

  /// Key for the sidebar item that represents the current view (for focus when returning from content).
  String? _getActiveSidebarKey() {
    final tabId = _tabIdForIndex(_isOffline, _currentIndex);
    switch (tabId) {
      case NavigationTabId.discover:
        return 'home';
      case NavigationTabId.libraries:
        if (_selectedLibraryGlobalKey == kJellyfinFavoritesKey) return 'favorites';
        return _selectedLibraryGlobalKey ?? 'libraries';
      case NavigationTabId.liveTv:
        return 'liveTv';
      case NavigationTabId.search:
        return 'search';
      case NavigationTabId.downloads:
        return 'downloads';
      case NavigationTabId.settings:
        return 'settings';
    }
  }

  void _focusContent() {
    setState(() => _isSidebarFocused = false);
    _contentFocusScope.requestFocus();
    // When content regains focus while on Discover, focus the hero section
    if (_currentIndex == 0 && !_isOffline) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_discoverKey.currentState case final TabVisibilityAware aware) {
          aware.onTabShown();
        }
      });
    }
    // When content regains focus while on Libraries, retry focusing the active tab
    if (_currentIndex == 1 && !_isOffline) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_librariesKey.currentState case final FocusableTab focusable) {
          focusable.focusActiveTabIfReady();
        }
      });
    }
    // When content regains focus while on Live TV, focus the active guide/whats-on tab
    final liveTvIndex = NavigationTab.indexFor(NavigationTabId.liveTv, isOffline: _isOffline, hasLiveTv: _hasLiveTv);
    if (_currentIndex == liveTvIndex && liveTvIndex >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_liveTvKey.currentState case final FocusableTab focusable) {
          focusable.focusActiveTabIfReady();
        }
      });
    }
    // When content regains focus while on Settings, restore focus to last focused setting
    final settingsIndex = NavigationTab.indexFor(
      NavigationTabId.settings,
      isOffline: _isOffline,
      hasLiveTv: _hasLiveTv,
    );
    if (_currentIndex == settingsIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_settingsKey.currentState case final FocusableTab focusable) {
          focusable.focusActiveTabIfReady();
        }
      });
    }
  }

  /// Suppress stray back events after a child route pops.
  /// On Android TV the platform popRoute can arrive before the key events,
  /// so BackKeySuppressorObserver misses them and they leak into _handleBackKey.
  bool _suppressBackAfterPop = false;

  KeyEventResult _handleBackKey(KeyEvent event) {
    if (_suppressBackAfterPop && event.logicalKey.isBackKey) {
      if (event is KeyUpEvent) _suppressBackAfterPop = false;
      return KeyEventResult.handled;
    }

    // [OverlaySheetHost] in library browse only excludes its child (the grid), not this
    // rail. While any overlay sheet is open, do not treat Back as "jump to sidebar" —
    // that races sheet refocus and leaves Escape on the rail instead of the dialog.
    if (OverlaySheetHost.anySheetOpen.value && event.logicalKey.isBackKey) {
      return KeyEventResult.ignored;
    }

    if (!_isSidebarFocused) {
      // Content focused → move to sidebar
      return handleBackKeyAction(event, _focusSidebar);
    }

    // Sidebar focused → exit app
    return handleBackKeyAction(event, () async {
      if (PlatformDetector.isTV()) {
        final settings = await SettingsService.getInstance();
        if (settings.getConfirmExitOnBack() && mounted) {
          final result = await showConfirmDialogWithCheckbox(
            context,
            title: t.common.exitConfirmTitle,
            message: t.common.exitConfirmMessage,
            confirmText: t.common.exit,
            checkboxLabel: t.common.dontAskAgain,
          );
          if (result.checked) {
            await settings.setConfirmExitOnBack(false);
          }
          if (!result.confirmed) return;
        }
      }
      SystemNavigator.pop();
    });
  }

  @override
  void didPush() {
    // Called when this route has been pushed (initial navigation)
    if (_currentIndex == 0 && !_isOffline) {
      _onDiscoverBecameVisible();
    }
  }

  @override
  void didPushNext() {
    // Called when a child route is pushed on top (e.g., video player)
    if (_currentIndex == 0 && !_isOffline) {
      if (_discoverKey.currentState case final TabVisibilityAware aware) {
        aware.onTabHidden();
      }
    }
  }

  @override
  void didPopNext() {
    // Suppress stray back key events from the pop that just returned us here
    _suppressBackAfterPop = true;
    // Auto-clear after 2 frames in case no back event arrives
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _suppressBackAfterPop = false;
      });
    });

    // Called when returning to this route from a child route (e.g., from video player)
    if (_currentIndex == 0 && !_isOffline) {
      if (_discoverKey.currentState case final TabVisibilityAware aware) {
        aware.onTabShown(scrollToTop: false);
      }
      _onDiscoverBecameVisible();
    }
  }

  void _onDiscoverBecameVisible() {
    appLogger.d('Navigated to home');
    // Refresh content when returning to discover page
    if (_discoverKey.currentState case final Refreshable refreshable) {
      refreshable.refresh();
    }
  }

  void _onLibraryOrderChanged() {
    // Refresh side navigation when library order changes
    _sideNavKey.currentState?.reloadLibraries();
  }

  /// Called when Jellyfin user is switched; reconnects with current server list and refreshes.
  Future<void> _invalidateAllScreensForJellyfinSwitch() async {
    appLogger.d('Invalidating all screen data due to Jellyfin profile switch');

    final multiServerProvider = context.read<MultiServerProvider>();
    final serverStateProvider = context.read<ServerStateProvider>();
    final hiddenLibrariesProvider = context.read<HiddenLibrariesProvider>();
    final librariesProvider = context.read<LibrariesProvider>();
    final playbackStateProvider = context.read<PlaybackStateProvider>();

    librariesProvider.clear();

    final storage = await StorageService.getInstance();
    final registry = ServerRegistry(storage);
    final registeredServers = await registry.getServers();

    if (registeredServers.isNotEmpty) {
      final clientId = storage.getClientIdentifier();
      final deviceId = await storage.getOrCreateDeviceId();
      final connectedCount = await multiServerProvider.reconnectWithServers(
        registeredServers,
        clientIdentifier: clientId,
        deviceId: deviceId,
      );
      appLogger.d('Reconnected to $connectedCount/${registeredServers.length} servers after Jellyfin profile switch');

      if (connectedCount > 0) {
        if (!mounted) return;
        context.read<OfflineWatchSyncService>().onServersConnected();
        librariesProvider.initialize(multiServerProvider.aggregationService);
        await librariesProvider.refresh();
      }
    }

    serverStateProvider.reset();
    hiddenLibrariesProvider.refresh();
    playbackStateProvider.clearShuffle();

    if (_discoverKey.currentState case final FullRefreshable refreshable) {
      refreshable.fullRefresh();
    }
    if (_librariesKey.currentState case final FullRefreshable refreshable) {
      refreshable.fullRefresh();
    }
    if (_searchKey.currentState case final FullRefreshable refreshable) {
      refreshable.fullRefresh();
    }
  }

  void _selectTab(int index) {
    final previousIndex = _currentIndex;
    setState(() {
      _currentIndex = index;
    });

    // Handle screen-specific logic
    final settingsIndex = NavigationTab.indexFor(
      NavigationTabId.settings,
      isOffline: _isOffline,
      hasLiveTv: _hasLiveTv,
    );

    // Skip online-only screen logic in offline mode
    if (!_isOffline) {
      // Pause/resume discover auto-scroll when switching tabs
      if (previousIndex == 0 && index != 0) {
        if (_discoverKey.currentState case final TabVisibilityAware aware) {
          aware.onTabHidden();
        }
      }
      // Notify discover screen when it becomes visible via tab switch
      if (index == 0) {
        if (previousIndex != 0) {
          if (_discoverKey.currentState case final TabVisibilityAware aware) {
            aware.onTabShown();
          }
        }
        _onDiscoverBecameVisible();
      }
      // Ensure the libraries screen applies focus when brought into view
      if (index == 1 && previousIndex != 1) {
        if (_librariesKey.currentState case final FocusableTab focusable) {
          focusable.focusActiveTabIfReady();
        }
      }
      // Ensure the Live TV screen applies focus when brought into view
      final liveTvIdx = NavigationTab.indexFor(NavigationTabId.liveTv, isOffline: _isOffline, hasLiveTv: _hasLiveTv);
      if (index == liveTvIdx && liveTvIdx >= 0 && previousIndex != liveTvIdx) {
        if (_liveTvKey.currentState case final FocusableTab focusable) {
          focusable.focusActiveTabIfReady();
        }
      }
      // Focus search input when selecting Search tab
      if (NavigationTab.isTabAtIndex(NavigationTabId.search, index, isOffline: _isOffline, hasLiveTv: _hasLiveTv)) {
        if (_searchKey.currentState case final SearchInputFocusable searchable) {
          searchable.focusSearchInput();
        }
      }
    }

    // Restore focus and refresh settings when switching to Settings tab (works in both online and offline mode)
    if (index == settingsIndex && previousIndex != settingsIndex) {
      if (_settingsKey.currentState case final TabVisibilityAware aware) {
        aware.onTabShown();
      }
      if (_settingsKey.currentState case final FocusableTab focusable) {
        focusable.focusActiveTabIfReady();
      }
    }
  }

  /// Handle library selection from side navigation rail
  void _selectLibrary(String libraryGlobalKey) {
    setState(() {
      _selectedLibraryGlobalKey = libraryGlobalKey;
      _currentIndex = 1; // Switch to Libraries tab
    });
    // Tell LibrariesScreen to load this library
    if (_librariesKey.currentState case final LibraryLoadable loadable) {
      loadable.loadLibraryByKey(libraryGlobalKey);
    }
    if (_librariesKey.currentState case final FocusableTab focusable) {
      focusable.focusActiveTabIfReady();
    }
  }

  /// Whether the Live TV tab is currently visible
  bool get _hasLiveTv {
    try {
      return context.read<MultiServerProvider>().hasLiveTv;
    } catch (_) {
      return false;
    }
  }

  /// Get navigation tabs filtered by offline mode
  List<NavigationTab> _getVisibleTabs(bool isOffline) {
    return NavigationTab.getVisibleTabs(isOffline: isOffline, hasLiveTv: _hasLiveTv);
  }

  /// Get the tab ID for a given index, clamping to the available range.
  NavigationTabId _tabIdForIndex(bool isOffline, int index) {
    final tabs = _getVisibleTabs(isOffline);
    if (tabs.isEmpty) return NavigationTabId.discover;
    final safeIndex = index.clamp(0, tabs.length - 1).toInt();
    return tabs[safeIndex].id;
  }

  /// Build navigation destinations for bottom navigation bar.
  List<NavigationDestination> _buildNavDestinations(bool isOffline) {
    return _getVisibleTabs(isOffline).map((tab) => tab.toDestination()).toList();
  }

  @override
  Widget build(BuildContext context) {
    final useSideNav = PlatformDetector.shouldUseSideNavigation(context);

    if (useSideNav) {
      return Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          final alwaysExpanded = settingsProvider.alwaysKeepSidebarOpen;
          final contentLeftPadding = alwaysExpanded
              ? SideNavigationRailState.expandedWidth
              : SideNavigationRailState.collapsedWidth;

          return PopScope(
            canPop: false, // Prevent system back from popping on Android TV
            // ignore: no-empty-block - required callback, back navigation handled by _handleBackKey
            onPopInvokedWithResult: (didPop, result) {},
            child: Focus(
              onKeyEvent: (node, event) => _handleBackKey(event),
              child: MainScreenFocusScope(
                focusSidebar: _focusSidebar,
                focusContent: _focusContent,
                isSidebarFocused: _isSidebarFocused,
                child: SideNavigationScope(
                  child: Stack(
                    children: [
                      // Content with animated left padding based on sidebar state
                      Positioned.fill(
                        child: AnimatedPadding(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          padding: EdgeInsets.only(left: contentLeftPadding),
                          child: FocusScope(
                            node: _contentFocusScope,
                            // No autofocus - we control focus programmatically to prevent
                            // autofocus from stealing focus back after setState() rebuilds
                            child: IndexedStack(
                              index: _screens.isEmpty ? 0 : _currentIndex.clamp(0, _screens.length - 1),
                              children: _screens,
                            ),
                          ),
                        ),
                      ),
                      // Sidebar overlays content when expanded (unless always expanded)
                      Positioned(
                        top: 0,
                        bottom: 0,
                        left: 0,
                        child: ValueListenableBuilder<bool>(
                          valueListenable: OverlaySheetHost.anySheetOpen,
                          builder: (context, anySheetOpen, _) {
                            return ExcludeFocus(
                              excluding: anySheetOpen,
                              child: FocusScope(
                                node: _sidebarFocusScope,
                                child: Builder(
                                  builder: (context) {
                                    final offlineProvider = context.watch<OfflineModeProvider?>();
                                    return SideNavigationRail(
                                      key: _sideNavKey,
                                      selectedIndex: _currentIndex,
                                      selectedLibraryKey: _selectedLibraryGlobalKey,
                                      isOfflineMode: _isOffline,
                                      isSidebarFocused: _isSidebarFocused,
                                      alwaysExpanded: alwaysExpanded,
                                      isReconnecting: _isReconnecting,
                                      isForcedOffline: offlineProvider?.isForcedOffline ?? false,
                                      connectionAvailableWhenForced:
                                          offlineProvider?.connectionAvailableWhenForced ?? false,
                                      onGoOffline: offlineProvider != null ? _handleGoOffline : null,
                                      jellyfinFavoritesKey: context.watch<MultiServerProvider>().hasConnectedServers
                                          ? kJellyfinFavoritesKey
                                          : null,
                                      onDestinationSelected: (index) {
                                        _selectTab(index);
                                        _focusContent();
                                      },
                                      onLibrarySelected: (key) {
                                        _selectLibrary(key);
                                        _focusContent();
                                      },
                                      onNavigateToContent: _focusContent,
                                      onReconnect: _triggerReconnect,
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // Loading overlay while checking for pending external return (TV)
                      if (_isCheckingPendingReturn)
                        Positioned.fill(
                          child: ColoredBox(
                            color: Theme.of(context).colorScheme.surface,
                            child: Center(
                              child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return Scaffold(
      body: IndexedStack(index: _screens.isEmpty ? 0 : _currentIndex.clamp(0, _screens.length - 1), children: _screens),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reconnect bar when offline
          if (_isOffline)
            Builder(
              builder: (context) {
                final isForcedOffline = context.watch<OfflineModeProvider?>()?.isForcedOffline ?? false;
                final connectionAvailable =
                    context.watch<OfflineModeProvider?>()?.connectionAvailableWhenForced ?? false;
                final label = isForcedOffline ? t.common.goOnline : t.common.reconnect;
                return Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: InkWell(
                    onTap: _triggerReconnect,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          RotatingIcon(
                            icon: _isReconnecting ? Symbols.sync_rounded : Symbols.wifi_rounded,
                            spin: _isReconnecting,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              if (connectionAvailable)
                                Text(
                                  t.common.connectionAvailable,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _selectTab,
            destinations: _buildNavDestinations(_isOffline),
          ),
        ],
      ),
    );
  }
}
