import 'package:flutter/material.dart';

import '../../../mpv/mpv.dart';
import '../../../widgets/overlay_sheet.dart';
import 'base_video_control_sheet.dart';
import '../helpers/track_filter_helper.dart';
import '../helpers/track_selection_helper.dart';

/// Generic track selection sheet for audio and subtitle tracks
///
/// Type parameter [T] should be either [AudioTrack] or [SubtitleTrack]
class TrackSelectionSheet<T> extends StatefulWidget {
  final Player player;
  final String title;
  final IconData icon;
  final List<T> Function(Tracks?) extractTracks;
  final T? Function(TrackSelection) getCurrentTrack;
  final String Function(T track, int index) buildLabel;
  final void Function(T track) setTrack;
  final Function(T)? onTrackChanged;
  final bool showOffOption;
  final T Function()? createOffTrack;
  final bool Function(T track)? isOffTrack;

  /// Optional tracks not yet in the player (e.g. external subtitles); shown after embedded tracks.
  final List<T>? extraTracks;

  /// Called when user selects an extra track (e.g. to load it on demand).
  final void Function(T track)? onExtraTrackSelected;

  const TrackSelectionSheet({
    super.key,
    required this.player,
    required this.title,
    required this.icon,
    required this.extractTracks,
    required this.getCurrentTrack,
    required this.buildLabel,
    required this.setTrack,
    this.onTrackChanged,
    this.showOffOption = false,
    this.createOffTrack,
    this.isOffTrack,
    this.extraTracks,
    this.onExtraTrackSelected,
  });

  @override
  State<TrackSelectionSheet<T>> createState() => _TrackSelectionSheetState<T>();
}

class _TrackSelectionSheetState<T> extends State<TrackSelectionSheet<T>> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Tracks>(
      stream: widget.player.streams.tracks,
      initialData: widget.player.state.tracks,
      builder: (context, snapshot) {
        final tracks = snapshot.data;
        final availableTracks = TrackFilterHelper.extractAndFilterTracks<T>(tracks, widget.extractTracks);
        final hasAnyTracks = availableTracks.isNotEmpty || (widget.extraTracks?.isNotEmpty ?? false);
        final sheetChild = !hasAnyTracks
            ? TrackSelectionHelper.buildEmptyState<T>()
            : _buildTrackList(availableTracks);

        return BaseVideoControlSheet(title: widget.title, icon: widget.icon, child: sheetChild);
      },
    );
  }

  Widget _buildTrackList(List<T> availableTracks) {
    return StreamBuilder<TrackSelection>(
      stream: widget.player.streams.track,
      initialData: widget.player.state.track,
      builder: (context, selectedSnapshot) {
        final currentTrack = selectedSnapshot.data ?? widget.player.state.track;
        final selectedTrack = widget.getCurrentTrack(currentTrack);
        final isOffSelected = TrackSelectionHelper.isOffSelected(selectedTrack, widget.isOffTrack);
        final extraTracks = widget.extraTracks ?? [];
        final itemCount = availableTracks.length + (widget.showOffOption ? 1 : 0) + extraTracks.length;

        return ListView.builder(
          itemCount: itemCount,
          itemBuilder: (context, index) {
            if (widget.showOffOption && index == 0) {
              return _buildOffTile(isOffSelected);
            }

            final trackIndex = widget.showOffOption ? index - 1 : index;
            if (trackIndex < availableTracks.length) {
              final track = availableTracks[trackIndex];
              final trackId = TrackSelectionHelper.getTrackId(track);
              final selectedId = selectedTrack == null ? '' : TrackSelectionHelper.getTrackId(selectedTrack);
              return TrackSelectionHelper.buildTrackTile<T>(
                label: widget.buildLabel(track, trackIndex),
                isSelected: trackId == selectedId,
                onTap: () {
                  widget.setTrack(track);
                  widget.onTrackChanged?.call(track);
                  OverlaySheetController.of(context).close();
                },
              );
            }

            // Extra track (e.g. external subtitle)
            final extraIndex = trackIndex - availableTracks.length;
            final extraTrack = extraTracks[extraIndex];
            return TrackSelectionHelper.buildTrackTile<T>(
              label: widget.buildLabel(extraTrack, availableTracks.length + extraIndex),
              isSelected: false,
              onTap: () {
                widget.onExtraTrackSelected?.call(extraTrack);
                OverlaySheetController.of(context).close();
              },
            );
          },
        );
      },
    );
  }

  Widget _buildOffTile(bool isOffSelected) {
    return TrackSelectionHelper.buildOffTile<T>(
      isSelected: isOffSelected,
      onTap: () {
        if (widget.createOffTrack != null) {
          final offTrack = widget.createOffTrack!();
          widget.setTrack(offTrack);
          widget.onTrackChanged?.call(offTrack);
        }
        OverlaySheetController.of(context).close();
      },
    );
  }
}
