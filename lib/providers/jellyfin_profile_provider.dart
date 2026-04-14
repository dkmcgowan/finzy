import 'package:flutter/material.dart';
import '../models/registered_server.dart';
import '../services/jellyfin_auth_service.dart';
import '../services/server_registry.dart';
import '../services/storage_service.dart';
/// Minimal model for Jellyfin user display (avatar + switch profile).
class JellyfinProfileUser {
  final String userId;
  final String userName;
  final String? primaryImageTag;

  JellyfinProfileUser({
    required this.userId,
    required this.userName,
    this.primaryImageTag,
  });
}

/// Provides current Jellyfin user and list for switch profile when app is using Jellyfin.
/// Read from ServerRegistry; call [refresh] after login/switch.
class JellyfinProfileProvider extends ChangeNotifier {
  JellyfinProfileProvider();

  StorageService? _storage;
  ServerRegistry? _registry;
  JellyfinServerData? _data;
  String? _deviceId;

  JellyfinProfileUser? get currentUser {
    if (_data?.currentUser == null) return null;
    final u = _data!.currentUser!;
    return JellyfinProfileUser(
      userId: u.userId,
      userName: u.userName,
      primaryImageTag: u.primaryImageTag,
    );
  }

  String get baseUrl => _data?.baseUrl ?? '';

  /// List of stored users for switch profile.
  List<JellyfinProfileUser> get users {
    if (_data == null || _data!.users.isEmpty) return [];
    return _data!.users
        .map((u) => JellyfinProfileUser(
              userId: u.userId,
              userName: u.userName,
              primaryImageTag: u.primaryImageTag,
            ))
        .toList();
  }

  bool get hasMultipleUsers => (_data?.users.length ?? 0) > 1;

  /// Build avatar image URL for a user. Requires [baseUrl] to be set.
  /// When [JellyfinProfileUser.primaryImageTag] is null (e.g. legacy stored accounts), the tag-less
  /// Jellyfin URL still returns the current primary image if the request is authenticated.
  String imageUrlFor(JellyfinProfileUser user) {
    if (baseUrl.isEmpty) return '';
    final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final tag = user.primaryImageTag;
    if (tag != null && tag.isNotEmpty) {
      return '${base}Users/${user.userId}/Images/Primary?tag=${Uri.encodeComponent(tag)}';
    }
    return '${base}Users/${user.userId}/Images/Primary';
  }

  /// HTTP headers for loading [user]'s avatar (Jellyfin requires auth for user images on most servers).
  /// Uses that user's stored access token and the app device id (same shape as [JellyfinClient] requests).
  Map<String, String>? imageHttpHeadersFor(JellyfinProfileUser user) {
    if (_data == null) return null;
    String? token;
    for (final u in _data!.users) {
      if (u.userId == user.userId) {
        token = u.accessToken;
        break;
      }
    }
    if (token == null || token.isEmpty) return null;
    final did = _deviceId ?? JellyfinAuthService.defaultDeviceId;
    return {
      'Authorization': JellyfinAuthService.authHeaderWithToken(token, deviceId: did),
      'User-Agent': 'Finzy Flutter Client',
    };
  }

  Future<void> refresh() async {
    _storage ??= await StorageService.getInstance();
    _deviceId ??= await _storage!.getOrCreateDeviceId();
    _registry ??= ServerRegistry(_storage!);
    final servers = await _registry!.getServers();
    final jellyfin = servers.toList();
    if (jellyfin.isEmpty) {
      if (_data != null) {
        _data = null;
        notifyListeners();
      }
      return;
    }
    final newData = jellyfin.first.jellyfinData;
    final dataRefChanged = newData != _data;
    if (dataRefChanged) {
      _data = newData;
      notifyListeners();
    }
  }

  /// Callback after switching user (reconnect + refresh). Set by MainScreen.
  Future<void> Function()? onAfterSwitch;

  /// Switch to another stored user. Caller should then reconnect/invalidate (e.g. MainScreen callback).
  Future<bool> setCurrentUser(String userId) async {
    _storage ??= await StorageService.getInstance();
    _registry ??= ServerRegistry(_storage!);
    final ok = await _registry!.setCurrentJellyfinUser(userId);
    if (ok) {
      await refresh();
      await onAfterSwitch?.call();
    }
    return ok;
  }
}

