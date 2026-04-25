import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../mpv/mpv.dart';
import '../models/media_metadata.dart';
import '../providers/playback_state_provider.dart';
import '../utils/app_logger.dart';
import '../utils/content_utils.dart';
import '../utils/video_player_navigation.dart';
import 'jellyfin_client.dart';

/// Result of loading adjacent episodes
class AdjacentEpisodes {
  final MediaMetadata? next;
  final MediaMetadata? previous;

  AdjacentEpisodes({this.next, this.previous});

  bool get hasNext => next != null;
  bool get hasPrevious => previous != null;
}

/// Manages episode navigation for TV show playback.
///
/// Handles:
/// - Loading next/previous episodes from play queues
/// - Navigating between episodes while preserving track selections
/// - Supporting both sequential and shuffle playback modes
///
/// All episode navigation uses play queues for consistent behavior.
class EpisodeNavigationService {
  /// Load the next and previous episodes for the current episode.
  ///
  /// If a play queue is active (shuffle, play-all from collection), neighbours
  /// come from the queue. Otherwise we look them up directly from the series in
  /// Jellyfin, walking across seasons by (parentIndex, index). Returns nulls
  /// for movies, missing series metadata, or edges of the series.
  Future<AdjacentEpisodes> loadAdjacentEpisodes({
    required BuildContext context,
    required JellyfinClient client,
    required MediaMetadata metadata,
  }) async {
    try {
      final playbackState = context.read<PlaybackStateProvider>();

      if (playbackState.isQueueActive) {
        final next = await playbackState.getNextEpisode(metadata.itemId, loopQueue: false);
        final previous = await playbackState.getPreviousEpisode(metadata.itemId);
        return AdjacentEpisodes(next: next, previous: previous);
      }

      if (!metadata.isEpisode || metadata.seriesId == null) {
        return AdjacentEpisodes();
      }

      final episodes = await client.getSeriesEpisodes(metadata.seriesId!);
      if (episodes.isEmpty) return AdjacentEpisodes();

      final sorted = List<MediaMetadata>.from(episodes)
        ..sort((a, b) {
          final seasonCmp = (a.parentIndex ?? 0).compareTo(b.parentIndex ?? 0);
          if (seasonCmp != 0) return seasonCmp;
          return (a.index ?? 0).compareTo(b.index ?? 0);
        });

      final currentIdx = sorted.indexWhere((ep) => ep.itemId == metadata.itemId);
      if (currentIdx == -1) return AdjacentEpisodes();

      return AdjacentEpisodes(
        previous: currentIdx > 0 ? sorted[currentIdx - 1] : null,
        next: currentIdx < sorted.length - 1 ? sorted[currentIdx + 1] : null,
      );
    } catch (e) {
      appLogger.d('Could not load adjacent episodes', error: e);
      return AdjacentEpisodes();
    }
  }

  /// Navigate to the next or previous episode
  ///
  /// Preserves the current audio track, subtitle track, and playback rate
  /// selections when transitioning between episodes.
  Future<void> navigateToEpisode({
    required BuildContext context,
    required MediaMetadata episode,
    required Player? player,
    bool usePushReplacement = true,
  }) async {
    if (!context.mounted) return;

    // Capture current player state before navigation
    AudioTrack? currentAudioTrack;
    SubtitleTrack? currentSubtitleTrack;
    double? currentPlaybackRate;

    if (player != null) {
      currentAudioTrack = player.state.track.audio;
      currentSubtitleTrack = player.state.track.subtitle;
      currentPlaybackRate = player.state.rate;

      appLogger.d(
        'Navigating to episode with preserved settings - Audio: ${currentAudioTrack?.id}, Subtitle: ${currentSubtitleTrack?.id}, Rate: ${currentPlaybackRate}x',
      );
    }

    // Navigate to the new episode
    if (context.mounted) {
      navigateToVideoPlayer(
        context,
        metadata: episode,
        preferredAudioTrack: currentAudioTrack,
        preferredSubtitleTrack: currentSubtitleTrack,
        usePushReplacement: usePushReplacement,
      );
    }
  }
}
