import 'jellyfin_client.dart';
import '../models/media_info.dart';
import '../models/media_metadata.dart';
import '../models/download_models.dart';
import '../mpv/mpv.dart';
import '../utils/app_logger.dart';
import '../utils/error_message_utils.dart';
import '../i18n/strings.g.dart';
import '../database/app_database.dart';
import 'download_storage_service.dart';
import 'settings_service.dart';
import 'dart:io';
import 'package:drift/drift.dart';

/// Service responsible for fetching video playback data from the media server
class PlaybackInitializationService {
  final JellyfinClient client;
  final AppDatabase? database;

  PlaybackInitializationService({required this.client, this.database});

  /// Format a video path as a URL (adds file:// prefix for file paths)
  String _formatVideoUrl(String path) {
    return path.contains('://') ? path : 'file://$path';
  }

  /// Check if content is available offline and return local path
  ///
  /// Returns the local file path if the video is downloaded and completed.
  /// Returns null if not available offline or database is not provided.
  Future<String?> getOfflineVideoPath(String serverId, String itemId) async {
    if (database == null) {
      return null;
    }

    try {
      // Query database for downloaded media with matching serverId and itemId
      final query = database!.select(database!.downloadedMedia)
        ..where((tbl) => tbl.serverId.equals(serverId) & tbl.itemId.equals(itemId));

      final downloadedItem = await query.getSingleOrNull();

      // Return null if not found or not completed
      if (downloadedItem == null || downloadedItem.status != DownloadStatus.completed.index) {
        return null;
      }

      // Return null if no video file path
      if (downloadedItem.videoFilePath == null) {
        return null;
      }

      final storageService = DownloadStorageService.instance;
      final storedPath = downloadedItem.videoFilePath!;

      // Get readable path (handles both SAF URIs and file paths)
      final readablePath = await storageService.getReadablePath(storedPath);

      // For file paths (not SAF), verify the file exists
      if (!storageService.isSafUri(storedPath)) {
        final file = File(readablePath);
        if (!await file.exists()) {
          appLogger.w('Offline video file not found: $readablePath (stored as: $storedPath)');
          return null;
        }
      }

      appLogger.d('Found offline video: $readablePath');
      return readablePath;
    } catch (e) {
      appLogger.w('Error checking offline video path', error: e);
      return null;
    }
  }

  /// Fetch playback data for the given metadata
  ///
  /// Returns a PlaybackInitializationResult with video URL and available versions
  /// If [preferOffline] is true and offline content is available, uses local file
  /// When [enableExternalSubtitles] is false, external subtitle list is empty so video loads fast.
  /// When [overrideResumePositionMs] is set (e.g. quality change restart), use it for the URL
  /// so transcode streams start at the correct position.
  Future<PlaybackInitializationResult> getPlaybackData({
    required MediaMetadata metadata,
    required int selectedMediaIndex,
    bool preferOffline = false,
    bool enableExternalSubtitles = false,
    int? overrideResumePositionMs,
  }) async {
    try {
      // Check for offline content first if preferOffline is enabled
      String? offlineVideoPath;
      if (preferOffline && database != null) {
        offlineVideoPath = await getOfflineVideoPath(client.serverId, metadata.itemId);
      }

      // If offline video is available, use it
      if (offlineVideoPath != null) {
        appLogger.d('Using offline playback for ${metadata.itemId}');

        // For offline playback, we still need to fetch media info for subtitles
        // but use the local file path for video
        try {
          final settings = await SettingsService.getInstance();
          final startMs = overrideResumePositionMs ?? metadata.resumePositionMs;
          final playbackData = await client.getVideoPlaybackData(
            metadata.itemId,
            mediaIndex: selectedMediaIndex,
            playbackMode: settings.getPlaybackMode(),
            startPositionMs: startMs,
          );

          final externalSubtitles = enableExternalSubtitles ? _buildExternalSubtitles(playbackData.mediaInfo) : <SubtitleTrack>[];

          return PlaybackInitializationResult(
            availableVersions: playbackData.availableVersions,
            videoUrl: _formatVideoUrl(offlineVideoPath),
            mediaInfo: playbackData.mediaInfo,
            externalSubtitles: externalSubtitles,
            isOffline: true,
          );
        } catch (e) {
          // If we can't fetch media info (e.g., no network), use offline-only mode
          appLogger.w('Failed to fetch media info for offline video, using offline-only mode', error: e);
          return PlaybackInitializationResult(
            availableVersions: [],
            videoUrl: _formatVideoUrl(offlineVideoPath),
            mediaInfo: null,
            externalSubtitles: const [],
            isOffline: true,
          );
        }
      }

      // Fall back to network streaming
      final settings = await SettingsService.getInstance();
      final mode = settings.getPlaybackMode();
      final startMs = overrideResumePositionMs ?? metadata.resumePositionMs;
      appLogger.d('Playback init: itemId=${metadata.itemId} playbackMode=${mode.name} startMs=$startMs');
      final playbackData = await client.getVideoPlaybackData(
        metadata.itemId,
        mediaIndex: selectedMediaIndex,
        playbackMode: mode,
        startPositionMs: startMs,
      );

      if (!playbackData.hasValidVideoUrl) {
        throw PlaybackException(
          playbackData.playbackErrorReason ?? t.messages.fileInfoNotAvailable,
        );
      }

      final externalSubtitles = enableExternalSubtitles ? _buildExternalSubtitles(playbackData.mediaInfo) : <SubtitleTrack>[];

      return PlaybackInitializationResult(
        availableVersions: playbackData.availableVersions,
        videoUrl: playbackData.videoUrl,
        mediaInfo: playbackData.mediaInfo,
        externalSubtitles: externalSubtitles,
        isOffline: false,
      );
    } catch (e, st) {
      if (e is PlaybackException) {
        rethrow;
      }
      logErrorWithStackTrace('Playback initialization failed', e, st);
      throw PlaybackException(t.messages.errorLoading(error: safeUserMessage(e)));
    }
  }

  /// Build list of external subtitle tracks from media info
  List<SubtitleTrack> _buildExternalSubtitles(MediaInfo? mediaInfo) {
    final externalSubtitles = <SubtitleTrack>[];

    if (mediaInfo == null) {
      return externalSubtitles;
    }

    final externalTracks = mediaInfo.subtitleTracks.where((MediaSubtitleTrack track) => track.isExternal).toList();

    if (externalTracks.isNotEmpty) {
      appLogger.d('Found ${externalTracks.length} external subtitle track(s)');
    }

    for (final serverTrack in externalTracks) {
      try {
        // Skip if no auth token is available
        final token = client.token;
        if (token == null) {
          appLogger.w('No auth token available for external subtitles');
          continue;
        }

        final url = serverTrack.getSubtitleUrl(client.baseUrl, token);

        // Skip if URL couldn't be constructed
        if (url == null) continue;

        externalSubtitles.add(
          SubtitleTrack.uri(
            url,
            title: serverTrack.displayTitle ?? serverTrack.language ?? 'Track ${serverTrack.id}',
            language: serverTrack.languageCode,
          ),
        );
      } catch (e) {
        // Silent fallback - log error but continue with other subtitles
        appLogger.w('Failed to add external subtitle track ${serverTrack.id}', error: e);
      }
    }

    return externalSubtitles;
  }
}

/// Result of playback initialization
class PlaybackInitializationResult {
  final List<dynamic> availableVersions;
  final String? videoUrl;
  final MediaInfo? mediaInfo;
  final List<SubtitleTrack> externalSubtitles;
  final bool isOffline;

  PlaybackInitializationResult({
    required this.availableVersions,
    this.videoUrl,
    this.mediaInfo,
    this.externalSubtitles = const [],
    this.isOffline = false,
  });
}

/// Exception thrown when playback initialization fails
class PlaybackException implements Exception {
  final String message;

  PlaybackException(this.message);

  @override
  String toString() => message;
}
