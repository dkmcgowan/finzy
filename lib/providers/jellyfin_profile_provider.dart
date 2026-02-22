import 'package:flutter/material.dart';
import '../models/registered_server.dart';
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
  String imageUrlFor(JellyfinProfileUser user) {
    if (baseUrl.isEmpty || user.primaryImageTag == null) return '';
    final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    return '${base}Users/${user.userId}/Images/Primary?tag=${Uri.encodeComponent(user.primaryImageTag!)}';
  }

  Future<void> refresh() async {
    _storage ??= await StorageService.getInstance();
    _registry ??= ServerRegistry(_storage!);
    final servers = await _registry!.getServers();
    final jellyfin = servers.where((s) => s.isJellyfin).toList();
    if (jellyfin.isEmpty) {
      if (_data != null) {
        _data = null;
        notifyListeners();
      }
      return;
    }
    final newData = jellyfin.first.jellyfinData;
    if (newData != _data) {
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

