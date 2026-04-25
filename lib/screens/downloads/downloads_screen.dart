import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import '../../focus/dpad_navigator.dart';
import '../../models/media_metadata.dart';
import '../../providers/download_provider.dart';
import '../../widgets/app_icon.dart';
import '../../providers/multi_server_provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/global_key_utils.dart';
import '../../mixins/tab_navigation_mixin.dart';
import '../../services/settings_service.dart' show ViewMode;
import '../../utils/grid_size_calculator.dart';
import '../../utils/layout_constants.dart';
import '../../utils/platform_detector.dart';
import '../../widgets/focusable_tab_chip.dart';
import '../../widgets/focusable_media_card.dart';
import '../../widgets/media_grid_delegate.dart';
import '../../widgets/download_tree_view.dart';
import '../main_screen.dart';
import '../libraries/state_messages.dart';
import '../../i18n/strings.g.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => DownloadsScreenState();
}

class DownloadsScreenState extends State<DownloadsScreen> with TickerProviderStateMixin, TabNavigationMixin {
  // Focus nodes for tab chips
  final _queueTabChipFocusNode = FocusNode(debugLabel: 'tab_chip_queue');
  final _tvShowsTabChipFocusNode = FocusNode(debugLabel: 'tab_chip_tv_shows');
  final _moviesTabChipFocusNode = FocusNode(debugLabel: 'tab_chip_movies');
  final _refreshButtonFocusNode = FocusNode(debugLabel: 'RefreshButton');
  bool _isRefreshFocused = false;

  @override
  List<FocusNode> get tabChipFocusNodes => [_queueTabChipFocusNode, _tvShowsTabChipFocusNode, _moviesTabChipFocusNode];

  @override
  void initState() {
    super.initState();
    suppressAutoFocus = true; // Start suppressed
    initTabNavigation();
    _refreshButtonFocusNode.addListener(_onRefreshFocusChange);
  }

  @override
  void dispose() {
    _queueTabChipFocusNode.dispose();
    _tvShowsTabChipFocusNode.dispose();
    _moviesTabChipFocusNode.dispose();
    _refreshButtonFocusNode.removeListener(_onRefreshFocusChange);
    _refreshButtonFocusNode.dispose();
    disposeTabNavigation();
    super.dispose();
  }

  void _onRefreshFocusChange() {
    if (mounted) setState(() => _isRefreshFocused = _refreshButtonFocusNode.hasFocus);
  }

  KeyEventResult _handleRefreshKeyEvent(FocusNode _, KeyEvent event) {
    if (!event.isActionable) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key.isLeftKey) {
      getTabChipFocusNode(tabCount - 1).requestFocus();
      return KeyEventResult.handled;
    }
    if (key.isRightKey || key.isUpKey) return KeyEventResult.handled;
    if (key.isDownKey) {
      _focusCurrentTab();
      return KeyEventResult.handled;
    }
    if (key.isSelectKey) {
      context.read<DownloadProvider>().refresh();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void onTabChanged() {
    if (!tabController.indexIsChanging) {
      super.onTabChanged();
    }
  }

  /// Focus the first item in the currently active tab
  void _focusCurrentTab() {
    // Re-enable auto-focus since user is navigating into tab content
    setState(() {
      suppressAutoFocus = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Focus will be handled by the tab content
    });
  }

  Widget _buildTabChip(String label, int index, {bool hasRefreshButton = false}) {
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
          : hasRefreshButton
              ? () => _refreshButtonFocusNode.requestFocus()
              : null,
      onNavigateDown: _focusCurrentTab,
      onNavigateUp: hasRefreshButton ? () => _refreshButtonFocusNode.requestFocus() : onTabBarBack,
      onBack: onTabBarBack,
    );
  }

  @override
  Widget build(BuildContext context) {
    final useSideNav = PlatformDetector.shouldUseSideNavigation(context);
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final dims = AppBarLayout.getDimensions(context);
    final titleStyle = Theme.of(context).appBarTheme.titleTextStyle ?? Theme.of(context).textTheme.titleLarge;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: statusBarHeight + dims.contentHeight,
        title: null,
        leading: null,
        leadingWidth: 0,
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: Padding(
          padding: EdgeInsets.only(
            top: statusBarHeight,
            left: 16,
            right: 16,
            bottom: dims.barPadding,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: dims.barPadding),
            child: useSideNav
                ? Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildTabChip(t.downloads.manage, 0, hasRefreshButton: true),
                              const SizedBox(width: 8),
                              _buildTabChip(t.downloads.tvShows, 1, hasRefreshButton: true),
                              const SizedBox(width: 8),
                              _buildTabChip(t.downloads.movies, 2, hasRefreshButton: true),
                            ],
                          ),
                        ),
                      ),
                      Focus(
                        focusNode: _refreshButtonFocusNode,
                        onKeyEvent: _handleRefreshKeyEvent,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _isRefreshFocused ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
                            borderRadius: const BorderRadius.all(Radius.circular(20)),
                          ),
                          child: Semantics(
                            label: t.common.refresh,
                            button: true,
                            excludeSemantics: true,
                            child: IconButton(
                              icon: const AppIcon(Symbols.refresh_rounded, fill: 1),
                              tooltip: null,
                              onPressed: () => context.read<DownloadProvider>().refresh(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Align(
                    alignment: Alignment.topLeft,
                    child: Text(t.downloads.title, style: titleStyle),
                  ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (!useSideNav)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: dims.barPadding),
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTabChip(t.downloads.manage, 0),
                    const SizedBox(width: 8),
                    _buildTabChip(t.downloads.tvShows, 1),
                    const SizedBox(width: 8),
                    _buildTabChip(t.downloads.movies, 2),
                  ],
                ),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: tabController,
              children: [
                Consumer2<DownloadProvider, MultiServerProvider>(
                  builder: (context, downloadProvider, serverProvider, _) {
                    // Only show downloads for currently configured servers (hide legacy
                    // downloads when logged in as Jellyfin-only and vice versa).
                    final serverIds = serverProvider.serverIds.toSet();
                          final filteredDownloads = Map.fromEntries(
                            downloadProvider.downloads.entries
                                .where((e) => serverIds.contains(parseGlobalKey(e.key)?.serverId)),
                          );
                          final filteredMetadata = Map.fromEntries(
                            downloadProvider.metadata.entries
                                .where((e) => serverIds.contains(parseGlobalKey(e.key)?.serverId)),
                          );

                          // Helper to get client from globalKey (serverId:itemId)
                          getClient(String globalKey) {
                            final serverId = parseGlobalKey(globalKey)?.serverId ?? globalKey;
                            return serverProvider.serverManager.getClient(serverId);
                          }

                          return DownloadTreeView(
                            downloads: filteredDownloads,
                            metadata: filteredMetadata,
                            onPause: downloadProvider.pauseDownload,
                            onResume: (globalKey) {
                              final client = getClient(globalKey);
                              if (client != null) {
                                downloadProvider.resumeDownload(globalKey, client);
                              }
                            },
                            onRetry: (globalKey) {
                              final client = getClient(globalKey);
                              if (client != null) {
                                downloadProvider.retryDownload(globalKey, client);
                              }
                            },
                            onCancel: downloadProvider.cancelDownload,
                            onDelete: downloadProvider.deleteDownload,
                            onNavigateLeft: () => MainScreenFocusScope.of(context)?.focusSidebar(),
                            onNavigateUp: focusTabBar,
                            onBack: focusTabBar,
                            suppressAutoFocus: suppressAutoFocus,
                          );
                        },
                ),
                _DownloadsGridContent(
                  type: DownloadType.tvShows,
                  suppressAutoFocus: suppressAutoFocus,
                  onBack: focusTabBar,
                  onNavigateUp: focusTabBar,
                ),
                _DownloadsGridContent(
                  type: DownloadType.movies,
                  suppressAutoFocus: suppressAutoFocus,
                  onBack: focusTabBar,
                  onNavigateUp: focusTabBar,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum DownloadType { manage, tvShows, movies }

/// Grid content for TV Shows and Movies tabs
class _DownloadsGridContent extends StatefulWidget {
  final DownloadType type;
  final bool suppressAutoFocus;
  final VoidCallback? onBack;
  final VoidCallback? onNavigateUp;

  const _DownloadsGridContent({required this.type, required this.suppressAutoFocus, this.onBack, this.onNavigateUp});

  @override
  State<_DownloadsGridContent> createState() => _DownloadsGridContentState();
}

class _DownloadsGridContentState extends State<_DownloadsGridContent> {
  final FocusNode _firstItemFocusNode = FocusNode(debugLabel: 'DownloadsGrid_firstItem');

  @override
  void dispose() {
    _firstItemFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_DownloadsGridContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When suppressAutoFocus changes from true to false, focus the first item
    if (oldWidget.suppressAutoFocus && !widget.suppressAutoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _firstItemFocusNode.canRequestFocus) {
          _firstItemFocusNode.requestFocus();
        }
      });
    }
  }

  /// Navigate focus to the sidebar
  void _navigateToSidebar() {
    MainScreenFocusScope.of(context)?.focusSidebar();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<DownloadProvider, MultiServerProvider, SettingsProvider>(
      builder: (context, downloadProvider, serverProvider, settingsProvider, _) {
        final serverIds = serverProvider.serverIds.toSet();
        final shows = downloadProvider.downloadedShows
            .where((s) => s.serverId != null && serverIds.contains(s.serverId))
            .toList();
        final movies = downloadProvider.downloadedMovies
            .where((m) => m.serverId != null && serverIds.contains(m.serverId))
            .toList();
        final List<MediaMetadata> items =
            widget.type == DownloadType.tvShows ? shows : movies;

        if (items.isEmpty) {
          return _buildEmptyState();
        }

        // Extra top padding for focus decoration (scale + border extends beyond item bounds)
        const effectivePadding = EdgeInsets.only(left: 8, right: 8, top: 8);
        final isListMode = settingsProvider.viewMode == ViewMode.list;

        if (isListMode) {
          return ListView.builder(
            padding: effectivePadding,
            // Flutter deprecated cacheExtent on scrollables; keep until a replacement lands.
            // ignore: deprecated_member_use
            cacheExtent: settingsProvider.gridPreloadCacheExtent,
            clipBehavior: Clip.none,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isFirst = index == 0;
              final isFirstRow = index == 0;
              return FocusableMediaCard(
                item: item,
                focusNode: isFirst ? _firstItemFocusNode : null,
                onBack: widget.onBack,
                isOffline: true,
                onNavigateLeft: _navigateToSidebar,
                onNavigateUp: isFirstRow ? widget.onNavigateUp : null,
              );
            },
          );
        }

        final maxCrossAxisExtent = GridSizeCalculator.getMaxCrossAxisExtent(context, settingsProvider.libraryDensity);

        // Use LayoutBuilder to get actual available width (accounting for sidebar)
        return LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth - effectivePadding.left - effectivePadding.right;
            final columnCount = GridSizeCalculator.getColumnCount(availableWidth, maxCrossAxisExtent);

            return GridView.builder(
              padding: effectivePadding,
              // Flutter deprecated cacheExtent on scrollables; keep until a replacement lands.
              // ignore: deprecated_member_use
              cacheExtent: settingsProvider.gridPreloadCacheExtent,
              clipBehavior: Clip.none,
              gridDelegate: MediaGridDelegate.createDelegate(
                context: context,
                density: settingsProvider.libraryDensity,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isFirstColumn = GridSizeCalculator.isFirstColumn(index, columnCount);
                final isFirst = index == 0;
                final isFirstRow = GridSizeCalculator.isFirstRow(index, columnCount);
                return FocusableMediaCard(
                  item: item,
                  focusNode: isFirst ? _firstItemFocusNode : null,
                  onBack: widget.onBack,
                  isOffline: true,
                  onNavigateLeft: isFirstColumn ? _navigateToSidebar : null,
                  onNavigateUp: isFirstRow ? widget.onNavigateUp : null,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return EmptyStateWidget(
      message: t.downloads.noDownloads,
      subtitle: t.downloads.noDownloadsDescription,
      icon: Symbols.download_rounded,
      iconSize: 80,
    );
  }
}
