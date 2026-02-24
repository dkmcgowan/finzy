import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../mpv/mpv.dart';
import '../../../i18n/strings.g.dart';
import '../../../utils/track_label_builder.dart';
import 'track_selection_sheet.dart';

/// Bottom sheet for selecting subtitle tracks
class SubtitleTrackSheet extends StatelessWidget {
  final Player player;
  final Function(SubtitleTrack)? onTrackChanged;

  /// External subtitle tracks (shown when setting is on; load on demand when selected)
  final List<SubtitleTrack> availableExternalSubtitles;

  /// Called when user selects an external subtitle track
  final Future<void> Function(SubtitleTrack)? onExternalSubtitleSelected;

  const SubtitleTrackSheet({
    super.key,
    required this.player,
    this.onTrackChanged,
    this.availableExternalSubtitles = const [],
    this.onExternalSubtitleSelected,
  });

  @override
  Widget build(BuildContext context) {
    return TrackSelectionSheet<SubtitleTrack>(
      player: player,
      title: t.videoControls.subtitlesLabel,
      icon: Symbols.subtitles_rounded,
      extractTracks: (tracks) => tracks?.subtitle ?? [],
      getCurrentTrack: (track) => track.subtitle,
      buildLabel: (subtitle, index) => TrackLabelBuilder.buildSubtitleLabel(
        title: subtitle.title,
        language: subtitle.language,
        codec: subtitle.codec,
        index: index,
      ),
      setTrack: (track) => player.selectSubtitleTrack(track),
      onTrackChanged: onTrackChanged,
      showOffOption: true,
      createOffTrack: () => SubtitleTrack.off,
      isOffTrack: (track) => track.id == 'no',
      extraTracks: availableExternalSubtitles.isEmpty ? null : availableExternalSubtitles,
      onExtraTrackSelected: onExternalSubtitleSelected == null
          ? null
          : (track) {
              onExternalSubtitleSelected!(track);
            },
    );
  }
}
