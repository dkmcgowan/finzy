import '../models/registered_server.dart';
import '../utils/app_logger.dart';
import 'storage_service.dart';

/// Centralized server configuration registry.
/// Manages which Jellyfin servers are available and their configurations.
class ServerRegistry {
  final StorageService _storage;

  ServerRegistry(this._storage);

  /// Get all registered servers
  Future<List<RegisteredServer>> getServers() async {
    try {
      final serversJson = _storage.getServersListJson();
      return RegisteredServer.listFromJsonString(serversJson);
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
      appLogger.d('Saved ${servers.length} servers');
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

  /// Add a Jellyfin server (e.g. after sign-in). Replaces existing if same serverId.
  /// For one-server multi-user: if a server already exists, adds or updates this user and sets as current.
  Future<void> addOrReplaceJellyfinServer(JellyfinServerData data) async {
    final servers = await getServers();
    final index = servers.indexWhere((s) => s.serverId == data.serverId);
    if (index >= 0) {
      servers[index] = RegisteredServer.jellyfin(data);
      appLogger.d('Updated Jellyfin server: ${data.serverName}');
    } else {
      servers.add(RegisteredServer.jellyfin(data));
      appLogger.d('Added Jellyfin server: ${data.serverName}');
    }
    await saveServers(servers);
  }

  /// Add or update a user on the existing server and set as current user.
  /// If no server exists, returns false (caller should use addOrReplaceJellyfinServer with full data).
  Future<bool> addOrUpdateJellyfinUserAndSetCurrent(JellyfinStoredUser user) async {
    final servers = await getServers();
    if (servers.isEmpty) return false;
    final index = 0;
    final reg = servers[index];
    final data = reg.jellyfinData;
    final existing = data.users.where((u) => u.userId == user.userId).toList();
    final newUsers = existing.isEmpty
        ? [...data.users, user]
        : data.users.map((u) => u.userId == user.userId ? user : u).toList();
    final newData = JellyfinServerData(
      baseUrl: data.baseUrl,
      serverId: data.serverId,
      serverName: data.serverName,
      users: newUsers,
      currentUserId: user.userId,
    );
    servers[index] = RegisteredServer.jellyfin(newData);
    await saveServers(servers);
    appLogger.d('Added/updated Jellyfin user: ${user.userName}');
    return true;
  }

  /// Sets [primaryImageTag] on the stored user [userId] when missing or different (from Jellyfin `/Users/{id}`).
  /// Returns `true` if disk was updated.
  Future<bool> mergePrimaryImageTagForUser({required String userId, required String primaryImageTag}) async {
    if (primaryImageTag.isEmpty) return false;
    final servers = await getServers();
    if (servers.isEmpty) return false;
    const index = 0;
    final data = servers[index].jellyfinData;
    var changed = false;
    final newUsers = data.users.map((u) {
      if (u.userId != userId) return u;
      if (u.primaryImageTag == primaryImageTag) return u;
      changed = true;
      return JellyfinStoredUser(
        userId: u.userId,
        accessToken: u.accessToken,
        userName: u.userName,
        primaryImageTag: primaryImageTag,
      );
    }).toList();
    if (!changed) return false;
    servers[index] = RegisteredServer.jellyfin(
      JellyfinServerData(
        baseUrl: data.baseUrl,
        serverId: data.serverId,
        serverName: data.serverName,
        users: newUsers,
        currentUserId: data.currentUserId,
      ),
    );
    await saveServers(servers);
    return true;
  }

  /// Set the current user (for switch profile). [userId] must be in the server's users list.
  Future<bool> setCurrentJellyfinUser(String userId) async {
    final servers = await getServers();
    if (servers.isEmpty) return false;
    final index = 0;
    final data = servers[index].jellyfinData;
    if (!data.users.any((u) => u.userId == userId)) return false;
    final newData = JellyfinServerData(
      baseUrl: data.baseUrl,
      serverId: data.serverId,
      serverName: data.serverName,
      users: data.users,
      currentUserId: userId,
    );
    servers[index] = RegisteredServer.jellyfin(newData);
    await saveServers(servers);
    return true;
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
}
