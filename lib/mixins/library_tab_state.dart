import 'package:flutter/material.dart';
import '../models/media_library.dart';
import '../services/jellyfin_client.dart';
import '../utils/provider_extensions.dart';

/// Mixin providing common functionality for library tab screens
/// Provides server-specific client resolution for multi-server support
mixin LibraryTabStateMixin<T extends StatefulWidget> on State<T> {
  /// The library being displayed
  MediaLibrary get library;

  /// Get the correct JellyfinClient for this library's server
  /// Throws an exception if no client is available
  JellyfinClient getClientForLibrary() => context.getClientForLibrary(library);
}
