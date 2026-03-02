import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

import '../models/jellyfin_config.dart';
import '../models/registered_server.dart';
import '../utils/app_logger.dart';
import '../utils/connection_constants.dart';
import 'jellyfin_client.dart';

/// Manages multiple Jellyfin server connections.
class MultiServerManager {
  /// Map of serverId to client
  final Map<String, JellyfinClient> _clients = {};

  /// Map of serverId to registered server info
  final Map<String, RegisteredServer> _servers = {};

  /// Map of serverId to online status
  final Map<String, bool> _serverStatus = {};

  /// Stream controller for server status changes
  final _statusController = StreamController<Map<String, bool>>.broadcast();

  /// Stream of server status changes
  Stream<Map<String, bool>> get statusStream => _statusController.stream;

  /// Connectivity subscription for network monitoring
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Periodic timer to retry reconnection when offline. connectivity_plus can miss
  /// the "back online" event on Android, so we poll when we have offline servers.
  Timer? _offlineReconnectTimer;

  /// Map of serverId to active reconnection futures
  final Map<String, Future<void>> _activeOptimizations = {};

  /// Cached client identifier for reconnection without async storage lookup
  String? _clientIdentifier;

  /// Get all registered server IDs
  List<String> get serverIds => _servers.keys.toList();

  /// Get all online server IDs
  List<String> get onlineServerIds => _serverStatus.entries.where((e) => e.value).map((e) => e.key).toList();

  /// Get all offline server IDs
  List<String> get offlineServerIds => _serverStatus.entries.where((e) => !e.value).map((e) => e.key).toList();

  /// Get client for specific server
  JellyfinClient? getClient(String serverId) => _clients[serverId];

  /// Get server info for specific server
  RegisteredServer? getServer(String serverId) => _servers[serverId];

  /// Get all online clients
  Map<String, JellyfinClient> get onlineClients {
    final result = <String, JellyfinClient>{};
    for (final serverId in onlineServerIds) {
      final client = _clients[serverId];
      if (client != null) {
        result[serverId] = client;
      }
    }
    return result;
  }

  /// Get all servers
  Map<String, RegisteredServer> get servers => Map.unmodifiable(_servers);

  /// Check if a server is online
  bool isServerOnline(String serverId) => _serverStatus[serverId] ?? false;

  /// Creates a JellyfinClient for the given Jellyfin server data
  JellyfinClient _createJellyfinClient(JellyfinServerData data) {
    final config = JellyfinConfig(
      baseUrl: data.baseUrl,
      token: data.token,
      userId: data.userId,
      serverId: data.serverId,
      serverName: data.serverName,
    );
    return JellyfinClient(config, serverId: data.serverId, serverName: data.serverName);
  }

  /// Connect to all available servers in parallel
  /// Returns the number of successfully connected servers
  Future<int> connectToAllServers(
    List<RegisteredServer> servers, {
    String? clientIdentifier,
    Duration timeout = ConnectionTimeouts.connectAll,
    Function(String serverId, JellyfinClient client)? onServerConnected,
    Function(String serverId, Object error)? onServerFailed,
  }) async {
    if (servers.isEmpty) {
      appLogger.w('No servers to connect to');
      return 0;
    }

    appLogger.i('Connecting to ${servers.length} servers...');

    final effectiveClientId = clientIdentifier ?? DateTime.now().millisecondsSinceEpoch.toString();
    _clientIdentifier = effectiveClientId;

    final connectionFutures = servers.map((registered) async {
      final serverId = registered.serverId;
      final serverName = registered.serverName;

      try {
        appLogger.d('Attempting connection to server: $serverName');

        final client = _createJellyfinClient(registered.jellyfinData);
        await client.loadUserPolicy();

        _clients[serverId] = client;
        _servers[serverId] = registered;
        _serverStatus[serverId] = true;

        onServerConnected?.call(serverId, client);
        appLogger.i('Successfully connected to $serverName');

        return serverId;
      } catch (e, stackTrace) {
        appLogger.e('Failed to connect to $serverName', error: e, stackTrace: stackTrace);

        _servers[serverId] = registered;
        _serverStatus[serverId] = false;

        onServerFailed?.call(serverId, e);
        return null;
      }
    });

    final results = await Future.wait(
      connectionFutures.map(
        (f) => f.timeout(
          timeout,
          onTimeout: () {
            appLogger.w('Server connection timed out');
            return null;
          },
        ),
      ),
    );

    final successCount = results.where((id) => id != null).length;
    _statusController.add(Map.from(_serverStatus));
    appLogger.i('Connected to $successCount/${servers.length} servers successfully');

    if (successCount > 0) {
      startNetworkMonitoring();
      _startOfflineReconnectTimer();
    }

    return successCount;
  }

  /// Add a single server connection
  Future<bool> addServer(RegisteredServer registered, {String? clientIdentifier}) async {
    final serverId = registered.serverId;
    final effectiveClientId = clientIdentifier ?? DateTime.now().millisecondsSinceEpoch.toString();
    _clientIdentifier ??= effectiveClientId;

    try {
      appLogger.d('Adding server: ${registered.serverName}');

      final client = _createJellyfinClient(registered.jellyfinData);
      await client.loadUserPolicy();

      _clients[serverId] = client;
      _servers[serverId] = registered;
      _serverStatus[serverId] = true;
      _statusController.add(Map.from(_serverStatus));

      appLogger.i('Successfully added server: ${registered.serverName}');
      return true;
    } catch (e, stackTrace) {
      appLogger.e('Failed to add server ${registered.serverName}', error: e, stackTrace: stackTrace);

      _servers[serverId] = registered;
      _serverStatus[serverId] = false;
      _statusController.add(Map.from(_serverStatus));

      return false;
    }
  }

  /// Remove a server connection
  void removeServer(String serverId) {
    _clients.remove(serverId);
    _servers.remove(serverId);
    _serverStatus.remove(serverId);
    _statusController.add(Map.from(_serverStatus));
    appLogger.i('Removed server: $serverId');
  }

  /// Update server status (used for health monitoring)
  void updateServerStatus(String serverId, bool isOnline) {
    if (_serverStatus[serverId] != isOnline) {
      _serverStatus[serverId] = isOnline;
      _statusController.add(Map.from(_serverStatus));
      appLogger.d('Server $serverId status changed to: $isOnline');
    }
  }

  /// Number of retries before marking a server offline. Transient failures (timeout,
  /// connection reset) are common when app resumes on Android.
  static const int _healthCheckRetries = 3;

  /// Delay between health check retries.
  static const Duration _healthCheckRetryDelay = Duration(milliseconds: 800);

  /// Test connection health for all servers.
  /// Retries transient failures before marking offline — a single timeout or
  /// connection reset on app resume must not permanently break the app.
  Future<void> checkServerHealth() async {
    appLogger.d('Checking health for ${_clients.length} servers');

    final healthChecks = _clients.entries.map((entry) async {
      final serverId = entry.key;
      final client = entry.value;

      Object? lastError;
      for (var attempt = 0; attempt < _healthCheckRetries; attempt++) {
        try {
          await client.getServerIdentity();
          updateServerStatus(serverId, true);
          return;
        } catch (e) {
          lastError = e;
          final is401 = _isAuthError(e);
          if (is401) {
            // 401 = invalid token. Mark offline (match Plezy) — user sees offline UI
            // with reconnect; no global redirect to login on every 401.
            appLogger.w('Server $serverId returned 401 (auth), marking offline');
            updateServerStatus(serverId, false);
            return;
          }
          if (attempt < _healthCheckRetries - 1) {
            appLogger.d('Server $serverId health check attempt ${attempt + 1} failed, retrying: $e');
            await Future<void>.delayed(_healthCheckRetryDelay);
          }
        }
      }
      appLogger.w('Server $serverId health check failed after $_healthCheckRetries attempts: $lastError');
      updateServerStatus(serverId, false);
    });

    await Future.wait(healthChecks);
  }

  static bool _isAuthError(Object e) {
    if (e is DioException && e.response?.statusCode == 401) return true;
    return false;
  }

  /// Start monitoring network connectivity for all servers
  void startNetworkMonitoring() {
    if (_connectivitySubscription != null) {
      appLogger.d('Network monitoring already active');
      return;
    }

    appLogger.i('Starting network monitoring for all servers');
    final connectivity = Connectivity();
    _connectivitySubscription = connectivity.onConnectivityChanged.listen(
      (results) {
        final status = results.isNotEmpty ? results.first : ConnectivityResult.none;

        if (status == ConnectivityResult.none) {
          appLogger.w('Connectivity lost, pausing until network returns');
          return;
        }

        appLogger.d(
          'Connectivity change detected, re-probing offline servers',
          error: {
            'status': status.name,
            'serverCount': _servers.length,
          },
        );

        // Brief delay so the new network is ready (Android can report connectivity
        // before TCP is actually usable).
        Future<void>.delayed(const Duration(seconds: 1), () {
          _reoptimizeAllServers(reason: 'connectivity:${status.name}');
          checkServerHealth();
        });
      },
      onError: (error, stackTrace) {
        appLogger.w('Connectivity listener error', error: error, stackTrace: stackTrace);
      },
    );
  }

  /// Stop monitoring network connectivity
  void stopNetworkMonitoring() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _offlineReconnectTimer?.cancel();
    _offlineReconnectTimer = null;
    appLogger.i('Stopped network monitoring');
  }

  /// Interval for periodic reconnect attempts when we have offline servers.
  /// connectivity_plus can miss "back online" on Android, so we poll.
  static const Duration _offlineReconnectInterval = Duration(seconds: 45);

  void _startOfflineReconnectTimer() {
    _offlineReconnectTimer?.cancel();
    _offlineReconnectTimer = Timer.periodic(_offlineReconnectInterval, (_) {
      final offline = offlineServerIds;
      if (offline.isEmpty) return;
      appLogger.d('Periodic reconnect: ${offline.length} offline server(s)');
      checkServerHealth();
      reconnectOfflineServers();
    });
  }

  /// Reconnect offline servers; no-op for already online Jellyfin servers
  void _reoptimizeAllServers({required String reason}) {
    for (final entry in _servers.entries) {
      final serverId = entry.key;
      final registered = entry.value;

      if (_activeOptimizations.containsKey(serverId)) {
        appLogger.d('Reconnection already running for ${registered.serverName}, skipping', error: {'reason': reason});
        continue;
      }

      if (!isServerOnline(serverId)) {
        _activeOptimizations[serverId] = _reconnectServer(serverId, registered).whenComplete(() {
          _activeOptimizations.remove(serverId);
        });
      }
    }
  }

  /// Attempt full reconnection for a single offline server
  Future<void> _reconnectServer(String serverId, RegisteredServer registered) async {
    try {
      appLogger.d('Attempting reconnection for ${registered.serverName}');

      final client = _createJellyfinClient(registered.jellyfinData);
      await client.loadUserPolicy();

      _clients[serverId] = client;
      updateServerStatus(serverId, true);
      appLogger.i('Successfully reconnected to ${registered.serverName}');
    } catch (e) {
      appLogger.d('Reconnection failed for ${registered.serverName}: $e');
    }
  }

  /// Attempt reconnection for all offline servers
  Future<void> reconnectOfflineServers() async {
    final offline = offlineServerIds;
    if (offline.isEmpty) return;

    appLogger.d('Attempting reconnection for ${offline.length} offline servers');

    final futures = offline.map((serverId) {
      final server = _servers[serverId];
      if (server == null) return Future<void>.value();

      if (_activeOptimizations.containsKey(serverId)) return Future<void>.value();

      final future = _reconnectServer(serverId, server)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              appLogger.d('Reconnection timed out for $serverId');
            },
          )
          .whenComplete(() => _activeOptimizations.remove(serverId));

      _activeOptimizations[serverId] = future;
      return future;
    });

    await Future.wait(futures);
  }

  /// Disconnect all servers
  void disconnectAll() {
    appLogger.i('Disconnecting all servers');
    _offlineReconnectTimer?.cancel();
    _offlineReconnectTimer = null;
    stopNetworkMonitoring();
    _clients.clear();
    _servers.clear();
    _serverStatus.clear();
    _activeOptimizations.clear();
    _statusController.add({});
  }

  /// Dispose resources
  void dispose() {
    disconnectAll();
    _statusController.close();
  }
}
