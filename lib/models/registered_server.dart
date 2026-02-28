import 'dart:convert';

/// One stored Jellyfin user (token + display info for switch profile).
class JellyfinStoredUser {
  final String userId;
  final String accessToken;
  final String userName;
  final String? primaryImageTag;

  JellyfinStoredUser({
    required this.userId,
    required this.accessToken,
    required this.userName,
    this.primaryImageTag,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'accessToken': accessToken,
        'userName': userName,
        if (primaryImageTag != null) 'primaryImageTag': primaryImageTag,
      };

  factory JellyfinStoredUser.fromJson(Map<String, dynamic> json) {
    return JellyfinStoredUser(
      userId: json['userId'] as String? ?? '',
      accessToken: json['accessToken'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      primaryImageTag: json['primaryImageTag'] as String?,
    );
  }
}

/// Data required to connect to a Jellyfin server.
/// Supports multiple users on one server; [currentUserId] selects the active user.
class JellyfinServerData {
  final String baseUrl;
  final String serverId;
  final String serverName;
  /// Stored users (at least one). Current user is selected by [currentUserId].
  final List<JellyfinStoredUser> users;
  final String currentUserId;

  JellyfinServerData({
    required this.baseUrl,
    required this.serverId,
    required this.serverName,
    required this.users,
    required this.currentUserId,
  });

  /// Token for the currently selected user.
  String get token {
    final u = currentUser;
    return u?.accessToken ?? (users.isNotEmpty ? users.first.accessToken : '');
  }

  /// User id for the currently selected user.
  String get userId => currentUserId;

  /// Current user's display name and optional image tag for avatar.
  JellyfinStoredUser? get currentUser {
    for (final u in users) {
      if (u.userId == currentUserId) return u;
    }
    return users.isNotEmpty ? users.first : null;
  }

  Map<String, dynamic> toJson() => {
        'baseUrl': baseUrl,
        'serverId': serverId,
        'serverName': serverName,
        'users': users.map((u) => u.toJson()).toList(),
        'currentUserId': currentUserId,
      };

  factory JellyfinServerData.fromJson(Map<String, dynamic> json) {
    final usersJson = json['users'] as List<dynamic>?;
    List<JellyfinStoredUser> usersList;
    String currentUserId;
    if (usersJson != null && usersJson.isNotEmpty) {
      usersList = usersJson.map((e) => JellyfinStoredUser.fromJson(e as Map<String, dynamic>)).toList();
      currentUserId = json['currentUserId'] as String? ?? usersList.first.userId;
    } else {
      // Legacy: single token/userId
      final token = json['token'] as String? ?? '';
      final userId = json['userId'] as String? ?? '';
      usersList = token.isNotEmpty && userId.isNotEmpty
          ? [JellyfinStoredUser(userId: userId, accessToken: token, userName: '')]
          : [];
      currentUserId = userId;
    }
    return JellyfinServerData(
      baseUrl: json['baseUrl'] as String,
      serverId: json['serverId'] as String,
      serverName: json['serverName'] as String? ?? 'Jellyfin',
      users: usersList,
      currentUserId: currentUserId,
    );
  }
}

/// A server registered in the app. Finzy supports Jellyfin only.
/// Used for storage and for MultiServerManager to create the client.
class RegisteredServer {
  final String serverId;
  final String serverName;
  final JellyfinServerData jellyfinData;

  RegisteredServer._({
    required this.serverId,
    required this.serverName,
    required this.jellyfinData,
  });

  factory RegisteredServer.jellyfin(JellyfinServerData data) {
    return RegisteredServer._(
      serverId: data.serverId,
      serverName: data.serverName,
      jellyfinData: data,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'backend': 'jellyfin',
      'serverId': serverId,
      'serverName': serverName,
      'jellyfin': jellyfinData.toJson(),
    };
  }

  factory RegisteredServer.fromJson(Map<String, dynamic> json) {
    final j = json['jellyfin'] as Map<String, dynamic>? ?? json;
    final data = JellyfinServerData.fromJson(j);
    return RegisteredServer.jellyfin(data);
  }

  /// Decode a stored servers list JSON string into [RegisteredServer] list.
  static List<RegisteredServer> listFromJsonString(String? serversJson) {
    if (serversJson == null || serversJson.isEmpty) return [];
    try {
      final list = jsonDecode(serversJson) as List<dynamic>?;
      if (list == null) return [];
      final result = <RegisteredServer>[];
      for (final e in list) {
        try {
          result.add(RegisteredServer.fromJson(e as Map<String, dynamic>));
        } catch (_) {
          // Skip malformed entries
        }
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  /// Encode a list of [RegisteredServer] to the stored JSON string.
  static String listToJsonString(List<RegisteredServer> servers) {
    return jsonEncode(servers.map((s) => s.toJson()).toList());
  }
}
