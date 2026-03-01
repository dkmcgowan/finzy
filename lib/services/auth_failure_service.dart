import 'dart:async';

import '../utils/app_logger.dart';

/// Notifies when a Jellyfin API request returns 401 Unauthorized (e.g. token expired).
/// The app should listen and prompt the user to sign in again.
class AuthFailureService {
  AuthFailureService._();

  static final AuthFailureService instance = AuthFailureService._();

  final _controller = StreamController<String>.broadcast();

  /// When true, the app is on AuthScreen or SetupScreen (pre-login flow).
  /// Session-expired dialogs are suppressed in this state since the user isn't logged in.
  static bool isOnAuthOrSetupFlow = false;

  /// Emits serverId when that server returns 401.
  Stream<String> get authFailureStream => _controller.stream;

  /// Call when a 401 response is received for [serverId].
  void notifyAuthFailure(String serverId) {
    appLogger.w('Auth failure (401) for server: $serverId');
    if (!_controller.isClosed) {
      _controller.add(serverId);
    }
  }

  void dispose() {
    _controller.close();
  }
}
