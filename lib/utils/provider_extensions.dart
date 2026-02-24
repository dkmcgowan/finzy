import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/jellyfin_client.dart';
import '../i18n/strings.g.dart';
import '../models/media_library.dart';
import '../models/media_metadata.dart';
import '../models/user_profile_preferences.dart';
import '../providers/hidden_libraries_provider.dart';
import '../providers/multi_server_provider.dart';
import '../providers/user_profile_provider.dart';
import 'app_logger.dart';

extension ProviderExtensions on BuildContext {
  UserProfileProvider get userProfile => Provider.of<UserProfileProvider>(this, listen: false);

  UserProfileProvider watchUserProfile() => Provider.of<UserProfileProvider>(this, listen: true);

  HiddenLibrariesProvider get hiddenLibraries => Provider.of<HiddenLibrariesProvider>(this, listen: false);

  HiddenLibrariesProvider watchHiddenLibraries() => Provider.of<HiddenLibrariesProvider>(this, listen: true);

  // Direct profile settings access (nullable)
  UserProfilePreferences? get profileSettings => userProfile.profileSettings;

  /// Get Jellyfin client for a specific server ID
  JellyfinClient getClientForServer(String serverId) {
    final multiServerProvider = Provider.of<MultiServerProvider>(this, listen: false);

    final serverClient = multiServerProvider.getClientForServer(serverId);

    if (serverClient == null) {
      appLogger.e('No client found for server $serverId');
      throw Exception(t.errors.noClientAvailable);
    }

    return serverClient;
  }

  /// Get client for a library
  JellyfinClient getClientForLibrary(MediaLibrary library) {
    if (library.serverId == null) {
      final multiServerProvider = Provider.of<MultiServerProvider>(this, listen: false);
      if (!multiServerProvider.hasConnectedServers) {
        throw Exception(t.errors.noClientAvailable);
      }
      return getClientForServer(multiServerProvider.onlineServerIds.first);
    }
    return getClientForServer(library.serverId!);
  }

  /// Get client for metadata, with fallback to first available server
  JellyfinClient getClientForMetadata(MediaMetadata metadata) {
    if (metadata.serverId != null) {
      return getClientForServer(metadata.serverId!);
    }
    return getFirstAvailableClient();
  }

  /// Get client for metadata, or null if offline mode or no serverId
  JellyfinClient? getClientForMetadataOrNull(MediaMetadata metadata, {bool isOffline = false}) {
    if (isOffline || metadata.serverId == null) {
      return null;
    }
    return Provider.of<MultiServerProvider>(this, listen: false).getClientForServer(metadata.serverId!);
  }

  /// Get the first available client from connected servers
  JellyfinClient getFirstAvailableClient() {
    final multiServerProvider = Provider.of<MultiServerProvider>(this, listen: false);
    if (!multiServerProvider.hasConnectedServers) {
      throw Exception(t.errors.noClientAvailable);
    }
    return getClientForServer(multiServerProvider.onlineServerIds.first);
  }

  /// Get client for a serverId with fallback to first available server
  /// Useful for items that might not have a serverId
  JellyfinClient getClientWithFallback(String? serverId) {
    if (serverId != null) {
      return getClientForServer(serverId);
    }
    return getFirstAvailableClient();
  }
}
