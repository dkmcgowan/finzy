import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:io' show Platform;
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';
import 'screens/main_screen.dart';
import 'screens/auth_screen.dart';
import 'services/storage_service.dart';
import 'services/macos_titlebar_service.dart';
import 'services/fullscreen_state_manager.dart';
import 'services/settings_service.dart';
import 'utils/platform_detector.dart';

import 'services/gamepad_service.dart';
import 'providers/user_profile_provider.dart';
import 'providers/jellyfin_profile_provider.dart';
import 'providers/multi_server_provider.dart';
import 'providers/server_state_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/hidden_libraries_provider.dart';
import 'providers/libraries_provider.dart';
import 'providers/playback_state_provider.dart';
import 'providers/download_provider.dart';
import 'providers/offline_mode_provider.dart';
import 'providers/offline_watch_provider.dart';
import 'providers/shader_provider.dart';
import 'utils/snackbar_helper.dart';

import 'services/multi_server_manager.dart';
import 'services/offline_watch_sync_service.dart';
import 'services/server_connection_orchestrator.dart';
import 'services/data_aggregation_service.dart';
import 'services/in_app_review_service.dart';
import 'models/registered_server.dart';
import 'services/jellyfin_auth_service.dart';
import 'services/server_registry.dart';
import 'services/download_manager_service.dart';
import 'services/pip_service.dart';
import 'services/download_storage_service.dart';
import 'services/api_cache.dart';
import 'database/app_database.dart';
import 'utils/app_logger.dart';
import 'utils/orientation_helper.dart';
import 'utils/language_codes.dart';
import 'i18n/strings.g.dart';
import 'focus/focusable_wrapper.dart';
import 'focus/input_mode_tracker.dart';
import 'focus/key_event_utils.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Git commit hash from build (--dart-define=GIT_COMMIT=xxx). Empty when not set.
const String gitCommit = String.fromEnvironment('GIT_COMMIT');

// Workaround for Flutter bug #177992: iPadOS 26.1+ misinterprets fake touch events
// at (0,0) as barrier taps, causing modals to dismiss immediately.
// Remove when Flutter PR #179643 is merged.
bool _zeroOffsetPointerGuardInstalled = false;

void _installZeroOffsetPointerGuard() {
  if (_zeroOffsetPointerGuardInstalled) return;
  GestureBinding.instance.pointerRouter.addGlobalRoute(_absorbZeroOffsetPointerEvent);
  _zeroOffsetPointerGuardInstalled = true;
}

void _absorbZeroOffsetPointerEvent(PointerEvent event) {
  if (event.position == Offset.zero) {
    GestureBinding.instance.cancelPointer(event.pointer);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installZeroOffsetPointerGuard(); // Workaround for iPadOS 26.1+ modal dismissal bug

  // Initialize settings first to get saved locale
  final settings = await SettingsService.getInstance();
  final savedLocale = settings.getAppLocale();

  // Initialize localization with saved locale
  LocaleSettings.setLocale(savedLocale);

  // Needed for formatting dates in different locales
  await initializeDateFormatting(savedLocale.languageCode, null);

  // Configure image cache for large libraries
  PaintingBinding.instance.imageCache.maximumSizeBytes = 200 << 20; // 200MB

  // Initialize services in parallel where possible
  final futures = <Future<void>>[];

  // Initialize window_manager for desktop platforms
  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    futures.add(windowManager.ensureInitialized());
  }

  // Initialize TV detection and PiP service for Android
  if (Platform.isAndroid) {
    futures.add(TvDetectionService.getInstance());
    // Initialize PiP service to listen for PiP state changes
    PipService();
  }

  // Configure macOS window with custom titlebar (depends on window manager)
  futures.add(MacOSTitlebarService.setupCustomTitlebar());

  // Initialize storage service
  futures.add(StorageService.getInstance());

  // Initialize language codes for track selection
  futures.add(LanguageCodes.initialize());

  // Wait for all parallel services to complete
  await Future.wait(futures);

  // Initialize logger level based on debug setting
  final debugEnabled = settings.getEnableDebugLogging();
  setLoggerLevel(debugEnabled);

  // Log app version and git commit at startup
  final packageInfo = await PackageInfo.fromPlatform();
  final commitSuffix = gitCommit.isNotEmpty ? ' (${gitCommit.length >= 7 ? gitCommit.substring(0, 7) : gitCommit})' : '';
  appLogger.i('Finzy v${packageInfo.version}+${packageInfo.buildNumber}$commitSuffix');

  // Initialize download storage service with settings
  await DownloadStorageService.instance.initialize(settings);

  // Start global fullscreen state monitoring
  FullscreenStateManager().startMonitoring();

  // Initialize gamepad service for desktop platforms
  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    GamepadService.instance.start();
  }

  // DTD service is available for MCP tooling connection if needed

  // Register bundled shader licenses
  _registerShaderLicenses();

  runApp(const MainApp());
}

void _registerShaderLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      ['Anime4K'],
      'MIT License\n'
      '\n'
      'Copyright (c) 2019-2021 bloc97\n'
      'All rights reserved.\n'
      '\n'
      'Permission is hereby granted, free of charge, to any person obtaining a copy '
      'of this software and associated documentation files (the "Software"), to deal '
      'in the Software without restriction, including without limitation the rights '
      'to use, copy, modify, merge, publish, distribute, sublicense, and/or sell '
      'copies of the Software, and to permit persons to whom the Software is '
      'furnished to do so, subject to the following conditions:\n'
      '\n'
      'The above copyright notice and this permission notice shall be included in all '
      'copies or substantial portions of the Software.\n'
      '\n'
      'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR '
      'IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, '
      'FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE '
      'AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER '
      'LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, '
      'OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE '
      'SOFTWARE.',
    );
    yield LicenseEntryWithLineBreaks(
      ['NVIDIA Image Scaling (NVScaler)'],
      'The MIT License (MIT)\n'
      '\n'
      'Copyright (c) 2022 NVIDIA CORPORATION & AFFILIATES. All rights reserved.\n'
      '\n'
      'Permission is hereby granted, free of charge, to any person obtaining a copy of '
      'this software and associated documentation files (the "Software"), to deal in '
      'the Software without restriction, including without limitation the rights to '
      'use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of '
      'the Software, and to permit persons to whom the Software is furnished to do so, '
      'subject to the following conditions:\n'
      '\n'
      'The above copyright notice and this permission notice shall be included in all '
      'copies or substantial portions of the Software.\n'
      '\n'
      'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR '
      'IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS '
      'FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR '
      'COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER '
      'IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN '
      'CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.',
    );
  });
}

// Global RouteObserver for tracking navigation
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

/// Global navigator key for auth failure handling (navigate to login from anywhere).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  // Initialize multi-server infrastructure
  late final MultiServerManager _serverManager;
  late final DataAggregationService _aggregationService;
  late final AppDatabase _appDatabase;
  late final DownloadManagerService _downloadManager;
  late final OfflineWatchSyncService _offlineWatchSyncService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _serverManager = MultiServerManager();
    _aggregationService = DataAggregationService(_serverManager);
    _appDatabase = AppDatabase();

    // Initialize API cache with database
    ApiCache.initialize(_appDatabase);

    _downloadManager = DownloadManagerService(database: _appDatabase, storageService: DownloadStorageService.instance);
    _downloadManager.recoveryFuture = _downloadManager.recoverInterruptedDownloads();

    _offlineWatchSyncService = OfflineWatchSyncService(database: _appDatabase, serverManager: _serverManager);

    // Start in-app review session tracking
    InAppReviewService.instance.startSession();

  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // App came back to foreground - trigger sync check and start new session
        _offlineWatchSyncService.onAppResumed();
        InAppReviewService.instance.startSession();
        // Re-probe servers after a short delay — on Android, network/TCP may not be
        // ready immediately; running health checks too soon causes false "offline" state
        // and breaks the app (empty libraries, unresponsive UI).
        Future<void>.delayed(const Duration(seconds: 2), () {
          _serverManager.checkServerHealth();
          _serverManager.reconnectOfflineServers();
        });
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // App went to background or is closing - end session
        InAppReviewService.instance.endSession();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // Transitional states - don't trigger session events
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => MultiServerProvider(_serverManager, _aggregationService)),
        ChangeNotifierProvider(create: (context) => ServerStateProvider()),
        // Offline mode provider - depends on MultiServerProvider
        ChangeNotifierProxyProvider<MultiServerProvider, OfflineModeProvider>(
          create: (_) {
            final provider = OfflineModeProvider(_serverManager);
            provider.initialize(); // Initialize immediately so statusStream listener is ready
            return provider;
          },
          update: (_, multiServerProvider, previous) {
            final provider = previous ?? OfflineModeProvider(_serverManager);
            provider.initialize(); // Idempotent - safe to call again
            return provider;
          },
        ),
        // Download provider
        ChangeNotifierProvider(create: (context) => DownloadProvider(downloadManager: _downloadManager)),
        // Offline watch sync service
        ChangeNotifierProvider<OfflineWatchSyncService>(
          create: (context) {
            final offlineModeProvider = context.read<OfflineModeProvider>();
            final downloadProvider = context.read<DownloadProvider>();

            // Wire up callback to refresh download provider after watch state sync
            _offlineWatchSyncService.onWatchStatesRefreshed = () {
              downloadProvider.refreshMetadataFromCache();
            };

            _offlineWatchSyncService.startConnectivityMonitoring(offlineModeProvider);
            return _offlineWatchSyncService;
          },
        ),
        // Offline watch provider - depends on sync service and download provider
        ChangeNotifierProxyProvider2<OfflineWatchSyncService, DownloadProvider, OfflineWatchProvider>(
          create: (context) => OfflineWatchProvider(
            syncService: _offlineWatchSyncService,
            downloadProvider: context.read<DownloadProvider>(),
            apiCache: ApiCache.instance,
          ),
          update: (_, syncService, downloadProvider, previous) {
            return previous ??
                OfflineWatchProvider(
                  syncService: syncService,
                  downloadProvider: downloadProvider,
                  apiCache: ApiCache.instance,
                );
          },
        ),
        // Existing providers
        ChangeNotifierProvider(create: (context) => UserProfileProvider()),
        ChangeNotifierProvider(create: (context) => JellyfinProfileProvider()),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => SettingsProvider(), lazy: true),
        ChangeNotifierProvider(create: (context) => HiddenLibrariesProvider(), lazy: true),
        ChangeNotifierProvider(create: (context) => LibrariesProvider()),
        ChangeNotifierProvider(create: (context) => PlaybackStateProvider()),

        ChangeNotifierProvider(create: (context) => ShaderProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return TranslationProvider(
            child: InputModeTracker(
              child: TooltipVisibility(
                visible: false,
                child: MaterialApp(
                title: t.app.title,
                debugShowCheckedModeBanner: false,
                theme: themeProvider.lightTheme,
                darkTheme: themeProvider.darkTheme,
                themeMode: themeProvider.materialThemeMode,
                navigatorKey: navigatorKey,
                navigatorObservers: [routeObserver, BackKeySuppressorObserver()],
                home: const OrientationAwareSetup(),
                builder: (context, child) => ScaffoldMessenger(
                  key: rootScaffoldMessengerKey,
                  child: Scaffold(
                    backgroundColor: Colors.transparent,
                    body: child ?? const SizedBox.shrink(),
                  ),
                ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class OrientationAwareSetup extends StatefulWidget {
  const OrientationAwareSetup({super.key});

  @override
  State<OrientationAwareSetup> createState() => _OrientationAwareSetupState();
}

class _OrientationAwareSetupState extends State<OrientationAwareSetup> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setOrientationPreferences();
  }

  void _setOrientationPreferences() {
    OrientationHelper.restoreDefaultOrientations(context);
  }

  @override
  Widget build(BuildContext context) {
    return const SetupScreen();
  }
}

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  // Once the 'Go offline' button has been on screen, the auto-flow holds the
  // navigation off for at least this long so the button is actually tappable.
  static const _offlineButtonMinWindow = Duration(seconds: 4);

  Timer? _offlineButtonTimer;
  bool _showOfflineButton = false;
  bool _navigated = false;
  DateTime? _buttonShownAt;

  @override
  void initState() {
    super.initState();
    _offlineButtonTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && !_navigated) {
        setState(() {
          _showOfflineButton = true;
          _buttonShownAt = DateTime.now();
        });
      }
    });
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _offlineButtonTimer?.cancel();
    super.dispose();
  }

  void _navigateTo(Widget screen) {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _goOfflineNow() async {
    if (_navigated || !mounted) return;
    final downloadProvider = context.read<DownloadProvider>();
    await downloadProvider.ensureInitialized();
    if (!mounted) return;
    _navigateTo(const MainScreen(isOfflineMode: true));
  }

  /// Auto-flow path to offline mode. If the 'Go offline' button is already
  /// visible, hold the navigation until the user has had at least
  /// [_offlineButtonMinWindow] to interact — otherwise on a fast-fail (no
  /// network at all) the button flashes for ~300ms and disappears before
  /// the user can tap it.
  Future<void> _autoFlowGoOffline(DownloadProvider downloadProvider) async {
    if (_navigated || !mounted) return;

    if (_buttonShownAt != null) {
      final elapsed = DateTime.now().difference(_buttonShownAt!);
      if (elapsed < _offlineButtonMinWindow) {
        await Future<void>.delayed(_offlineButtonMinWindow - elapsed);
        if (_navigated || !mounted) return;
      }
    }

    await downloadProvider.ensureInitialized();
    if (!mounted) return;
    _navigateTo(const MainScreen(isOfflineMode: true));
  }

  Future<void> _loadSavedCredentials() async {
    final storage = await StorageService.getInstance();
    final registry = ServerRegistry(storage);

    // Load all configured servers
    final servers = await registry.getServers();

    appLogger.i('_loadSavedCredentials: ${servers.length} server(s) found');

    if (servers.isEmpty) {
      _navigateTo(const AuthScreen());
      return;
    }

    if (!mounted) return;

    final multiServerProvider = context.read<MultiServerProvider>();
    final librariesProvider = context.read<LibrariesProvider>();
    final syncService = context.read<OfflineWatchSyncService>();
    final downloadProvider = context.read<DownloadProvider>();
    if (!mounted) return;

    try {

      final deviceId = await storage.getOrCreateDeviceId();
      if (!mounted || _navigated) return;

      // Retry connection on cold start — TV/phone network may not be ready immediately
      var result = await ServerConnectionOrchestrator.connectAndInitialize(
        servers: servers,
        multiServerProvider: multiServerProvider,
        librariesProvider: librariesProvider,
        syncService: syncService,
        clientIdentifier: storage.getClientIdentifier(),
        deviceId: deviceId,
      );

      if (_navigated) return;

      if (!result.hasConnections) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (!mounted || _navigated) return;
        multiServerProvider.clearAllConnections();
        result = await ServerConnectionOrchestrator.connectAndInitialize(
          servers: servers,
          multiServerProvider: multiServerProvider,
          librariesProvider: librariesProvider,
          syncService: syncService,
          clientIdentifier: storage.getClientIdentifier(),
          deviceId: deviceId,
        );
      }

      if (!mounted || _navigated) return;

      if (result.hasConnections) {
        // Connect may have backfilled PrimaryImageTag from Jellyfin `/Users/{id}` — reload registry before UI.
        await context.read<JellyfinProfileProvider>().refresh();
        if (!mounted || _navigated) return;

        // Resume any downloads that were interrupted by app kill
        downloadProvider.ensureInitialized().then((_) {
          downloadProvider.resumeQueuedDownloads(result.firstClient!);
        });

        _navigateTo(MainScreen(client: result.firstClient!));
      } else {
        // Check if any server is reachable — if so, it's an auth issue, not network
        if (await _isAnyServerReachable(servers)) {
          appLogger.i('Server reachable but auth failed — redirecting to login');
          _navigateTo(const AuthScreen());
        } else {
          await _autoFlowGoOffline(downloadProvider);
        }
      }
    } catch (e, stackTrace) {
      appLogger.e('Error during multi-server connection', error: e, stackTrace: stackTrace);
      await _autoFlowGoOffline(downloadProvider);
    }
  }

  Future<bool> _isAnyServerReachable(List<RegisteredServer> servers) async {
    for (final server in servers) {
      if (await JellyfinAuthService.testConnection(server.jellyfinData.baseUrl,
          timeout: const Duration(seconds: 3))) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 16),
            Text(t.common.loading, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 32),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _showOfflineButton
                  ? FocusableWrapper(
                      autofocus: true,
                      onSelect: _goOfflineNow,
                      child: TextButton(
                        onPressed: _goOfflineNow,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        child: Text(t.common.goOffline),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
