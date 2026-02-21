import 'package:flutter/material.dart';
import '../models/plex_library.dart';
import '../services/media_server_client.dart';
import '../utils/provider_extensions.dart';

/// Mixin providing common functionality for library tab screens
/// Provides server-specific client resolution for multi-server support
mixin LibraryTabStateMixin<T extends StatefulWidget> on State<T> {
  /// The library being displayed
  PlexLibrary get library;

  /// Get the correct MediaServerClient for this library's server
  /// Throws an exception if no client is available
  MediaServerClient getClientForLibrary() => context.getClientForLibrary(library);
}
