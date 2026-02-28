import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../focus/dpad_navigator.dart';
import '../../i18n/strings.g.dart';
import '../../models/livetv_channel.dart';
import '../../models/livetv_dvr.dart';
import '../../mixins/refreshable.dart';
import '../../mixins/tab_navigation_mixin.dart';
import '../../providers/hidden_libraries_provider.dart';
import '../../providers/multi_server_provider.dart';
import '../../providers/playback_state_provider.dart';
import '../../providers/server_state_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../utils/app_logger.dart';
import '../../utils/dialogs.dart';
import '../../utils/platform_detector.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/focusable_tab_chip.dart';
import '../../widgets/profile_app_bar_button.dart';
import '../auth_screen.dart';
import '../profile/jellyfin_profile_switch_screen.dart';
import 'tabs/channels_tab.dart';
import 'tabs/guide_tab.dart';
import 'tabs/programs_tab.dart';
import 'tabs/recordings_tab.dart';
import 'tabs/scheduled_tab.dart';
import 'tabs/series_timers_tab.dart';

class LiveTvScreen extends StatefulWidget {
  const LiveTvScreen({super.key});

  @override
  State<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends State<LiveTvScreen>
    with TickerProviderStateMixin, TabNavigationMixin
    implements FocusableTab {
  final _programsTabFocusNode = FocusNode(debugLabel: 'tab_chip_programs');
  final _guideTabFocusNode = FocusNode(debugLabel: 'tab_chip_guide');
  final _channelsTabFocusNode = FocusNode(debugLabel: 'tab_chip_channels');
  final _recordingsTabFocusNode = FocusNode(debugLabel: 'tab_chip_recordings');
  final _scheduledTabFocusNode = FocusNode(debugLabel: 'tab_chip_scheduled');
  final _seriesTabFocusNode = FocusNode(debugLabel: 'tab_chip_series');
  final _programsTabKey = GlobalKey<ProgramsTabState>();
  final _guideTabKey = GlobalKey<GuideTabState>();
  final _channelsTabKey = GlobalKey<ChannelsTabState>();
  final _recordingsTabKey = GlobalKey<RecordingsTabState>();
  final _scheduledTabKey = GlobalKey<ScheduledTabState>();
  final _seriesTimersTabKey = GlobalKey<SeriesTimersTabState>();

  // App bar action button focus
  final _refreshButtonFocusNode = FocusNode(debugLabel: 'RefreshButton');
  bool _isRefreshFocused = false;

  List<LiveTvChannel> _channels = [];
  bool _isLoading = true;
  String? _error;

  @override
  List<FocusNode> get tabChipFocusNodes => [
        _programsTabFocusNode,
        _guideTabFocusNode,
        _channelsTabFocusNode,
        _recordingsTabFocusNode,
        _scheduledTabFocusNode,
        _seriesTabFocusNode,
      ];

  @override
  void initState() {
    super.initState();
    suppressAutoFocus = true;
    initTabNavigation();
    _refreshButtonFocusNode.addListener(_onRefreshFocusChange);
    _loadChannels();
  }

  @override
  void dispose() {
    _programsTabFocusNode.dispose();
    _guideTabFocusNode.dispose();
    _channelsTabFocusNode.dispose();
    _recordingsTabFocusNode.dispose();
    _scheduledTabFocusNode.dispose();
    _seriesTabFocusNode.dispose();
    _refreshButtonFocusNode.removeListener(_onRefreshFocusChange);
    _refreshButtonFocusNode.dispose();
    disposeTabNavigation();
    super.dispose();
  }

  void _onRefreshFocusChange() {
    if (mounted) setState(() => _isRefreshFocused = _refreshButtonFocusNode.hasFocus);
  }

  @override
  void onTabChanged() {
    if (!tabController.indexIsChanging) {
      super.onTabChanged();
      final idx = tabController.index;
      if (idx == 0) {
        _guideTabKey.currentState?.pauseRefresh();
        _programsTabKey.currentState?.resumeRefresh();
      } else if (idx == 1) {
        _programsTabKey.currentState?.pauseRefresh();
        _guideTabKey.currentState?.resumeRefresh();
      } else {
        _programsTabKey.currentState?.pauseRefresh();
        _guideTabKey.currentState?.pauseRefresh();
      }
    }
  }

  /// Extracts enabled channel keys from DVR mappings, returning null if no DVR has mapping data.
  Set<String>? _extractEnabledChannelKeys(List<LiveTvDvr> dvrs) {
    final enabledKeys = <String>{};
    bool hasMappings = false;
    for (final dvr in dvrs) {
      if (dvr.channelMappings.isEmpty) continue;
      hasMappings = true;
      for (final m in dvr.channelMappings) {
        if (m.enabled == true && m.channelKey != null) {
          enabledKeys.add(m.channelKey!);
        }
      }
    }
    return hasMappings ? enabledKeys : null;
  }

  Future<void> _loadChannels() async {
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

      final allChannels = <LiveTvChannel>[];
      final seenChannels = <String>{};

      appLogger.d(
        'Live TV DVRs: ${liveTvServers.map((s) => '${s.serverId}/${s.dvrKey} lineup=${s.lineup}').join(', ')}',
      );

      // Build a set of enabled channel keys per server from DVR mappings
      final enabledKeysByServer = <String, Set<String>>{};
      final queriedServers = <String>{};
      for (final serverInfo in liveTvServers) {
        if (!queriedServers.add(serverInfo.serverId)) continue;
        try {
          final client = multiServer.getClientForServer(serverInfo.serverId);
          if (client == null) continue;
          final dvrs = await client.getDvrs();
          final enabledKeys = _extractEnabledChannelKeys(dvrs);
          if (enabledKeys != null) {
            enabledKeysByServer[serverInfo.serverId] = enabledKeys;
          }
        } catch (e) {
          appLogger.e('Failed to load DVR mappings for server ${serverInfo.serverId}', error: e);
        }
      }

      for (final serverInfo in liveTvServers) {
        try {
          final client = multiServer.getClientForServer(serverInfo.serverId);
          if (client == null) continue;

          final channels = await client.getEpgChannels(lineup: serverInfo.lineup);
          final enabledKeys = enabledKeysByServer[serverInfo.serverId];
          appLogger.d(
            'Channels from DVR ${serverInfo.dvrKey}: ${channels.length} channels (${enabledKeys?.length ?? 'all'} enabled)',
          );
          for (final channel in channels) {
            // Skip disabled channels if DVR has mapping data
            if (enabledKeys != null && !enabledKeys.contains(channel.key)) continue;
            final dedupKey = '${serverInfo.serverId}:${channel.key}';
            if (seenChannels.add(dedupKey)) {
              allChannels.add(channel);
            }
          }
        } catch (e) {
          appLogger.e('Failed to load channels from server ${serverInfo.serverId}', error: e);
        }
      }

      allChannels.sort((a, b) {
        final aNum = double.tryParse(a.number ?? '') ?? 999999;
        final bNum = double.tryParse(b.number ?? '') ?? 999999;
        return aNum.compareTo(bNum);
      });

      if (!mounted) return;

      appLogger.d('Live TV: loaded ${allChannels.length} channels');

      setState(() {
        _channels = allChannels;
        _isLoading = false;
      });

      if (allChannels.isNotEmpty && PlatformDetector.shouldUseSideNavigation(context)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focusCurrentTab();
        });
      }
    } catch (e) {
      appLogger.e('Failed to load Live TV channels', error: e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _focusCurrentTab() {
    switch (tabController.index) {
      case 0:
        _programsTabKey.currentState?.focusFirstHub();
      case 1:
        _guideTabKey.currentState?.focusContent();
      case 2:
        _channelsTabKey.currentState?.focusContent();
      case 3:
        _recordingsTabKey.currentState?.focusContent();
      case 4:
        _scheduledTabKey.currentState?.focusContent();
      case 5:
        _seriesTimersTabKey.currentState?.focusContent();
    }
    setState(() {
      suppressAutoFocus = false;
    });
  }

  @override
  void focusActiveTabIfReady() => _focusCurrentTab();

  void _handleSwitchProfile(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const JellyfinProfileSwitchScreen()));
  }

  Future<void> _handleLogout() async {
    final confirm = await showConfirmDialog(
      context,
      title: t.common.logout,
      message: t.messages.logoutConfirm,
      confirmText: t.common.logout,
      isDestructive: true,
    );
    if (confirm && mounted) {
      final userProfileProvider = context.read<UserProfileProvider>();
      final multiServerProvider = context.read<MultiServerProvider>();
      final serverStateProvider = context.read<ServerStateProvider>();
      final hiddenLibrariesProvider = context.read<HiddenLibrariesProvider>();
      final playbackStateProvider = context.read<PlaybackStateProvider>();
      await userProfileProvider.logout();
      multiServerProvider.clearAllConnections();
      serverStateProvider.reset();
      await hiddenLibrariesProvider.refresh();
      playbackStateProvider.clearShuffle();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (route) => false,
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Action button key handlers
  // ---------------------------------------------------------------------------

  KeyEventResult _handleRefreshKeyEvent(FocusNode _, KeyEvent event) {
    if (!event.isActionable) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key.isLeftKey) {
      getTabChipFocusNode(tabCount - 1).requestFocus();
      return KeyEventResult.handled;
    }
    if (key.isRightKey || key.isUpKey) {
      return KeyEventResult.handled;
    }
    if (key.isDownKey) {
      _focusCurrentTab();
      return KeyEventResult.handled;
    }
    if (key.isSelectKey) {
      _loadChannels();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---------------------------------------------------------------------------
  // Tab chips
  // ---------------------------------------------------------------------------

  Widget _buildTabChip(String label, int index) {
    final isSelected = tabController.index == index;

    return FocusableTabChip(
      label: label,
      isSelected: isSelected,
      focusNode: getTabChipFocusNode(index),
      onSelect: () {
        if (isSelected) {
          _focusCurrentTab();
        } else {
          setState(() {
            tabController.index = index;
          });
        }
      },
      onNavigateLeft: index > 0
          ? () {
              final newIndex = index - 1;
              setState(() {
                suppressAutoFocus = true;
                tabController.index = newIndex;
              });
              getTabChipFocusNode(newIndex).requestFocus();
            }
          : onTabBarBack,
      onNavigateRight: index < tabCount - 1
          ? () {
              final newIndex = index + 1;
              setState(() {
                suppressAutoFocus = true;
                tabController.index = newIndex;
              });
              getTabChipFocusNode(newIndex).requestFocus();
            }
          : () => _refreshButtonFocusNode.requestFocus(),
      onNavigateDown: _focusCurrentTab,
      onBack: onTabBarBack,
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final useSideNav = PlatformDetector.shouldUseSideNavigation(context);
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: statusBarHeight + 72,
        title: null,
        leading: null,
        leadingWidth: 0,
        automaticallyImplyLeading: false,
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: Padding(
          padding: EdgeInsets.only(
            top: statusBarHeight,
            left: 16,
            right: 16,
            bottom: 8,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: useSideNav
                      ? SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildTabChip(t.liveTv.programs, 0),
                              const SizedBox(width: 8),
                              _buildTabChip(t.liveTv.guide, 1),
                              const SizedBox(width: 8),
                              _buildTabChip(t.liveTv.channels, 2),
                              const SizedBox(width: 8),
                              _buildTabChip(t.liveTv.recordings, 3),
                              const SizedBox(width: 8),
                              _buildTabChip(t.liveTv.scheduled, 4),
                              const SizedBox(width: 8),
                              _buildTabChip(t.liveTv.seriesTimers, 5),
                            ],
                          ),
                        )
                      : Text(t.liveTv.title, style: theme.textTheme.titleLarge),
                ),
                Focus(
                  focusNode: _refreshButtonFocusNode,
                  onKeyEvent: _handleRefreshKeyEvent,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _isRefreshFocused ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
                      borderRadius: const BorderRadius.all(Radius.circular(20)),
                    ),
                    child: IconButton(
                      icon: const AppIcon(Symbols.refresh_rounded, fill: 1),
                      tooltip: t.liveTv.reloadGuide,
                      onPressed: _loadChannels,
                    ),
                  ),
                ),
                ProfileAppBarButton(
                  onSwitchProfile: () => _handleSwitchProfile(context),
                  onLogout: _handleLogout,
                ),
              ],
            ),
          ),
        ),
      ),
      body: _buildLiveTvBody(theme, useSideNav),
    );
  }

  Widget _buildLiveTvBody(ThemeData theme, bool useSideNav) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(Symbols.error_rounded, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(_error!, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadChannels,
              icon: const AppIcon(Symbols.refresh_rounded),
              label: Text(t.common.retry),
            ),
          ],
        ),
      );
    }
    if (_channels.isEmpty) {
      return Center(child: Text(t.liveTv.noChannels));
    }
    return Column(
      children: [
        if (!useSideNav)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTabChip(t.liveTv.programs, 0),
                  const SizedBox(width: 8),
                  _buildTabChip(t.liveTv.guide, 1),
                  const SizedBox(width: 8),
                  _buildTabChip(t.liveTv.channels, 2),
                  const SizedBox(width: 8),
                  _buildTabChip(t.liveTv.recordings, 3),
                  const SizedBox(width: 8),
                  _buildTabChip(t.liveTv.scheduled, 4),
                  const SizedBox(width: 8),
                  _buildTabChip(t.liveTv.seriesTimers, 5),
                ],
              ),
            ),
          ),
        Expanded(
          child: TabBarView(
            controller: tabController,
            children: [
              ProgramsTab(key: _programsTabKey, channels: _channels, onNavigateUp: focusTabBar, onBack: onTabBarBack),
              GuideTab(key: _guideTabKey, channels: _channels, onNavigateUp: focusTabBar, onBack: onTabBarBack),
              ChannelsTab(key: _channelsTabKey, channels: _channels, onNavigateUp: focusTabBar, onBack: onTabBarBack),
              RecordingsTab(key: _recordingsTabKey, onNavigateUp: focusTabBar, onBack: onTabBarBack),
              ScheduledTab(key: _scheduledTabKey, onNavigateUp: focusTabBar, onBack: onTabBarBack),
              SeriesTimersTab(key: _seriesTimersTabKey, onNavigateUp: focusTabBar, onBack: onTabBarBack),
            ],
          ),
        ),
      ],
    );
  }
}
