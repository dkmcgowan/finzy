import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../i18n/strings.g.dart';
import '../../../models/hub.dart';
import '../../../models/media_metadata.dart';
import '../../../providers/multi_server_provider.dart';
import '../../../utils/app_logger.dart';
import '../../../widgets/hub_section.dart';

class RecordingsTab extends StatefulWidget {
  final VoidCallback? onNavigateUp;
  final VoidCallback? onBack;

  const RecordingsTab({super.key, this.onNavigateUp, this.onBack});

  @override
  State<RecordingsTab> createState() => RecordingsTabState();
}

class RecordingsTabState extends State<RecordingsTab> {
  List<MediaMetadata> _recordings = [];
  bool _isLoading = true;
  final _hubKey = GlobalKey<HubSectionState>();

  @override
  void initState() {
    super.initState();
    _loadRecordings();
  }

  void focusContent() {
    _hubKey.currentState?.requestFocusFromMemory();
  }

  Future<void> _loadRecordings() async {
    if (!mounted) return;
    setState(() => _isLoading = _recordings.isEmpty);

    try {
      final multiServer = context.read<MultiServerProvider>();
      final liveTvServers = multiServer.liveTvServers;
      final allRecordings = <MediaMetadata>[];
      final queriedServers = <String>{};

      for (final serverInfo in liveTvServers) {
        if (!queriedServers.add(serverInfo.serverId)) continue;
        try {
          final client = multiServer.getClientForServer(serverInfo.serverId);
          if (client == null) continue;
          final recordings = await client.getRecordingsAsMetadata();
          allRecordings.addAll(recordings);
        } catch (e) {
          appLogger.e('Failed to load recordings from server ${serverInfo.serverId}', error: e);
        }
      }

      if (!mounted) return;
      setState(() {
        _recordings = allRecordings;
        _isLoading = false;
      });
    } catch (e) {
      appLogger.e('Failed to load recordings', error: e);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onItemRefresh(String itemId) async {
    await _loadRecordings();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_recordings.isEmpty) {
      return Center(child: Text(t.liveTv.noRecordings));
    }

    final hub = Hub(
      hubKey: 'livetv_recordings',
      title: t.liveTv.recentlyAdded,
      type: 'mixed',
      hubIdentifier: '_livetv_recordings_',
      size: _recordings.length,
      more: false,
      items: _recordings,
    );

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        HubSection(
          key: _hubKey,
          hub: hub,
          icon: Symbols.video_library_rounded,
          onRefresh: _onItemRefresh,
          onVerticalNavigation: (isUp) {
            if (isUp) {
              widget.onNavigateUp?.call();
              return true;
            }
            return true;
          },
          onNavigateUp: widget.onNavigateUp,
          onBack: widget.onBack,
        ),
      ],
    );
  }
}
