/// Configuration for a Jellyfin server connection.
/// Used by [JellyfinClient] to build requests and image URLs.
class JellyfinConfig {
  final String baseUrl;
  final String token;
  final String userId;
  final String serverId;
  final String? serverName;
  final String deviceId;
  final String clientName;
  final String clientVersion;

  JellyfinConfig({
    required this.baseUrl,
    required this.token,
    required this.userId,
    required this.serverId,
    this.serverName,
    this.deviceId = 'plezy-jellyfin',
    this.clientName = 'Plezy',
    this.clientVersion = '1.0.0',
  });

  /// Authorization header value for Jellyfin API requests.
  String get authorizationHeader =>
      'MediaBrowser Client="$clientName", Device="Plezy", DeviceId="$deviceId", Version="$clientVersion", Token="$token"';

  JellyfinConfig copyWith({
    String? baseUrl,
    String? token,
    String? userId,
    String? serverId,
    String? serverName,
    String? deviceId,
    String? clientName,
    String? clientVersion,
  }) {
    return JellyfinConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      token: token ?? this.token,
      userId: userId ?? this.userId,
      serverId: serverId ?? this.serverId,
      serverName: serverName ?? this.serverName,
      deviceId: deviceId ?? this.deviceId,
      clientName: clientName ?? this.clientName,
      clientVersion: clientVersion ?? this.clientVersion,
    );
  }
}
