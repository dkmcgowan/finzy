import '../models/registered_server.dart';
import '../utils/app_logger.dart';
import 'plex_auth_service.dart';
import 'storage_service.dart';

/// Centralized server configuration registry
/// Manages which servers are available (Plex and/or Jellyfin) and their configurations
class ServerRegistry {
  final StorageService _storage;

  ServerRegistry(this._storage);

  /// Get all registered servers (Plex and Jellyfin)
  Future<List<RegisteredServer>> getServers() async {
    try {
      final serversJson = _storage.getServersListJson();
      final list = RegisteredServer.listFromJsonString(serversJson);
      return list;
    } catch (e, stackTrace) {
      appLogger.e('Failed to load servers from storage', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Save all servers to storage
  Future<void> saveServers(List<RegisteredServer> servers) async {
    try {
      final serversJson = RegisteredServer.listToJsonString(servers);
      await _storage.saveServersListJson(serversJson);
      appLogger.d('Saved ${servers.length} servers to storage');
    } catch (e, stackTrace) {
      appLogger.e('Failed to save servers to storage', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Get a specific server by ID
  Future<RegisteredServer?> getServer(String serverId) async {
    final servers = await getServers();
    try {
      return servers.firstWhere((s) => s.serverId == serverId);
    } catch (e) {
      return null;
    }
  }

  /// Update server status (called when server connection status changes)
  Future<void> updateServerStatus(String serverId) async {
    // Status tracking is handled by MultiServerManager
  }

  /// Add or update a single Plex server
  Future<void> upsertServer(PlexServer server) async {
    final servers = await getServers();
    final index = servers.indexWhere((s) => s.isPlex && s.serverId == server.clientIdentifier);
    if (index >= 0) {
      servers[index] = RegisteredServer.plex(server);
      appLogger.d('Updated server: ${server.name}');
    } else {
      servers.add(RegisteredServer.plex(server));
      appLogger.d('Added new server: ${server.name}');
    }
    await saveServers(servers);
  }

  /// Add a Jellyfin server (e.g. after sign-in). Replaces existing if same serverId.
  Future<void> addOrReplaceJellyfinServer(JellyfinServerData data) async {
    final servers = await getServers();
    final index = servers.indexWhere((s) => s.isJellyfin && s.serverId == data.serverId);
    if (index >= 0) {
      servers[index] = RegisteredServer.jellyfin(data);
      appLogger.d('Updated Jellyfin server: ${data.serverName}');
    } else {
      servers.add(RegisteredServer.jellyfin(data));
      appLogger.d('Added Jellyfin server: ${data.serverName}');
    }
    await saveServers(servers);
  }

  /// Remove a server
  Future<void> removeServer(String serverId) async {
    final servers = await getServers();
    servers.removeWhere((s) => s.serverId == serverId);
    await saveServers(servers);
    appLogger.i('Removed server: $serverId');
  }

  /// Clear all servers
  Future<void> clearAllServers() async {
    await _storage.clearServersList();
    appLogger.i('Cleared all servers from registry');
  }

  /// Refresh Plex servers from Plex API (connection info). Jellyfin servers are left unchanged.
  Future<void> refreshServersFromApi() async {
    final existing = await getServers();
    final jellyfinServers = existing.where((s) => s.isJellyfin).toList();
    final hasPlex = existing.any((s) => s.isPlex);

    if (!hasPlex) {
      appLogger.d('No Plex servers to refresh');
      return;
    }

    final token = _storage.getPlexToken();
    if (token == null || token.isEmpty) {
      appLogger.d('No Plex token available, skipping Plex server refresh');
      return;
    }

    try {
      appLogger.d('Refreshing Plex servers from API...');
      final authService = await PlexAuthService.create();
      final freshPlex = await authService.fetchServers(token);

      final updated = <RegisteredServer>[
        ...jellyfinServers,
        ...freshPlex.map((s) => RegisteredServer.plex(s)),
      ];
      await saveServers(updated);
      appLogger.i('Refreshed ${freshPlex.length} Plex servers, ${jellyfinServers.length} Jellyfin unchanged');
    } catch (e, stackTrace) {
      appLogger.w('Failed to refresh servers from API, using cached data', error: e, stackTrace: stackTrace);
    }
  }
}
