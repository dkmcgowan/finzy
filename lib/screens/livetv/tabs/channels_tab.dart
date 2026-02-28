import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../focus/focusable_wrapper.dart';
import '../../../i18n/strings.g.dart';
import '../../../models/livetv_channel.dart';
import '../../../providers/multi_server_provider.dart';
import '../../../theme/mono_tokens.dart';
import '../../../utils/live_tv_player_navigation.dart';
import '../../../utils/provider_extensions.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/optimized_image.dart';

class ChannelsTab extends StatefulWidget {
  final List<LiveTvChannel> channels;
  final VoidCallback? onNavigateUp;
  final VoidCallback? onBack;

  const ChannelsTab({super.key, required this.channels, this.onNavigateUp, this.onBack});

  @override
  State<ChannelsTab> createState() => ChannelsTabState();
}

class ChannelsTabState extends State<ChannelsTab> {
  final _firstItemFocusNode = FocusNode(debugLabel: 'channel_first_item');

  @override
  void dispose() {
    _firstItemFocusNode.dispose();
    super.dispose();
  }

  void focusContent() {
    if (widget.channels.isNotEmpty) {
      _firstItemFocusNode.requestFocus();
    }
  }

  Future<void> _tuneChannel(LiveTvChannel channel) async {
    final multiServer = context.read<MultiServerProvider>();
    final serverInfo =
        multiServer.liveTvServers.where((s) => s.serverId == channel.serverId).firstOrNull ??
        multiServer.liveTvServers.firstOrNull;
    if (serverInfo == null) return;

    final client = multiServer.getClientForServer(serverInfo.serverId);
    if (client == null) return;

    await navigateToLiveTv(
      context,
      client: client,
      dvrKey: serverInfo.dvrKey,
      channel: channel,
      channels: widget.channels,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.channels.isEmpty) {
      return Center(child: Text(t.liveTv.noChannels));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _crossAxisCount(constraints.maxWidth);

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.0,
          ),
          itemCount: widget.channels.length,
          itemBuilder: (context, index) {
            final channel = widget.channels[index];
            return FocusableWrapper(
              focusNode: index == 0 ? _firstItemFocusNode : null,
              autofocus: index == 0,
              autoScroll: true,
              useComfortableZone: true,
              onSelect: () => _tuneChannel(channel),
              onNavigateUp: index < crossAxisCount ? widget.onNavigateUp : null,
              onBack: widget.onBack,
              child: _ChannelCard(channel: channel, onTap: () => _tuneChannel(channel)),
            );
          },
        );
      },
    );
  }

  int _crossAxisCount(double width) {
    if (width >= 1400) return 8;
    if (width >= 1100) return 7;
    if (width >= 900) return 6;
    if (width >= 700) return 5;
    if (width >= 500) return 4;
    return 3;
  }
}

class _ChannelCard extends StatefulWidget {
  final LiveTvChannel channel;
  final VoidCallback? onTap;

  const _ChannelCard({required this.channel, this.onTap});

  @override
  State<_ChannelCard> createState() => _ChannelCardState();
}

class _ChannelCardState extends State<_ChannelCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ExcludeFocus(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (widget.channel.thumb != null)
                  Center(
                    child: FractionallySizedBox(
                      widthFactor: 0.70,
                      heightFactor: 0.70,
                      child: OptimizedImage(
                        client: context.getClientWithFallback(widget.channel.serverId),
                        imagePath: widget.channel.thumb,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
                  )
                else
                  Center(
                    child: AppIcon(
                      Symbols.live_tv_rounded,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  ),
                if (_isHovered)
                  Center(
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Symbols.play_arrow_rounded,
                        color: Colors.white,
                        size: 32,
                        fill: 1,
                      ),
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.8),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.channel.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        if (widget.channel.number != null)
                          Text(
                            t.liveTv.channelNumber(number: widget.channel.number!),
                            maxLines: 1,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (widget.channel.hd)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: tokens(context).surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        t.liveTv.hd,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
