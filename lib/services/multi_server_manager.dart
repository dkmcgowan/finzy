import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'media_server_client.dart';
import 'plex_client.dart';
import '../models/jellyfin_config.dart';
import '../models/plex_config.dart';
import '../models/registered_server.dart';
import '../utils/app_logger.dart';
import '../utils/connection_constants.dart';
import 'jellyfin_client.dart';
import 'plex_auth_service.dart';
import 'storage_service.dart';

/// Manages multiple media server connections (Plex and/or Jellyfin)
class MultiServerManager {
  /// Map of serverId to client (Plex or Jellyfin)
  final Map<String, MediaServerClient> _clients = {};

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

  /// Map of serverId to active optimization futures
  final Map<String, Future<void>> _activeOptimizations = {};

  /// Cached client identifier for reconnection without async storage lookup
  String? _clientIdentifier;

  /// Debounce timers for endpoint-exhaustion-triggered reconnection (per server)
  final Map<String, Timer> _reconnectDebounce = {};

  /// Get all registered server IDs
  List<String> get serverIds => _servers.keys.toList();

  /// Get all online server IDs
  List<String> get onlineServerIds => _serverStatus.entries.where((e) => e.value).map((e) => e.key).toList();

  /// Get all offline server IDs
  List<String> get offlineServerIds => _serverStatus.entries.where((e) => !e.value).map((e) => e.key).toList();

  /// Get client for specific server
  MediaServerClient? getClient(String serverId) => _clients[serverId];

  /// Get server info for specific server
  RegisteredServer? getServer(String serverId) => _servers[serverId];

  /// Get all online clients
  Map<String, MediaServerClient> get onlineClients {
    final result = <String, MediaServerClient>{};
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

  /// Creates and initializes a PlexClient for a given server
  ///
  /// Handles finding working connection, loading cached endpoint,
  /// creating config, and building client with failover support.
  Future<PlexClient> _createClientForServer({required PlexServer server, required String clientIdentifier}) async {
    final serverId = server.clientIdentifier;

    // Get storage and load cached endpoint for this server
    final storage = await StorageService.getInstance();
    final cachedEndpoint = storage.getServerEndpoint(serverId);

    // Find best working connection, passing cached endpoint for fast-path
    final streamIterator = StreamIterator(server.findBestWorkingConnection(preferredUri: cachedEndpoint));

    if (!await streamIterator.moveNext()) {
      throw Exception('No working connection found');
    }

    final workingConnection = streamIterator.current;
    final baseUrl = workingConnection.uri;

    // Create PlexClient with failover support
    final prioritizedEndpoints = server.prioritizedEndpointUrls(preferredFirst: cachedEndpoint ?? baseUrl);
    final config = await PlexConfig.create(
      baseUrl: baseUrl,
      token: server.accessToken,
      clientIdentifier: clientIdentifier,
    );

    final client = PlexClient(
      config,
      serverId: serverId,
      serverName: server.name,
      prioritizedEndpoints: prioritizedEndpoints,
      onEndpointChanged: (newUrl) async {
        await storage.saveServerEndpoint(serverId, newUrl);
        appLogger.i('Updated endpoint for ${server.name} after failover: $newUrl');
      },
      onAllEndpointsExhausted: () => _onServerEndpointsExhausted(serverId),
    );

    // Save the initial endpoint
    await storage.saveServerEndpoint(serverId, baseUrl);

    // Drain remaining stream values in background to apply better connections
    _drainOptimizationStream(streamIterator, client: client, server: server, storage: storage);

    return client;
  }

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

  /// Continues draining the connection optimization stream in the background,
  /// switching the client to any better endpoint found.
  void _drainOptimizationStream(
    StreamIterator<PlexConnection> streamIterator, {
    required PlexClient client,
    required PlexServer server,
    required StorageService storage,
  }) {
    final serverId = server.clientIdentifier;

    () async {
      try {
        while (await streamIterator.moveNext()) {
          final connection = streamIterator.current;
          final newUrl = connection.uri;

          if (newUrl == client.config.baseUrl) {
            appLogger.d('Background optimization confirmed current endpoint for ${server.name}');
            continue;
          }

          appLogger.i(
            'Background optimization found better endpoint for ${server.name}',
            error: {'from': client.config.baseUrl, 'to': newUrl, 'type': connection.displayType},
          );

          await storage.saveServerEndpoint(serverId, newUrl);
          final newEndpoints = server.prioritizedEndpointUrls(preferredFirst: newUrl);
          await client.updateEndpointPreferences(newEndpoints, switchToFirst: true);
        }
      } catch (e, stackTrace) {
        appLogger.w('Background connection optimization failed for ${server.name}', error: e, stackTrace: stackTrace);
      } finally {
        await streamIterator.cancel();
      }
    }();
  }

  /// Connect to all available servers in parallel (Plex and/or Jellyfin)
  /// Returns the number of successfully connected servers
  Future<int> connectToAllServers(
    List<RegisteredServer> servers, {
    String? clientIdentifier,
    Duration timeout = ConnectionTimeouts.connectAll,
    Function(String serverId, MediaServerClient client)? onServerConnected,
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

        final MediaServerClient client;
        if (registered.isPlex) {
          client = await _createClientForServer(server: registered.plexServer!, clientIdentifier: effectiveClientId);
        } else {
          client = _createJellyfinClient(registered.jellyfinData!);
        }

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

    // Start network monitoring if we have any connected servers
    if (successCount > 0) {
      startNetworkMonitoring();
    }

    return successCount;
  }

  /// Add a single server connection (Plex or Jellyfin)
  Future<bool> addServer(RegisteredServer registered, {String? clientIdentifier}) async {
    final serverId = registered.serverId;
    final effectiveClientId = clientIdentifier ?? DateTime.now().millisecondsSinceEpoch.toString();
    _clientIdentifier ??= effectiveClientId;

    try {
      appLogger.d('Adding server: ${registered.serverName}');

      final MediaServerClient client;
      if (registered.isPlex) {
        client = await _createClientForServer(server: registered.plexServer!, clientIdentifier: effectiveClientId);
      } else {
        client = _createJellyfinClient(registered.jellyfinData!);
      }

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

  /// Test connection health for all servers
  Future<void> checkServerHealth() async {
    appLogger.d('Checking health for ${_clients.length} servers');

    final healthChecks = _clients.entries.map((entry) async {
      final serverId = entry.key;
      final client = entry.value;

      try {
        // Simple ping by fetching server identity
        await client.getServerIdentity();
        updateServerStatus(serverId, true);
      } catch (e) {
        appLogger.w('Server $serverId health check failed: $e');
        updateServerStatus(serverId, false);
      }
    });

    await Future.wait(healthChecks);
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
          appLogger.w('Connectivity lost, pausing optimization until network returns');
          return;
        }

        appLogger.d(
          'Connectivity change detected, re-optimizing all servers',
          error: {
            'status': status.name,
            'interfaces': results.map((r) => r.name).toList(),
            'serverCount': _servers.length,
          },
        );

        // Re-optimize all servers and re-probe offline ones
        _reoptimizeAllServers(reason: 'connectivity:${status.name}');
        checkServerHealth();
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
    appLogger.i('Stopped network monitoring');
  }

  /// Re-optimize all connected servers and attempt reconnection for offline ones
  void _reoptimizeAllServers({required String reason}) {
    for (final entry in _servers.entries) {
      final serverId = entry.key;
      final registered = entry.value;

      if (_activeOptimizations.containsKey(serverId)) {
        appLogger.d('Optimization already running for ${registered.serverName}, skipping', error: {'reason': reason});
        continue;
      }

      if (!isServerOnline(serverId)) {
        _activeOptimizations[serverId] = _reconnectServer(serverId, registered).whenComplete(() {
          _activeOptimizations.remove(serverId);
        });
      } else if (registered.isPlex) {
        _activeOptimizations[serverId] = _reoptimizeServer(
          serverId: serverId,
          server: registered.plexServer!,
          reason: reason,
        ).whenComplete(() {
          _activeOptimizations.remove(serverId);
        });
      }
    }
  }

  /// Re-optimize connection for a specific server
  Future<void> _reoptimizeServer({required String serverId, required PlexServer server, required String reason}) async {
    final storage = await StorageService.getInstance();
    final client = _clients[serverId];
    final cachedEndpoint = storage.getServerEndpoint(serverId);

    try {
      appLogger.d('Starting connection optimization for ${server.name}', error: {'reason': reason});

      await for (final connection in server.findBestWorkingConnection(preferredUri: cachedEndpoint)) {
        final newUrl = connection.uri;

        // Check if this is actually a better connection than current (Plex-only)
        final plexClient = client as PlexClient?;
        if (plexClient != null && plexClient.config.baseUrl == newUrl) {
          appLogger.d('Already using optimal endpoint for ${server.name}: $newUrl');
          continue;
        }

        // Save the new endpoint
        await storage.saveServerEndpoint(serverId, newUrl);

        // Actively switch the running client to the better endpoint
        if (plexClient != null) {
          final newEndpoints = server.prioritizedEndpointUrls(preferredFirst: newUrl);
          await plexClient.updateEndpointPreferences(newEndpoints, switchToFirst: true);
          appLogger.i('Switched ${server.name} to better endpoint: $newUrl', error: {'type': connection.displayType});
        } else {
          appLogger.i('Updated optimal endpoint for ${server.name}: $newUrl', error: {'type': connection.displayType});
        }
      }
    } catch (e, stackTrace) {
      appLogger.w('Connection optimization failed for ${server.name}', error: e, stackTrace: stackTrace);
    }
  }

  /// Attempt full reconnection for a single offline server
  Future<void> _reconnectServer(String serverId, RegisteredServer registered) async {
    try {
      appLogger.d('Attempting reconnection for ${registered.serverName}');

      final MediaServerClient client;
      if (registered.isPlex) {
        final clientId = _clientIdentifier;
        if (clientId == null) {
          appLogger.w('Cannot reconnect ${registered.serverName}: no client identifier cached');
          return;
        }
        client = await _createClientForServer(server: registered.plexServer!, clientIdentifier: clientId);
      } else {
        client = _createJellyfinClient(registered.jellyfinData!);
      }

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

      // Skip if already running
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

  /// Called when all failover endpoints are exhausted for a Plex server.
  void _onServerEndpointsExhausted(String serverId) {
    _reconnectDebounce[serverId]?.cancel();

    _reconnectDebounce[serverId] = Timer(const Duration(seconds: 5), () {
      _reconnectDebounce.remove(serverId);

      final registered = _servers[serverId];
      if (registered == null || !registered.isPlex) return;

      appLogger.i('All endpoints exhausted for $serverId, triggering reconnection');
      updateServerStatus(serverId, false);

      if (_activeOptimizations.containsKey(serverId)) return;

      _activeOptimizations[serverId] = _reconnectServer(serverId, registered).whenComplete(() {
        _activeOptimizations.remove(serverId);
      });
    });
  }

  /// Disconnect all servers
  void disconnectAll() {
    appLogger.i('Disconnecting all servers');
    stopNetworkMonitoring();
    for (final timer in _reconnectDebounce.values) {
      timer.cancel();
    }
    _reconnectDebounce.clear();
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
