import 'dart:convert';

import '../services/plex_auth_service.dart';

/// Backend type for a registered media server.
enum BackendType {
  plex,
  jellyfin,
}

/// Data required to connect to a Jellyfin server.
class JellyfinServerData {
  final String baseUrl;
  final String token;
  final String userId;
  final String serverId;
  final String serverName;

  JellyfinServerData({
    required this.baseUrl,
    required this.token,
    required this.userId,
    required this.serverId,
    required this.serverName,
  });

  Map<String, dynamic> toJson() => {
        'baseUrl': baseUrl,
        'token': token,
        'userId': userId,
        'serverId': serverId,
        'serverName': serverName,
      };

  factory JellyfinServerData.fromJson(Map<String, dynamic> json) {
    return JellyfinServerData(
      baseUrl: json['baseUrl'] as String,
      token: json['token'] as String,
      userId: json['userId'] as String,
      serverId: json['serverId'] as String,
      serverName: json['serverName'] as String? ?? 'Jellyfin',
    );
  }
}

/// A server registered in the app (Plex or Jellyfin).
/// Used for storage and for MultiServerManager to create the right client.
class RegisteredServer {
  final BackendType backend;
  final String serverId;
  final String serverName;
  final PlexServer? plexServer;
  final JellyfinServerData? jellyfinData;

  RegisteredServer._({
    required this.backend,
    required this.serverId,
    required this.serverName,
    this.plexServer,
    this.jellyfinData,
  });

  factory RegisteredServer.plex(PlexServer server) {
    return RegisteredServer._(
      backend: BackendType.plex,
      serverId: server.clientIdentifier,
      serverName: server.name,
      plexServer: server,
      jellyfinData: null,
    );
  }

  factory RegisteredServer.jellyfin(JellyfinServerData data) {
    return RegisteredServer._(
      backend: BackendType.jellyfin,
      serverId: data.serverId,
      serverName: data.serverName,
      plexServer: null,
      jellyfinData: data,
    );
  }

  bool get isPlex => backend == BackendType.plex;
  bool get isJellyfin => backend == BackendType.jellyfin;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'backend': backend.name,
      'serverId': serverId,
      'serverName': serverName,
    };
    if (plexServer != null) {
      map['plex'] = plexServer!.toJson();
    }
    if (jellyfinData != null) {
      map['jellyfin'] = jellyfinData!.toJson();
    }
    return map;
  }

  factory RegisteredServer.fromJson(Map<String, dynamic> json) {
    final backendStr = json['backend'] as String? ?? 'plex';
    final backend = backendStr == 'jellyfin' ? BackendType.jellyfin : BackendType.plex;

    if (backend == BackendType.jellyfin) {
      final j = json['jellyfin'] as Map<String, dynamic>?;
      if (j == null) throw FormatException('RegisteredServer jellyfin missing jellyfin data');
      final data = JellyfinServerData.fromJson(j);
      return RegisteredServer.jellyfin(data);
    }

    final p = json['plex'] as Map<String, dynamic>? ?? json;
    final server = PlexServer.fromJson(p);
    return RegisteredServer.plex(server);
  }

  /// Decode a stored servers list JSON string into [RegisteredServer] list.
  static List<RegisteredServer> listFromJsonString(String? serversJson) {
    if (serversJson == null || serversJson.isEmpty) return [];
    try {
      final list = jsonDecode(serversJson) as List<dynamic>?;
      if (list == null) return [];
      return list.map((e) => RegisteredServer.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Encode a list of [RegisteredServer] to the stored JSON string.
  static String listToJsonString(List<RegisteredServer> servers) {
    return jsonEncode(servers.map((s) => s.toJson()).toList());
  }
}
