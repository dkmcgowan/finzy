import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Helper class for managing device orientation preferences across the app.
class OrientationHelper {
  /// Restores default orientation preferences.
  ///
  /// Allows all orientations (portrait and landscape) so the app rotates
  /// with the device. Called when leaving full-screen experiences like
  /// the video player to restore the app's default orientation behavior.
  static void restoreDefaultOrientations(BuildContext context) {
    // Allow all orientations on mobile and desktop
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  /// Sets orientation to landscape-only mode.
  ///
  /// Used by the video player to force landscape orientation during playback.
  static void setLandscapeOrientation() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  }

  /// Restores edge-to-edge system UI mode.
  ///
  /// Should be called when exiting full-screen mode.
  static void restoreSystemUI() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
}
