/// Centralized connection timeout constants used across the app.
class ConnectionTimeouts {
  /// Timeout for [MultiServerManager.connectToAllServers] — the maximum time
  /// to wait for each server's connection future.
  static const connectAll = Duration(seconds: 10);

  /// Dio connect timeout for individual HTTP requests to the server.
  static const connect = Duration(seconds: 10);

  /// Dio receive timeout for streaming/large responses.
  static const receive = Duration(seconds: 120);
}
