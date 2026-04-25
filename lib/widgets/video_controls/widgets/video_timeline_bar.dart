import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../mpv/mpv.dart';
import '../../../models/media_info.dart';
import '../../../providers/settings_provider.dart';
import '../../../utils/formatters.dart';
import 'timeline_slider.dart';

/// Encapsulates the StreamBuilder stack for video timeline with timestamps.
///
/// This widget listens to player position and duration streams, and displays
/// a timeline slider with formatted timestamps. Supports both horizontal
/// layout (timestamps beside slider) and vertical layout (timestamps below slider).
class VideoTimelineBar extends StatelessWidget {
  final Player player;
  final List<Chapter> chapters;
  final bool chaptersLoaded;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<Duration> onSeekEnd;

  /// If true, timestamps are shown in a row beside the slider (desktop layout).
  /// If false, timestamps are shown in a row below the slider (mobile layout).
  final bool horizontalLayout;

  /// Optional FocusNode for D-pad/keyboard navigation.
  final FocusNode? focusNode;

  /// Custom key event handler for focus navigation.
  final KeyEventResult Function(FocusNode, KeyEvent)? onKeyEvent;

  /// Called when focus changes.
  final ValueChanged<bool>? onFocusChange;

  /// Whether the timeline is enabled for interaction.
  final bool enabled;

  /// Whether to show the estimated finish time next to the remaining timestamp (mobile).
  final bool showFinishTime;

  /// Optional callback that returns a thumbnail URL for a given timestamp.
  final String Function(Duration time)? thumbnailUrlBuilder;

  /// When the player reports a growing or zero duration (e.g. HLS), use this as
  /// the timeline scale so the progress bar doesn't jump.
  final Duration? fallbackDuration;

  /// For transcode streams, the player reports position from stream start (0).
  /// Pass the playback start position in ms so we display and seek correctly.
  final int? positionOffsetMs;

  const VideoTimelineBar({
    super.key,
    required this.player,
    required this.chapters,
    required this.chaptersLoaded,
    required this.onSeek,
    required this.onSeekEnd,
    this.horizontalLayout = true,
    this.focusNode,
    this.onKeyEvent,
    this.onFocusChange,
    this.enabled = true,
    this.showFinishTime = false,
    this.thumbnailUrlBuilder,
    this.fallbackDuration,
    this.positionOffsetMs,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.streams.position,
      initialData: player.state.position,
      builder: (context, positionSnapshot) {
        return StreamBuilder<Duration>(
          stream: player.streams.duration,
          initialData: player.state.duration,
          builder: (context, durationSnapshot) {
            final rawPosition = positionSnapshot.data ?? Duration.zero;
            final playerDuration = durationSnapshot.data ?? Duration.zero;
            // Use fallback when player duration is zero or smaller (e.g. HLS buffer growth)
            final duration = (fallbackDuration != null &&
                    (playerDuration.inMilliseconds == 0 ||
                        playerDuration.inMilliseconds < fallbackDuration!.inMilliseconds))
                ? fallbackDuration!
                : playerDuration;
            // Transcode streams report position from stream start (0); add the server-provided
            // startTimeTicks offset to map to movie-time. Direct streams pass null and use raw.
            final position = positionOffsetMs != null
                ? Duration(milliseconds: positionOffsetMs! + rawPosition.inMilliseconds)
                : rawPosition;
            final remaining = position - duration; // We want this to be negative

            return horizontalLayout
                ? _buildHorizontalLayout(position, duration, remaining, playerDuration)
                : _buildVerticalLayout(position, duration, remaining, playerDuration);
          },
        );
      },
    );
  }

  Widget _buildHorizontalLayout(Duration position, Duration duration, Duration remaining, Duration playerDuration) {
    return Row(
      children: [
        _buildTimestamp(position),
        const SizedBox(width: 12),
        Expanded(child: _buildSlider(position, duration)),
        const SizedBox(width: 12),
        _buildTimestamp(remaining),
      ],
    );
  }

  Widget _buildVerticalLayout(Duration position, Duration duration, Duration remaining, Duration playerDuration) {
    return Column(
      children: [
        _buildSlider(position, duration),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [_buildTimestamp(position), _buildRemainingTimestamp(remaining)],
          ),
        ),
      ],
    );
  }

  Widget _buildTimestamp(Duration time) {
    return Text(formatDurationTimestamp(time), style: const TextStyle(color: Colors.white, fontSize: 14));
  }

  Widget _buildRemainingTimestamp(Duration remaining) {
    if (!showFinishTime || remaining.inSeconds >= 0) {
      return _buildTimestamp(remaining);
    }
    return StreamBuilder<double>(
      stream: player.streams.rate,
      initialData: player.state.rate,
      builder: (context, rateSnap) {
        final rate = rateSnap.data ?? 1.0;
        final use24h = context.read<SettingsProvider>().use24HourTime(context);
        final text = '${formatDurationTimestamp(remaining)} · ${formatFinishTime(remaining.abs(), rate: rate, use24Hour: use24h)}';
        return Text(text, style: const TextStyle(color: Colors.white, fontSize: 14));
      },
    );
  }

  /// Pass target (movie) position to parent. For direct play, parent uses player.seek().
  /// For transcode, parent uses seek-via-reload with this as the new start position.
  void _handleSeek(Duration targetPosition, Duration duration) {
    final clamped = Duration(
      milliseconds: targetPosition.inMilliseconds.clamp(0, duration.inMilliseconds),
    );
    onSeek(clamped);
  }

  void _handleSeekEnd(Duration targetPosition, Duration duration) {
    final clamped = Duration(
      milliseconds: targetPosition.inMilliseconds.clamp(0, duration.inMilliseconds),
    );
    onSeekEnd(clamped);
  }

  Widget _buildSlider(Duration position, Duration duration) {
    return TimelineSlider(
      position: position,
      duration: duration,
      chapters: chapters,
      chaptersLoaded: chaptersLoaded,
      onSeek: (pos) => _handleSeek(pos, duration),
      onSeekEnd: (pos) => _handleSeekEnd(pos, duration),
      focusNode: focusNode,
      onKeyEvent: onKeyEvent,
      onFocusChange: onFocusChange,
      enabled: enabled,
      thumbnailUrlBuilder: thumbnailUrlBuilder,
    );
  }
}
