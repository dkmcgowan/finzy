import 'package:dio/dio.dart';

import '../models/jellyfin_public_user.dart';
import '../utils/app_logger.dart';

/// Result of successful Jellyfin authentication.
class JellyfinAuthResult {
  final String accessToken;
  final String userId;
  final String? serverId;
  final String? serverName;

  JellyfinAuthResult({
    required this.accessToken,
    required this.userId,
    this.serverId,
    this.serverName,
  });
}

/// State returned when initiating Quick Connect (code shown to user, secret used for polling).
class JellyfinQuickConnectState {
  final String code;
  final String secret;
  final bool authenticated;

  JellyfinQuickConnectState({
    required this.code,
    required this.secret,
    this.authenticated = false,
  });

  factory JellyfinQuickConnectState.fromJson(Map<String, dynamic> json) {
    return JellyfinQuickConnectState(
      code: json['Code'] as String? ?? '',
      secret: json['Secret'] as String? ?? '',
      authenticated: json['Authenticated'] as bool? ?? false,
    );
  }
}

/// Authenticates with a Jellyfin server (username/password).
/// Does not use a central discovery service; user provides server URL.
class JellyfinAuthService {
  JellyfinAuthService._();

  static const _clientName = 'Finzy';
  static const _clientVersion = '1.0.0';
  static const defaultDeviceId = 'finzy-jellyfin';

  /// Build Authorization header without token (for login).
  static String authHeaderNoToken({String? deviceId}) =>
      'MediaBrowser Client="$_clientName", Device="Finzy", DeviceId="${deviceId ?? defaultDeviceId}", Version="$_clientVersion"';

  /// Build Authorization header with token (for post-login API calls).
  static String authHeaderWithToken(String token, {String? deviceId}) =>
      'MediaBrowser Client="$_clientName", Device="Finzy", DeviceId="${deviceId ?? defaultDeviceId}", Version="$_clientVersion", Token="$token"';

  /// Authenticate by username and password.
  /// [baseUrl] should be the server base URL (e.g. https://jellyfin.example.com).
  /// [deviceId] should be a per-installation UUID from [StorageService.getOrCreateDeviceId].
  /// Returns [JellyfinAuthResult] with token and userId, or throws on failure.
  static Future<JellyfinAuthResult> authenticateByName({
    required String baseUrl,
    required String username,
    required String password,
    String? deviceId,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: timeout,
        receiveTimeout: timeout,
        contentType: 'application/json',
        headers: {'Authorization': authHeaderNoToken(deviceId: deviceId)},
      ),
    );

    final response = await dio.post<Map<String, dynamic>>(
      '/Users/AuthenticateByName',
      data: {'Username': username, 'Pw': password},
    );

    if (response.statusCode != 200 || response.data == null) {
      appLogger.e('Jellyfin auth failed: ${response.statusCode} ${response.data}');
      throw Exception('Jellyfin authentication failed');
    }

    final data = response.data!;
    final token = data['AccessToken'] as String?;
    final user = data['User'] as Map<String, dynamic>?;
    final userId = user?['Id'] as String?;

    if (token == null || token.isEmpty || userId == null || userId.isEmpty) {
      appLogger.e('Jellyfin auth response missing AccessToken or User.Id: $data');
      throw Exception('Invalid Jellyfin authentication response');
    }

    // Optional: server id from response (some servers return it)
    final serverId = data['ServerId'] as String?;

    return JellyfinAuthResult(
      accessToken: token,
      userId: userId,
      serverId: serverId,
    );
  }

  /// Test connection to a Jellyfin server (public system info, no auth).
  /// Returns true if the server is reachable.
  static Future<bool> testConnection(String baseUrl, {Duration timeout = const Duration(seconds: 5)}) async {
    try {
      final dio = Dio(BaseOptions(baseUrl: baseUrl, connectTimeout: timeout, receiveTimeout: timeout));
      final response = await dio.get('/System/Info/Public');
      return response.statusCode == 200;
    } catch (e) {
      appLogger.d('Jellyfin connection test failed: $e');
      return false;
    }
  }

  /// Get list of public users (no auth). Used on login screen to show user picker.
  /// May return empty if server requires auth for this endpoint.
  static Future<List<JellyfinPublicUser>> getPublicUsers(
    String baseUrl, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final dio = Dio(BaseOptions(baseUrl: baseUrl, connectTimeout: timeout, receiveTimeout: timeout));
      final response = await dio.get<List<dynamic>>('/Users/Public');
      if (response.statusCode != 200 || response.data == null) return [];
      return (response.data!)
          .map((e) => JellyfinPublicUser.fromJson(e as Map<String, dynamic>))
          .where((u) => u.id.isNotEmpty && u.name.isNotEmpty)
          .toList();
    } catch (e) {
      appLogger.w('Jellyfin getPublicUsers failed: $e');
      return [];
    }
  }

  /// Start Quick Connect; returns code to show user and secret for polling.
  /// Throws if Quick Connect is disabled (e.g. 401).
  static Future<JellyfinQuickConnectState> quickConnectInitiate(
    String baseUrl, {
    String? deviceId,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: timeout,
        receiveTimeout: timeout,
        headers: {'Authorization': authHeaderNoToken(deviceId: deviceId)},
      ),
    );
    final response = await dio.post<Map<String, dynamic>>('/QuickConnect/Initiate');
    if (response.statusCode != 200 || response.data == null) {
      appLogger.e('QuickConnect Initiate failed: ${response.statusCode}');
      throw Exception('Quick Connect failed');
    }
    return JellyfinQuickConnectState.fromJson(response.data!);
  }

  /// Poll Quick Connect state; when authenticated is true, call authenticateWithQuickConnect.
  /// Uses GET /QuickConnect/Connect (not /State) per Jellyfin API.
  static Future<JellyfinQuickConnectState> quickConnectGetState(
    String baseUrl,
    String secret, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final dio = Dio(BaseOptions(baseUrl: baseUrl, connectTimeout: timeout, receiveTimeout: timeout));
    final response = await dio.get<Map<String, dynamic>>(
      '/QuickConnect/Connect',
      queryParameters: {'secret': secret},
    );
    if (response.statusCode != 200 || response.data == null) {
      throw Exception('Quick Connect state failed');
    }
    return JellyfinQuickConnectState.fromJson(response.data!);
  }

  /// Exchange Quick Connect secret for access token after user authorized on another device.
  static Future<JellyfinAuthResult> authenticateWithQuickConnect(
    String baseUrl,
    String secret, {
    String? deviceId,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: timeout,
        receiveTimeout: timeout,
        contentType: 'application/json',
        headers: {'Authorization': authHeaderNoToken(deviceId: deviceId)},
      ),
    );
    final response = await dio.post<Map<String, dynamic>>(
      '/Users/AuthenticateWithQuickConnect',
      data: {'Secret': secret},
    );
    if (response.statusCode != 200 || response.data == null) {
      appLogger.e('AuthenticateWithQuickConnect failed: ${response.statusCode}');
      throw Exception('Quick Connect authentication failed');
    }
    final data = response.data!;
    final token = data['AccessToken'] as String?;
    final user = data['User'] as Map<String, dynamic>?;
    final userId = user?['Id'] as String?;
    if (token == null || token.isEmpty || userId == null || userId.isEmpty) {
      throw Exception('Invalid Quick Connect response');
    }
    return JellyfinAuthResult(
      accessToken: token,
      userId: userId,
      serverId: data['ServerId'] as String?,
    );
  }
}
