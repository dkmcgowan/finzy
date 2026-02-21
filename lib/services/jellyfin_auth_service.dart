import 'package:dio/dio.dart';

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

/// Authenticates with a Jellyfin server (username/password).
/// Does not use a central discovery service; user provides server URL.
class JellyfinAuthService {
  JellyfinAuthService._();

  static const _clientName = 'Plezy';
  static const _clientVersion = '1.0.0';
  static const _deviceId = 'plezy-jellyfin';

  /// Build Authorization header without token (for login).
  static String _authHeaderNoToken() =>
      'MediaBrowser Client="$_clientName", Device="Plezy", DeviceId="$_deviceId", Version="$_clientVersion"';

  /// Authenticate by username and password.
  /// [baseUrl] should be the server base URL (e.g. https://jellyfin.example.com).
  /// Returns [JellyfinAuthResult] with token and userId, or throws on failure.
  static Future<JellyfinAuthResult> authenticateByName({
    required String baseUrl,
    required String username,
    required String password,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: timeout,
        receiveTimeout: timeout,
        contentType: 'application/json',
        headers: {'Authorization': _authHeaderNoToken()},
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
}
