import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../focus/focusable_wrapper.dart';
import '../../../utils/platform_detector.dart';
import '../../../i18n/strings.g.dart';
import '../../../models/livetv_scheduled_recording.dart';
import '../../../providers/multi_server_provider.dart';
import '../../../utils/app_logger.dart';
import '../../../utils/formatters.dart';
import '../../../utils/snackbar_helper.dart';
import '../../../widgets/app_icon.dart';

class ScheduledTab extends StatefulWidget {
  final VoidCallback? onNavigateUp;
  final VoidCallback? onNavigateLeft;
  final VoidCallback? onBack;

  const ScheduledTab({super.key, this.onNavigateUp, this.onNavigateLeft, this.onBack});

  @override
  State<ScheduledTab> createState() => ScheduledTabState();
}

class ScheduledTabState extends State<ScheduledTab> {
  List<ScheduledRecording> _scheduled = [];
  bool _isLoading = true;
  String? _error;
  final _firstItemFocusNode = FocusNode(debugLabel: 'scheduled_first_item');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _firstItemFocusNode.dispose();
    super.dispose();
  }

  void focusContent() {
    if (_scheduled.isNotEmpty) {
      _firstItemFocusNode.requestFocus();
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final multiServer = context.read<MultiServerProvider>();
      final liveTvServers = multiServer.liveTvServers;

      if (liveTvServers.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = t.liveTv.noDvr;
        });
        return;
      }

      final allScheduled = <ScheduledRecording>[];

      for (final serverInfo in liveTvServers) {
        final client = multiServer.getClientForServer(serverInfo.serverId);
        if (client == null) continue;

        final timers = await client.getTimers();
        allScheduled.addAll(timers);
      }

      if (!mounted) return;
      setState(() {
        _scheduled = allScheduled;
        _isLoading = false;
      });
    } catch (e) {
      appLogger.e('Failed to load scheduled recordings', error: e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _cancelTimer(ScheduledRecording timer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.liveTv.cancelTimer),
        content: Text(t.liveTv.cancelTimerConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(t.common.cancel)),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(t.common.delete)),
        ],
      ),
    );

    if (confirmed != true || !mounted || timer.key == null) return;

    final multiServer = context.read<MultiServerProvider>();
    for (final serverInfo in multiServer.liveTvServers) {
      final client = multiServer.getClientForServer(serverInfo.serverId);
      if (client == null) continue;
      final success = await client.cancelTimer(timer.key!);
      if (success && mounted) {
        showSnackBar(context, t.liveTv.timerCancelled);
        await _loadData();
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const AppIcon(Symbols.refresh_rounded),
              label: Text(t.common.retry),
            ),
          ],
        ),
      );
    }
    if (_scheduled.isEmpty) {
      return Center(child: Text(t.liveTv.noScheduled));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _scheduled.length,
      itemBuilder: (context, index) {
        final timer = _scheduled[index];
        final isTV = PlatformDetector.isTV();
        return FocusableWrapper(
          focusNode: index == 0 ? _firstItemFocusNode : null,
          autofocus: index == 0,
          autoScroll: true,
          useComfortableZone: true,
          onSelect: timer.key != null ? () => _cancelTimer(timer) : null,
          enableLongPress: isTV && timer.key != null,
          onLongPress: isTV && timer.key != null ? () => _cancelTimer(timer) : null,
          onNavigateUp: index == 0 ? widget.onNavigateUp : null,
          onNavigateLeft: widget.onNavigateLeft,
          onBack: widget.onBack,
          child: _buildScheduledCard(timer, theme),
        );
      },
    );
  }

  Widget _buildScheduledCard(ScheduledRecording recording, ThemeData theme) {
    final subtitle = <String>[];
    if (recording.channelName != null) subtitle.add(recording.channelName!);
    if (recording.startTime != null) {
      subtitle.add(DateFormat.yMd().add_jm().format(recording.startTime!));
    }
    if (recording.durationMinutes > 0) {
      subtitle.add(formatDurationTextual(recording.durationMinutes * 60000));
    }

    return ExcludeFocus(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: ListTile(
          leading: const AppIcon(Symbols.fiber_manual_record_rounded, size: 32, color: Colors.red),
          title: Text(recording.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: subtitle.isNotEmpty
              ? Text(
                  subtitle.join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                )
              : null,
          trailing: recording.key != null && !PlatformDetector.isTV()
              ? IconButton(
                  icon: AppIcon(Symbols.cancel_rounded, color: theme.colorScheme.error),
                  tooltip: t.liveTv.cancelTimer,
                  onPressed: () => _cancelTimer(recording),
                )
              : null,
        ),
      ),
    );
  }
}
