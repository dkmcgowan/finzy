import 'dart:async';

import '../mpv/mpv.dart';

import 'jellyfin_client.dart';
import 'offline_watch_sync_service.dart';
import '../models/media_metadata.dart';
import '../utils/app_logger.dart';
import '../utils/watch_state_notifier.dart';

/// Tracks playback progress and reports it to the Jellyfin server.
///
/// Handles:
/// - Playback start (POST /Sessions/Playing) when playback begins
/// - Periodic timeline updates during playback (online) or queuing (offline)
/// - Playback stopped (POST /Sessions/Playing/Stopped) when playback ends
/// - Resume position tracking
/// - State change reporting (playing, paused, stopped)
/// - Offline progress queuing for later sync
class PlaybackProgressTracker {
  /// Media server client for online progress updates (null when offline)
  final JellyfinClient? client;

  /// Metadata of the media being played
  final MediaMetadata metadata;

  /// Video player instance
  final Player player;

  /// Whether playback is in offline mode
  final bool isOffline;

  /// Service for queuing offline progress updates
  final OfflineWatchSyncService? offlineWatchService;

  /// PlaySessionId from PlaybackInfo; for playback reporting.
  final String? playSessionId;

  /// MediaSourceId of the chosen source; for playback reporting.
  final String? mediaSourceId;

  /// PlayMethod: DirectPlay, DirectStream, or Transcode.
  final String playMethod;

  /// True when using transcoding; stopActiveEncodings is called on stop.
  final bool isTranscode;

  /// Timer for periodic progress updates
  Timer? _progressTimer;

  /// Update interval (default: 10 seconds)
  final Duration updateInterval;

  /// Whether we have sent the playback start report (only once per session).
  bool _hasReportedStart = false;

  /// Counts consecutive online progress failures for backoff logic.
  int _consecutiveFailures = 0;

  /// Timer ticks to skip before retrying after failures (exponential backoff).
  int _ticksToSkip = 0;

  PlaybackProgressTracker({
    required this.client,
    required this.metadata,
    required this.player,
    this.isOffline = false,
    this.offlineWatchService,
    this.playSessionId,
    this.mediaSourceId,
    this.playMethod = 'DirectStream',
    this.isTranscode = false,
    this.updateInterval = const Duration(seconds: 10),
  }) : assert(!isOffline || offlineWatchService != null, 'offlineWatchService is required when isOffline is true'),
       assert(isOffline || client != null, 'client is required when isOffline is false');

  /// Start tracking playback progress
  ///
  /// Begins periodic timeline updates to the server (online)
  /// or queuing progress updates locally (offline).
  /// For online mode, the first progress send will also report playback start.
  void startTracking() {
    if (_progressTimer != null) {
      appLogger.w('Progress tracking already started');
      return;
    }

    // Send initial progress immediately (don't wait for first timer tick).
    // This will also call reportPlaybackStart on first send (online only).
    if (player.state.playing) {
      _sendProgress('playing');
    }

    _progressTimer = Timer.periodic(updateInterval, (timer) {
      if (player.state.playing) {
        // Skip ticks when backing off after consecutive failures to avoid
        // flooding the network with doomed requests during an outage.
        if (_ticksToSkip > 0) {
          _ticksToSkip--;
          return;
        }
        _sendProgress('playing');
      }
    });

    appLogger.d('Started progress tracking (interval: ${updateInterval.inSeconds}s, offline: $isOffline)');
  }

  /// Stop tracking playback progress
  ///
  /// Cancels the periodic timer.
  void stopTracking() {
    _progressTimer?.cancel();
    _progressTimer = null;
    appLogger.d('Stopped progress tracking');
  }

  /// Send progress update to server or queue locally
  ///
  /// [state] can be 'playing', 'paused', or 'stopped'
  Future<void> sendProgress(String state) async {
    await _sendProgress(state);
  }

  Future<void> _sendProgress(String state) async {
    try {
      final position = player.state.position;
      final duration = player.state.duration;

      appLogger.d(
        '[PlaybackDebug] PlaybackProgressTracker._sendProgress: state=$state '
        'position=${position.inSeconds}s (${position.inMilliseconds}ms) '
        'duration=${duration.inSeconds}s (${duration.inMilliseconds}ms)',
      );

      // Don't send progress if no duration (not ready)
      if (duration.inMilliseconds == 0) {
        appLogger.d('[PlaybackDebug] PlaybackProgressTracker: SKIPPING send (duration=0)');
        return;
      }

      if (isOffline) {
        // Queue progress update for later sync
        await _sendOfflineProgress(position, duration);
      } else if (state == 'stopped') {
        // Stopped: use dedicated endpoint (jellyfin-web parity)
        await _sendPlaybackStopped(position, duration);
        _resetBackoff();
      } else {
        // Fire-and-forget for playing/paused — avoid blocking the Dart event loop
        _sendOnlineProgress(state, position, duration)
            .then((_) {
              _resetBackoff();
            })
            .catchError((Object e) {
              _consecutiveFailures++;
              // Exponential backoff: skip 1, 2, 4, 8... ticks (capped at 6 ≈ 60s)
              _ticksToSkip = (1 << (_consecutiveFailures - 1)).clamp(1, 6);
              appLogger.d(
                'Progress update failed ($_consecutiveFailures consecutive), '
                'skipping next $_ticksToSkip tick(s)',
                error: e,
              );
            });
      }

      // Emit watch state event on stop for UI updates across screens
      if (state == 'stopped' && position.inMilliseconds > 0) {
        appLogger.d(
          '[PlaybackDebug] WatchStateNotifier.notifyProgress: resumePositionMs=${position.inMilliseconds} duration=${duration.inMilliseconds} '
          'percent=${(position.inMilliseconds / duration.inMilliseconds * 100).toStringAsFixed(1)}%',
        );
        WatchStateNotifier().notifyProgress(
          metadata: metadata,
          resumePositionMs: position.inMilliseconds,
          duration: duration.inMilliseconds,
        );
      }
    } catch (e) {
      if (!isOffline) {
        _consecutiveFailures++;
        _ticksToSkip = (1 << (_consecutiveFailures - 1)).clamp(1, 6);
        appLogger.d(
          'Progress update failed ($_consecutiveFailures consecutive), '
          'skipping next $_ticksToSkip tick(s)',
          error: e,
        );
      } else {
        appLogger.d('Failed to send progress update (non-critical)', error: e);
      }
    }
  }

  void _resetBackoff() {
    if (_consecutiveFailures > 0) {
      _consecutiveFailures = 0;
      _ticksToSkip = 0;
    }
  }

  /// Send playback start (once per session) then progress. Called for playing/paused.
  Future<void> _sendOnlineProgress(String state, Duration position, Duration duration) async {
    // Report playback start on first progress (jellyfin-web parity)
    if (!_hasReportedStart) {
      _hasReportedStart = true;
      await client!.reportPlaybackStart(
        itemId: metadata.itemId,
        positionMs: position.inMilliseconds,
        playMethod: playMethod,
        mediaSourceId: mediaSourceId,
        playSessionId: playSessionId,
      );
    }
    await client!.updateProgress(
      metadata.itemId,
      time: position.inMilliseconds,
      state: state,
      duration: duration.inMilliseconds,
      mediaSourceId: mediaSourceId,
      playSessionId: playSessionId,
    );
  }

  /// Send playback stopped (jellyfin-web parity). Called when playback ends.
  Future<void> _sendPlaybackStopped(Duration position, Duration duration) async {
    await client!.reportPlaybackStopped(
      itemId: metadata.itemId,
      positionMs: position.inMilliseconds,
      durationMs: duration.inMilliseconds,
      mediaSourceId: mediaSourceId,
      playSessionId: playSessionId,
    );
    // Stop transcoding to free server resources
    if (isTranscode && playSessionId != null && playSessionId!.isNotEmpty) {
      client!.stopActiveEncodings(playSessionId!);
    }
  }

  /// Queue progress update locally (offline mode)
  Future<void> _sendOfflineProgress(Duration position, Duration duration) async {
    final serverId = metadata.serverId;
    if (serverId == null) {
      appLogger.w('Cannot queue offline progress: serverId is null');
      return;
    }

    await offlineWatchService!.queueProgressUpdate(
      serverId: serverId,
      itemId: metadata.itemId,
      resumePositionMs: position.inMilliseconds,
      duration: duration.inMilliseconds,
    );

    final percent = (position.inMilliseconds / duration.inMilliseconds * 100);
    appLogger.d(
      'Offline progress queued: ${position.inSeconds}s / ${duration.inSeconds}s (${percent.toStringAsFixed(1)}%)',
    );
  }

  /// Dispose resources
  void dispose() {
    stopTracking();
  }
}
