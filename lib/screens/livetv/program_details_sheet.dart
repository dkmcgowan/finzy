import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../i18n/strings.g.dart';
import '../../models/livetv_channel.dart';
import '../../models/livetv_program.dart';
import '../../providers/multi_server_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/jellyfin_client.dart';
import '../../utils/app_logger.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/overlay_sheet.dart';
import '../../widgets/optimized_image.dart' show blurArtwork;

/// Shows a bottom sheet with program details and actions (Record, Watch Channel, Play).
void showProgramDetailsSheet(
  BuildContext context, {
  required LiveTvProgram program,
  required LiveTvChannel? channel,
  required String? posterUrl,
  required VoidCallback? onTuneChannel,
}) {
  final controller = OverlaySheetController.maybeOf(context);
  if (controller != null) {
    controller.show(
      builder: (sheetContext) {
        return _ProgramDetailsSheetContent(
          program: program,
          channel: channel,
          posterUrl: posterUrl,
          onTuneChannel: onTuneChannel,
        );
      },
    );
  } else {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return _ProgramDetailsSheetContent(
          program: program,
          channel: channel,
          posterUrl: posterUrl,
          onTuneChannel: onTuneChannel,
        );
      },
    );
  }
}

class _ProgramDetailsSheetContent extends StatefulWidget {
  final LiveTvProgram program;
  final LiveTvChannel? channel;
  final String? posterUrl;
  final VoidCallback? onTuneChannel;

  const _ProgramDetailsSheetContent({
    required this.program,
    required this.channel,
    required this.posterUrl,
    required this.onTuneChannel,
  });

  @override
  State<_ProgramDetailsSheetContent> createState() => _ProgramDetailsSheetContentState();
}

class _ProgramDetailsSheetContentState extends State<_ProgramDetailsSheetContent> {
  // Recording state fetched from the full program details
  bool _loadingRecordingState = true;
  String? _timerId;
  String? _seriesTimerId;
  String? _timerStatus;
  bool _isSeries = false;
  bool _recordingBusy = false;

  JellyfinClient? _client;

  @override
  void initState() {
    super.initState();
    _fetchRecordingState();
  }

  Future<void> _fetchRecordingState() async {
    final programId = widget.program.itemId ?? widget.program.key;
    if (programId == null) {
      if (mounted) setState(() => _loadingRecordingState = false);
      return;
    }

    try {
      final multiServer = context.read<MultiServerProvider>();
      final serverId = widget.channel?.serverId;
      final client = serverId != null
          ? multiServer.getClientForServer(serverId)
          : multiServer.liveTvServers.isNotEmpty
              ? multiServer.getClientForServer(multiServer.liveTvServers.first.serverId)
              : null;

      if (client == null) {
        if (mounted) setState(() => _loadingRecordingState = false);
        return;
      }

      _client = client;
      final details = await client.getProgramDetails(programId);

      if (!mounted) return;
      setState(() {
        _timerId = details?['TimerId'] as String?;
        _seriesTimerId = details?['SeriesTimerId'] as String?;
        _timerStatus = details?['Status'] as String?;
        _isSeries = details?['IsSeries'] == true;
        _loadingRecordingState = false;
      });
    } catch (e) {
      appLogger.e('Failed to fetch program recording state', error: e);
      if (mounted) setState(() => _loadingRecordingState = false);
    }
  }

  bool get _hasActiveTimer => _timerId != null && _timerStatus != 'Cancelled';
  bool get _hasSeriesTimer => _seriesTimerId != null;

  Future<void> _handleRecord() async {
    final programId = widget.program.itemId ?? widget.program.key;
    if (programId == null || _client == null) return;

    setState(() => _recordingBusy = true);

    try {
      if (_hasActiveTimer) {
        final success = await _client!.cancelTimer(_timerId!);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.liveTv.timerCancelled)),
          );
        }
      } else {
        final defaults = await _client!.getTimerDefaults(programId);
        if (defaults == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(t.liveTv.recordingFailed)),
            );
          }
          setState(() => _recordingBusy = false);
          return;
        }
        final success = await _client!.createTimer(defaults);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(success ? t.liveTv.recordingScheduled : t.liveTv.recordingFailed)),
          );
        }
      }
    } catch (e) {
      appLogger.e('Failed to toggle recording', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.liveTv.recordingFailed)),
        );
      }
    }

    setState(() => _recordingBusy = false);
    await _fetchRecordingState();
  }

  Future<void> _handleRecordSeries() async {
    final programId = widget.program.itemId ?? widget.program.key;
    if (programId == null || _client == null) return;

    setState(() => _recordingBusy = true);

    try {
      if (_hasSeriesTimer) {
        final success = await _client!.deleteSeriesTimer(_seriesTimerId!);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.liveTv.seriesTimerDeleted)),
          );
        }
      } else {
        final defaults = await _client!.getTimerDefaults(programId);
        if (defaults == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(t.liveTv.recordingFailed)),
            );
          }
          setState(() => _recordingBusy = false);
          return;
        }
        final success = await _client!.createSeriesTimer(defaults);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(success ? t.liveTv.seriesRecordingScheduled : t.liveTv.recordingFailed)),
          );
        }
      }
    } catch (e) {
      appLogger.e('Failed to toggle series recording', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.liveTv.recordingFailed)),
        );
      }
    }

    setState(() => _recordingBusy = false);
    await _fetchRecordingState();
  }

  void _closeSheet() {
    final controller = OverlaySheetController.maybeOf(context);
    if (controller != null) {
      controller.close();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final program = widget.program;
    final channel = widget.channel;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.posterUrl != null) ...[
                ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(6)),
                  child: blurArtwork(Image.network(
                    widget.posterUrl!,
                    width: 80,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  )),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(program.displayTitle, style: theme.textTheme.titleMedium)),
                        if (program.isCurrentlyAiring)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.all(Radius.circular(4)),
                            ),
                            child: Text(
                              t.liveTv.live,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (channel != null) channel.displayName,
                        if (program.startTime != null && program.endTime != null)
                          '${formatGuideTime(program.startTime!, use24Hour: context.read<SettingsProvider>().use24HourTime(context))} - ${formatGuideTime(program.endTime!, use24Hour: context.read<SettingsProvider>().use24HourTime(context))}',
                        if (program.durationMinutes > 0) formatDurationTextual(program.durationMinutes * 60000),
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    if (program.summary != null && program.summary!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        program.summary!,
                        style: theme.textTheme.bodyMedium,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildActionButtons(theme),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    final buttons = <Widget>[];

    // Play / Watch Channel button
    if (widget.onTuneChannel != null) {
      if (program.isCurrentlyAiring) {
        buttons.add(
          _actionButton(
            icon: Symbols.play_arrow_rounded,
            label: t.common.play,
            filled: true,
            onPressed: () {
              _closeSheet();
              widget.onTuneChannel!();
            },
          ),
        );
      } else {
        buttons.add(
          _actionButton(
            icon: Symbols.live_tv_rounded,
            label: t.liveTv.watchChannel,
            onPressed: () {
              _closeSheet();
              widget.onTuneChannel!();
            },
          ),
        );
      }
    }

    // Record button
    if (!_loadingRecordingState) {
      if (buttons.isNotEmpty) buttons.add(const SizedBox(width: 8));

      final String recordLabel;
      final Color? recordColor;
      if (_hasActiveTimer) {
        recordLabel = _timerStatus == 'InProgress' ? t.liveTv.stopRecording : t.liveTv.doNotRecord;
        recordColor = Colors.red;
      } else {
        recordLabel = t.liveTv.record;
        recordColor = null;
      }

      buttons.add(
        _actionButton(
          icon: Symbols.fiber_manual_record_rounded,
          label: recordLabel,
          iconColor: _hasActiveTimer ? Colors.red : recordColor,
          onPressed: _recordingBusy ? null : _handleRecord,
        ),
      );

      // Record Series button (only for series programs)
      if (_isSeries) {
        buttons.add(const SizedBox(width: 8));

        buttons.add(
          _actionButton(
            icon: Symbols.fiber_manual_record_rounded,
            label: _hasSeriesTimer ? t.liveTv.cancelSeries : t.liveTv.recordSeries,
            iconColor: _hasSeriesTimer ? Colors.red : null,
            onPressed: _recordingBusy ? null : _handleRecordSeries,
          ),
        );
      }
    } else {
      if (buttons.isNotEmpty) buttons.add(const SizedBox(width: 8));
      buttons.add(
        const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: buttons,
    );
  }

  LiveTvProgram get program => widget.program;

  Widget _actionButton({
    required IconData icon,
    required String label,
    bool filled = false,
    Color? iconColor,
    VoidCallback? onPressed,
  }) {
    if (filled) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        onPressed: onPressed,
        icon: AppIcon(icon),
        label: Text(label),
      );
    }
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      onPressed: onPressed,
      icon: AppIcon(icon, color: iconColor),
      label: Text(label),
    );
  }
}
