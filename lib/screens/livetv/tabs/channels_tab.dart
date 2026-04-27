import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../focus/focusable_wrapper.dart';
import '../../../i18n/strings.g.dart';
import '../../../models/livetv_channel.dart';
import '../../../providers/multi_server_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/settings_service.dart' show LibraryDensity;
import '../../../theme/mono_tokens.dart';
import '../../../utils/layout_constants.dart';
import '../../../utils/live_tv_player_navigation.dart';
import '../../../utils/provider_extensions.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/optimized_image.dart';

class ChannelsTab extends StatefulWidget {
  final List<LiveTvChannel> channels;
  final VoidCallback? onNavigateUp;
  final VoidCallback? onNavigateLeft;
  final VoidCallback? onBack;

  const ChannelsTab({super.key, required this.channels, this.onNavigateUp, this.onNavigateLeft, this.onBack});

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

    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            // Match Programs tab sizing and spacing
            final screenWidth = constraints.maxWidth;
            final densityScale = switch (settingsProvider.libraryDensity) {
              LibraryDensity.compact => 0.8,
              LibraryDensity.normal => 1.0,
              LibraryDensity.comfortable => 1.15,
            };
            final baseWidth = ScreenBreakpoints.isLargeDesktop(screenWidth)
                ? 220.0
                : ScreenBreakpoints.isDesktop(screenWidth)
                    ? 200.0
                    : ScreenBreakpoints.isWideTablet(screenWidth)
                        ? 190.0
                        : 160.0;
            final maxExtent = baseWidth * densityScale;
            const spacing = 4.0; // Match Programs horizontal padding between cards
            final availableWidth = constraints.maxWidth - 24;
            final columnCount = ((availableWidth + spacing) / (maxExtent + spacing)).ceil().clamp(1, 100);

            return GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: maxExtent,
                childAspectRatio: GridLayoutConstants.posterAspectRatio,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
              ),
              itemCount: widget.channels.length,
              itemBuilder: (context, index) {
                final channel = widget.channels[index];
                final isFirstColumn = index % columnCount == 0;
                return FocusableWrapper(
                  focusNode: index == 0 ? _firstItemFocusNode : null,
                  autofocus: index == 0,
                  autoScroll: true,
                  useComfortableZone: true,
                  onSelect: () => _tuneChannel(channel),
                  onNavigateUp: index < columnCount ? widget.onNavigateUp : null,
                  onNavigateLeft: isFirstColumn ? widget.onNavigateLeft : null,
                  onBack: widget.onBack,
                  child: _ChannelCard(channel: channel, onTap: () => _tuneChannel(channel)),
                );
              },
            );
          },
        );
      },
    );
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
                      widthFactor: 0.7,
                      heightFactor: 0.7,
                      child: OptimizedImage(
                        client: context.getClientWithFallback(widget.channel.serverId),
                        imagePath: widget.channel.thumb,
                        imageTag: widget.channel.thumbTag,
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
                        borderRadius: const BorderRadius.all(Radius.circular(4)),
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
