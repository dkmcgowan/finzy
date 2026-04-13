import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../i18n/strings.g.dart';
import '../../../mpv/mpv.dart';
import '../../../utils/track_label_builder.dart';
import '../../../widgets/overlay_sheet.dart';
import '../../../widgets/scroll_to_index_list_view.dart';
import '../helpers/track_filter_helper.dart';
import '../helpers/track_selection_helper.dart';
import 'base_video_control_sheet.dart';

/// Combined sheet for audio and subtitle track selection (Plezy-style).
///
/// Shows a two-column layout when both are available; otherwise a single list.
/// [availableExternalSubtitles] are Jellyfin/server tracks loaded on demand.
class TrackSheet extends StatelessWidget {
  final Player player;
  final Function(AudioTrack)? onAudioTrackChanged;
  final Function(SubtitleTrack)? onSubtitleTrackChanged;
  final List<SubtitleTrack> availableExternalSubtitles;
  final Future<void> Function(SubtitleTrack)? onExternalSubtitleSelected;

  const TrackSheet({
    super.key,
    required this.player,
    this.onAudioTrackChanged,
    this.onSubtitleTrackChanged,
    this.availableExternalSubtitles = const [],
    this.onExternalSubtitleSelected,
  });

  static const double _sideBySideMinWidth = 520;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Tracks>(
      stream: player.streams.tracks,
      initialData: player.state.tracks,
      builder: (context, tracksSnapshot) {
        final tracks = tracksSnapshot.data;
        final audioTracks = TrackFilterHelper.extractAndFilterTracks<AudioTrack>(
          tracks,
          (t) => t?.audio ?? [],
        );
        final embeddedSubs = TrackFilterHelper.extractAndFilterTracks<SubtitleTrack>(
          tracks,
          (t) => t?.subtitle ?? [],
        );
        final extras = availableExternalSubtitles;

        final showAudio = audioTracks.isNotEmpty;
        final showSubtitles = embeddedSubs.isNotEmpty || extras.isNotEmpty;

        final String title;
        final IconData icon;
        if (showAudio && showSubtitles) {
          title = t.videoControls.tracksButton;
          icon = Symbols.subtitles_rounded;
        } else if (showAudio) {
          title = t.videoControls.audioLabel;
          icon = Symbols.audiotrack_rounded;
        } else {
          title = t.videoControls.subtitlesLabel;
          icon = Symbols.subtitles_rounded;
        }

        return BaseVideoControlSheet(
          title: title,
          icon: icon,
          child: StreamBuilder<TrackSelection>(
            stream: player.streams.track,
            initialData: player.state.track,
            builder: (context, selSnapshot) {
              final selection = selSnapshot.data ?? player.state.track;

              if (!showAudio && !showSubtitles) {
                return TrackSelectionHelper.buildEmptyState<SubtitleTrack>();
              }

              if (showAudio && showSubtitles) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final sideBySide = constraints.maxWidth >= _sideBySideMinWidth;
                    final audioCol = _AudioTrackColumn(
                      tracks: audioTracks,
                      selection: selection,
                      player: player,
                      onTrackChanged: onAudioTrackChanged,
                      showHeader: true,
                    );
                    final subCol = _SubtitleTrackColumn(
                      embeddedTracks: embeddedSubs,
                      extraTracks: extras,
                      selection: selection,
                      player: player,
                      onTrackChanged: onSubtitleTrackChanged,
                      onExternalSubtitleSelected: onExternalSubtitleSelected,
                      showHeader: true,
                    );
                    if (sideBySide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: FocusTraversalGroup(child: audioCol)),
                          const VerticalDivider(width: 1, color: Colors.white24),
                          Expanded(child: FocusTraversalGroup(child: subCol)),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: FocusTraversalGroup(child: audioCol)),
                        const Divider(height: 1, color: Colors.white24),
                        Expanded(child: FocusTraversalGroup(child: subCol)),
                      ],
                    );
                  },
                );
              }

              if (showAudio) {
                return _AudioTrackColumn(
                  tracks: audioTracks,
                  selection: selection,
                  player: player,
                  onTrackChanged: onAudioTrackChanged,
                  showHeader: false,
                );
              }

              return _SubtitleTrackColumn(
                embeddedTracks: embeddedSubs,
                extraTracks: extras,
                selection: selection,
                player: player,
                onTrackChanged: onSubtitleTrackChanged,
                onExternalSubtitleSelected: onExternalSubtitleSelected,
                showHeader: false,
              );
            },
          ),
        );
      },
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  final String label;

  const _ColumnHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white70),
        ),
      ),
    );
  }
}

class _AudioTrackColumn extends StatelessWidget {
  final List<AudioTrack> tracks;
  final TrackSelection selection;
  final Player player;
  final Function(AudioTrack)? onTrackChanged;
  final bool showHeader;

  const _AudioTrackColumn({
    required this.tracks,
    required this.selection,
    required this.player,
    this.onTrackChanged,
    required this.showHeader,
  });

  @override
  Widget build(BuildContext context) {
    final selectedId = selection.audio?.id ?? '';
    final found = tracks.indexWhere((t) => t.id == selectedId);
    final initialIndex = tracks.isEmpty ? 0 : (found < 0 ? 0 : found);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader) _ColumnHeader(label: t.videoControls.audioLabel),
        Expanded(
          child: tracks.isEmpty
              ? Center(
                  child: Text(
                    TrackSelectionHelper.getEmptyMessage<AudioTrack>(),
                    style: const TextStyle(color: Colors.white70),
                  ),
                )
              : ScrollToIndexListView(
                  itemCount: tracks.length,
                  initialIndex: initialIndex,
                  itemBuilder: (context, index) {
                    final track = tracks[index];
                    final label = TrackLabelBuilder.buildAudioLabel(
                      title: track.title,
                      language: track.language,
                      codec: track.codec,
                      channelsCount: track.channelsCount,
                      index: index,
                    );
                    return TrackSelectionHelper.buildTrackTile<AudioTrack>(
                      label: label,
                      isSelected: track.id == selectedId,
                      onTap: () {
                        player.selectAudioTrack(track);
                        onTrackChanged?.call(track);
                        OverlaySheetController.of(context).close();
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SubtitleTrackColumn extends StatelessWidget {
  final List<SubtitleTrack> embeddedTracks;
  final List<SubtitleTrack> extraTracks;
  final TrackSelection selection;
  final Player player;
  final Function(SubtitleTrack)? onTrackChanged;
  final Future<void> Function(SubtitleTrack)? onExternalSubtitleSelected;
  final bool showHeader;

  const _SubtitleTrackColumn({
    required this.embeddedTracks,
    required this.extraTracks,
    required this.selection,
    required this.player,
    this.onTrackChanged,
    this.onExternalSubtitleSelected,
    required this.showHeader,
  });

  static bool _isOff(SubtitleTrack? t) => t == null || t.id == 'no';

  static int _initialSubtitleIndex({
    required SubtitleTrack? selectedSub,
    required List<SubtitleTrack> embedded,
    required List<SubtitleTrack> extras,
  }) {
    if (_isOff(selectedSub)) return 0;
    final selectedId = TrackSelectionHelper.getTrackId(selectedSub!);
    final inEmb = embedded.indexWhere((t) => TrackSelectionHelper.getTrackId(t) == selectedId);
    if (inEmb >= 0) return inEmb + 1;
    final selectedUri = selectedSub.uri;
    if (selectedUri != null) {
      for (var i = 0; i < extras.length; i++) {
        if (extras[i].uri == selectedUri) return 1 + embedded.length + i;
      }
    }
    final inExtra = extras.indexWhere((t) => TrackSelectionHelper.getTrackId(t) == selectedId);
    if (inExtra >= 0) return 1 + embedded.length + inExtra;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final selectedSub = selection.subtitle;
    final isOffSelected = _isOff(selectedSub);
    final itemCount = 1 + embeddedTracks.length + extraTracks.length;

    final initialIndex = _initialSubtitleIndex(
      selectedSub: selectedSub,
      embedded: embeddedTracks,
      extras: extraTracks,
    ).clamp(0, itemCount - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader) _ColumnHeader(label: t.videoControls.subtitlesLabel),
        Expanded(
          child: ScrollToIndexListView(
            itemCount: itemCount,
            initialIndex: initialIndex,
            itemBuilder: (context, index) {
              if (index == 0) {
                return TrackSelectionHelper.buildOffTile<SubtitleTrack>(
                  isSelected: isOffSelected,
                  onTap: () {
                    player.selectSubtitleTrack(SubtitleTrack.off);
                    onTrackChanged?.call(SubtitleTrack.off);
                    OverlaySheetController.of(context).close();
                  },
                );
              }

              final trackIndex = index - 1;
              if (trackIndex < embeddedTracks.length) {
                final track = embeddedTracks[trackIndex];
                final trackId = TrackSelectionHelper.getTrackId(track);
                final selectedId = selectedSub == null ? '' : TrackSelectionHelper.getTrackId(selectedSub);
                final label = TrackLabelBuilder.buildSubtitleLabel(
                  title: track.title,
                  language: track.language,
                  codec: track.codec,
                  index: trackIndex,
                );
                return TrackSelectionHelper.buildTrackTile<SubtitleTrack>(
                  label: label,
                  isSelected: trackId == selectedId,
                  onTap: () {
                    player.selectSubtitleTrack(track);
                    onTrackChanged?.call(track);
                    OverlaySheetController.of(context).close();
                  },
                );
              }

              final extraIndex = trackIndex - embeddedTracks.length;
              final extraTrack = extraTracks[extraIndex];
              final extraUri = extraTrack.uri;
              final selectedUri = selectedSub?.uri;
              final isExtraSelected =
                  extraUri != null && selectedUri != null && extraUri == selectedUri;
              final label = TrackLabelBuilder.buildSubtitleLabel(
                title: extraTrack.title,
                language: extraTrack.language,
                codec: extraTrack.codec,
                index: embeddedTracks.length + extraIndex,
              );
              return TrackSelectionHelper.buildTrackTile<SubtitleTrack>(
                label: label,
                isSelected: isExtraSelected,
                onTap: () {
                  onExternalSubtitleSelected?.call(extraTrack);
                  OverlaySheetController.of(context).close();
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
