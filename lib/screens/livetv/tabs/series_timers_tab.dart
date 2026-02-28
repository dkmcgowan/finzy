import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../focus/focusable_wrapper.dart';
import '../../../i18n/strings.g.dart';
import '../../../models/livetv_subscription.dart';
import '../../../providers/multi_server_provider.dart';
import '../../../utils/app_logger.dart';
import '../../../utils/snackbar_helper.dart';
import '../../../widgets/app_icon.dart';

class SeriesTimersTab extends StatefulWidget {
  final VoidCallback? onNavigateUp;
  final VoidCallback? onBack;

  const SeriesTimersTab({super.key, this.onNavigateUp, this.onBack});

  @override
  State<SeriesTimersTab> createState() => SeriesTimersTabState();
}

class SeriesTimersTabState extends State<SeriesTimersTab> {
  List<LiveTvSubscription> _seriesTimers = [];
  bool _isLoading = true;
  String? _error;
  final _firstItemFocusNode = FocusNode(debugLabel: 'series_timer_first_item');

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
    if (_seriesTimers.isNotEmpty) {
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

      final allSeriesTimers = <LiveTvSubscription>[];

      for (final serverInfo in liveTvServers) {
        final client = multiServer.getClientForServer(serverInfo.serverId);
        if (client == null) continue;

        final series = await client.getSeriesTimers();
        allSeriesTimers.addAll(series);
      }

      if (!mounted) return;
      setState(() {
        _seriesTimers = allSeriesTimers;
        _isLoading = false;
      });
    } catch (e) {
      appLogger.e('Failed to load series timers', error: e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _deleteSeriesTimer(LiveTvSubscription seriesTimer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.liveTv.deleteSeriesTimer),
        content: Text(t.liveTv.deleteSeriesTimerConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(t.common.cancel)),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(t.common.delete)),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final multiServer = context.read<MultiServerProvider>();
    final client = seriesTimer.serverId != null ? multiServer.getClientForServer(seriesTimer.serverId!) : null;

    if (client != null) {
      final success = await client.deleteSeriesTimer(seriesTimer.key);
      if (success && mounted) {
        showSnackBar(context, t.liveTv.seriesTimerDeleted);
        await _loadData();
      }
    }
  }

  Future<void> _editSeriesTimer(LiveTvSubscription seriesTimer) async {
    final result = await showDialog<LiveTvSubscription?>(
      context: context,
      builder: (ctx) => _SeriesTimerEditDialog(seriesTimer: seriesTimer),
    );

    if (result == null || !mounted) return;

    final multiServer = context.read<MultiServerProvider>();
    final client = seriesTimer.serverId != null ? multiServer.getClientForServer(seriesTimer.serverId!) : null;

    if (client != null) {
      final success = await client.updateSeriesTimer(result);
      if (success && mounted) {
        showSnackBar(context, t.liveTv.seriesTimerUpdated);
        await _loadData();
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
    if (_seriesTimers.isEmpty) {
      return Center(child: Text(t.liveTv.noSubscriptions));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _seriesTimers.length,
      itemBuilder: (context, index) {
        final sub = _seriesTimers[index];
        return FocusableWrapper(
          focusNode: index == 0 ? _firstItemFocusNode : null,
          autofocus: index == 0,
          autoScroll: true,
          useComfortableZone: true,
          onSelect: () => _editSeriesTimer(sub),
          onNavigateUp: index == 0 ? widget.onNavigateUp : null,
          onBack: widget.onBack,
          child: _buildSeriesTimerCard(sub, theme),
        );
      },
    );
  }

  Widget _buildSeriesTimerCard(LiveTvSubscription seriesTimer, ThemeData theme) {
    final subtitleParts = <String>[];
    if (seriesTimer.channelName != null) subtitleParts.add(seriesTimer.channelName!);
    if (seriesTimer.recordNewOnly) subtitleParts.add('New only');
    if (seriesTimer.days.isNotEmpty) subtitleParts.add(seriesTimer.days.join(', '));

    return ExcludeFocus(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: ListTile(
          leading: const AppIcon(Symbols.fiber_dvr_rounded, size: 32),
          title: Text(seriesTimer.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: subtitleParts.isNotEmpty
              ? Text(
                  subtitleParts.join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                )
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const AppIcon(Symbols.edit_rounded),
                onPressed: () => _editSeriesTimer(seriesTimer),
              ),
              IconButton(
                icon: AppIcon(Symbols.delete_rounded, color: theme.colorScheme.error),
                onPressed: () => _deleteSeriesTimer(seriesTimer),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Series Timer Edit Dialog
// ---------------------------------------------------------------------------

class _SeriesTimerEditDialog extends StatefulWidget {
  final LiveTvSubscription seriesTimer;

  const _SeriesTimerEditDialog({required this.seriesTimer});

  @override
  State<_SeriesTimerEditDialog> createState() => _SeriesTimerEditDialogState();
}

class _SeriesTimerEditDialogState extends State<_SeriesTimerEditDialog> {
  late bool _recordNewOnly;
  late int _keepUpTo;
  late int _prePaddingSeconds;
  late int _postPaddingSeconds;
  late List<String> _days;
  late int _priority;

  static const _allDays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  static const _paddingOptions = [0, 60, 120, 180, 300, 600, 900];
  static const _keepUpToOptions = [0, 1, 2, 3, 5, 10, 20, 50];

  @override
  void initState() {
    super.initState();
    final st = widget.seriesTimer;
    _recordNewOnly = st.recordNewOnly;
    _keepUpTo = st.keepUpTo;
    _prePaddingSeconds = st.prePaddingSeconds;
    _postPaddingSeconds = st.postPaddingSeconds;
    _days = List.from(st.days);
    _priority = st.priority;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.seriesTimer.title),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: Text(t.liveTv.recordNewOnly),
                value: _recordNewOnly,
                onChanged: (v) => setState(() => _recordNewOnly = v),
              ),
              const Divider(),
              ListTile(
                title: Text(t.liveTv.keepUpTo),
                trailing: DropdownButton<int>(
                  value: _keepUpToOptions.contains(_keepUpTo) ? _keepUpTo : 0,
                  items: _keepUpToOptions.map((v) {
                    final label = v == 0 ? t.liveTv.keepAll : t.liveTv.keepEpisodes(count: v.toString());
                    return DropdownMenuItem(value: v, child: Text(label));
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _keepUpTo = v);
                  },
                ),
              ),
              ListTile(
                title: Text(t.liveTv.prePadding),
                trailing: DropdownButton<int>(
                  value: _paddingOptions.contains(_prePaddingSeconds) ? _prePaddingSeconds : 0,
                  items: _paddingOptions.map((v) {
                    final label = v == 0 ? t.common.none : t.liveTv.minutes(count: (v ~/ 60).toString());
                    return DropdownMenuItem(value: v, child: Text(label));
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _prePaddingSeconds = v);
                  },
                ),
              ),
              ListTile(
                title: Text(t.liveTv.postPadding),
                trailing: DropdownButton<int>(
                  value: _paddingOptions.contains(_postPaddingSeconds) ? _postPaddingSeconds : 0,
                  items: _paddingOptions.map((v) {
                    final label = v == 0 ? t.common.none : t.liveTv.minutes(count: (v ~/ 60).toString());
                    return DropdownMenuItem(value: v, child: Text(label));
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _postPaddingSeconds = v);
                  },
                ),
              ),
              ListTile(
                title: Text(t.liveTv.priority),
                trailing: DropdownButton<int>(
                  value: _priority,
                  items: List.generate(6, (i) {
                    return DropdownMenuItem(value: i, child: Text('$i'));
                  }),
                  onChanged: (v) {
                    if (v != null) setState(() => _priority = v);
                  },
                ),
              ),
              const Divider(),
              ListTile(title: Text(t.liveTv.days)),
              Wrap(
                spacing: 8,
                children: _allDays.map((day) {
                  final selected = _days.contains(day);
                  return FilterChip(
                    label: Text(day.substring(0, 3)),
                    selected: selected,
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _days.add(day);
                        } else {
                          _days.remove(day);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(null), child: Text(t.common.cancel)),
        FilledButton(
          onPressed: () {
            final updated = widget.seriesTimer.copyWith(
              recordNewOnly: _recordNewOnly,
              keepUpTo: _keepUpTo,
              prePaddingSeconds: _prePaddingSeconds,
              postPaddingSeconds: _postPaddingSeconds,
              days: _days,
              priority: _priority,
            );
            Navigator.of(context).pop(updated);
          },
          child: Text(t.common.save),
        ),
      ],
    );
  }
}
