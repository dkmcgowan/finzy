import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/multi_server_manager.dart';
import '../utils/app_logger.dart';

/// Tracks offline mode status based on network connectivity and server reachability.
class OfflineModeProvider extends ChangeNotifier {
  final MultiServerManager _serverManager;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<Map<String, bool>>? _serverStatusSubscription;

  bool _hasNetworkConnection = true;
  late bool _hasServerConnection;
  bool _isInitialized = false;
  bool _isForcedOffline = false;

  /// Light polling when forced offline (~90s) to detect network for "Connection available".
  static const Duration _forcedOfflinePollInterval = Duration(seconds: 90);
  Timer? _forcedOfflinePollTimer;
  bool _connectionAvailableWhenForced = false;

  OfflineModeProvider(this._serverManager) : _hasServerConnection = _serverManager.onlineServerIds.isNotEmpty;

  /// Whether the user has forced offline mode (no auto reconnect).
  bool get isForcedOffline => _isForcedOffline;

  /// When forced offline and network is detected (via light polling), show "Connection available".
  bool get connectionAvailableWhenForced => _isForcedOffline && _connectionAvailableWhenForced;

  /// Whether the app is currently in offline mode
  /// Offline = no network OR no servers reachable OR forced offline
  bool get isOffline => _isForcedOffline || !_hasNetworkConnection || !_hasServerConnection;

  /// Whether there is network connectivity (WiFi, mobile data, etc.)
  bool get hasNetworkConnection => _hasNetworkConnection;

  /// Whether at least one server is reachable
  bool get hasServerConnection => _hasServerConnection;

  /// Updates network and server connection flags
  Future<void> _updateConnectionFlags() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      _hasNetworkConnection = !connectivityResult.contains(ConnectivityResult.none);
    } on PlatformException catch (e) {
      // connectivity_plus can throw on Windows/Linux (e.g. no NetworkManager)
      appLogger.d('Connectivity check failed, assuming network available: $e');
      _hasNetworkConnection = true;
    } catch (e) {
      appLogger.d('Connectivity check failed, assuming network available: $e');
      _hasNetworkConnection = true;
    }
    _hasServerConnection = _serverManager.onlineServerIds.isNotEmpty;
  }

  /// Initialize the provider and start monitoring
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // Check initial connectivity
    await _updateConnectionFlags();

    // Monitor connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (results) {
        try {
          final wasOffline = isOffline;
          _hasNetworkConnection = !results.contains(ConnectivityResult.none);
          if (wasOffline != isOffline) {
            notifyListeners();
          }
        } catch (e, stack) {
          appLogger.w('Connectivity listener error, assuming network available', error: e, stackTrace: stack);
          _hasNetworkConnection = true;
          notifyListeners();
        }
      },
      onError: (error, stack) {
        // e.g. DBusServiceUnknownException on Linux without NetworkManager
        appLogger.w('Connectivity stream error, assuming network available', error: error, stackTrace: stack);
        _hasNetworkConnection = true;
        notifyListeners();
      },
    );

    // Monitor server status from MultiServerManager
    _serverStatusSubscription = _serverManager.statusStream.listen((statusMap) {
      final wasOffline = isOffline;
      _hasServerConnection = statusMap.values.any((isOnline) => isOnline);

      if (wasOffline != isOffline) {
        notifyListeners();
      }
    });

    notifyListeners();
  }

  /// Force a refresh of connectivity status
  Future<void> refresh() async {
    await _updateConnectionFlags();
    notifyListeners();
  }

  /// Set forced offline mode. When true, no auto reconnect; user taps "Back Online".
  void setForcedOffline(bool forced) {
    if (_isForcedOffline == forced) return;
    _isForcedOffline = forced;
    _serverManager.setForcedOffline(forced);

    if (forced) {
      _updateConnectionFlags().then((_) {
        _connectionAvailableWhenForced = _hasNetworkConnection;
        notifyListeners();
      });
      _startForcedOfflinePolling();
    } else {
      _forcedOfflinePollTimer?.cancel();
      _forcedOfflinePollTimer = null;
      _connectionAvailableWhenForced = false;
    }
    notifyListeners();
  }

  void _startForcedOfflinePolling() {
    _forcedOfflinePollTimer?.cancel();
    _forcedOfflinePollTimer = Timer.periodic(_forcedOfflinePollInterval, (_) async {
      if (!_isForcedOffline) return;
      try {
        final result = await Connectivity().checkConnectivity();
        final hasNetwork = !result.contains(ConnectivityResult.none);
        if (_connectionAvailableWhenForced != hasNetwork) {
          _connectionAvailableWhenForced = hasNetwork;
          notifyListeners();
        }
      } catch (e) {
        appLogger.d('Forced-offline connectivity poll failed: $e');
        // Assume network available on error
        if (!_connectionAvailableWhenForced) {
          _connectionAvailableWhenForced = true;
          notifyListeners();
        }
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _serverStatusSubscription?.cancel();
    _forcedOfflinePollTimer?.cancel();
    super.dispose();
  }
}
