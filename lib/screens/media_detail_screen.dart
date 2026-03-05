import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:finzy/utils/platform_detector.dart';
import 'package:finzy/widgets/app_icon.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import '../widgets/collapsible_text.dart';

import '../focus/dpad_navigator.dart';
import '../focus/focusable_wrapper.dart';
import '../focus/key_event_utils.dart';
import '../focus/input_mode_tracker.dart';
import '../widgets/focus_builders.dart';
import '../widgets/media_card.dart';
import '../i18n/strings.g.dart';
import '../widgets/optimized_image.dart';
import '../utils/media_image_helper.dart';
import '../../services/jellyfin_client.dart';
import '../services/api_cache.dart';
import '../services/storage_service.dart';
import '../models/media_metadata.dart';
import '../utils/content_utils.dart';
import '../utils/rating_utils.dart';
import '../models/download_models.dart';
import '../providers/download_provider.dart';
import '../providers/offline_watch_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/mono_tokens.dart';
import '../utils/app_logger.dart';
import '../utils/formatters.dart';
import '../utils/scroll_utils.dart';
import '../utils/provider_extensions.dart';
import '../utils/dialogs.dart';
import '../utils/snackbar_helper.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/video_player_navigation.dart';
import '../widgets/app_bar_back_button.dart';
import 'person_detail_screen.dart';
import '../widgets/horizontal_scroll_with_arrows.dart';
import '../widgets/media_context_menu.dart';
import '../widgets/placeholder_container.dart';
import '../mixins/watch_state_aware.dart';
import '../mixins/deletion_aware.dart';
import '../utils/watch_state_notifier.dart';
import '../utils/deletion_notifier.dart';
import 'season_detail_screen.dart';

class MediaDetailScreen extends StatefulWidget {
  final MediaMetadata metadata;
  final bool isOffline;

  const MediaDetailScreen({super.key, required this.metadata, this.isOffline = false});

  @override
  State<MediaDetailScreen> createState() => _MediaDetailScreenState();
}

class _MediaDetailScreenState extends State<MediaDetailScreen> with WatchStateAware, DeletionAware {
  List<MediaMetadata> _seasons = [];
  bool _isLoadingSeasons = false;
  MediaMetadata? _fullMetadata;
  MediaMetadata? _nextEpisode;
  bool _isLoadingMetadata = true;
  List<MediaMetadata>? _extras;
  late final ScrollController _scrollController;
  final ScrollController _seasonsScrollController = ScrollController();
  final ScrollController _extrasScrollController = ScrollController();
  bool _watchStateChanged = false;
  double _scrollOffset = 0;

  // Locked focus pattern for seasons
  int _focusedSeasonIndex = 0;
  late final FocusNode _seasonsFocusNode;
  late final FocusNode _playButtonFocusNode;
  late final FocusNode _ratingChipFocusNode;
  late final FocusNode _backButtonFocusNode;
  Timer? _selectKeyTimer;
  bool _isSelectKeyDown = false;
  bool _longPressTriggered = false;
  static const _longPressDuration = Duration(milliseconds: 500);

  // GlobalKeys for season cards to access their context menu
  final Map<int, GlobalKey<MediaCardState>> _seasonCardKeys = {};

  // Locked focus pattern for extras
  late final FocusNode _extrasFocusNode;

  // Similar items ("More Like This")
  List<MediaMetadata>? _similarItems;
  int _focusedSimilarIndex = 0;
  late final FocusNode _similarItemsFocusNode;
  final ScrollController _similarItemsScrollController = ScrollController();
  final Map<int, GlobalKey<MediaCardState>> _similarCardKeys = {};
  final _similarSectionKey = GlobalKey();

  final _overviewSectionKey = GlobalKey();
  late final FocusNode _overviewFocusNode;

  // Locked focus pattern for cast
  int _focusedCastIndex = 0;
  late final FocusNode _castFocusNode;
  final ScrollController _castScrollController = ScrollController();
  final _castSectionKey = GlobalKey();
  final _seasonsSectionKey = GlobalKey();

  String _toGlobalKey(String itemId, {String? serverId}) =>
      '${serverId ?? widget.metadata.serverId ?? ''}:$itemId';

  // WatchStateAware: watch the show/movie and all season itemIds
  @override
  Set<String>? get watchedItemIds {
    final keys = <String>{widget.metadata.itemId};
    for (final season in _seasons) {
      keys.add(season.itemId);
    }
    return keys;
  }

  @override
  String? get watchStateServerId => widget.metadata.serverId;

  @override
  Set<String>? get watchedGlobalKeys {
    final serverId = widget.metadata.serverId;
    if (serverId == null) return null;

    final keys = <String>{_toGlobalKey(widget.metadata.itemId, serverId: serverId)};
    for (final season in _seasons) {
      keys.add(_toGlobalKey(season.itemId, serverId: season.serverId ?? serverId));
    }
    return keys;
  }

  @override
  void onWatchStateChanged(WatchStateEvent event) {
    // Lightweight refresh - no loader, preserves scroll position
    if (!widget.isOffline) {
      _refreshWatchState();
    }
  }

  @override
  Set<String>? get deletionItemIds {
    final keys = <String>{widget.metadata.itemId};
    for (final season in _seasons) {
      keys.add(season.itemId);
    }
    return keys;
  }

  @override
  String? get deletionServerId => widget.metadata.serverId;

  @override
  Set<String>? get deletionGlobalKeys {
    final serverId = widget.metadata.serverId;
    if (serverId == null) return null;

    final keys = <String>{_toGlobalKey(widget.metadata.itemId, serverId: serverId)};
    for (final season in _seasons) {
      keys.add(_toGlobalKey(season.itemId, serverId: season.serverId ?? serverId));
    }
    return keys;
  }

  @override
  void onDeletionEvent(DeletionEvent event) {
    if (widget.isOffline) return;

    // If we have a season that matches the item ID exactly, then remove it from our list
    final seasonIndex = _seasons.indexWhere((s) => s.itemId == event.itemId);
    if (seasonIndex != -1) {
      setState(() {
        _seasons.removeAt(seasonIndex);
      });

      // If the show has no more seasons, navigate back up to the library
      if (_seasons.isEmpty && mounted) {
        Navigator.of(context).pop();
        return;
      }
      _refreshWatchState();
      return;
    }

    // If a child item was delete, then update our list to reflect that.
    // If all children were deleted, remove our item.
    // Otherwise, just update the counts.
    for (final parentKey in event.parentChain) {
      final idx = _seasons.indexWhere((s) => s.itemId == parentKey);
      if (idx != -1) {
        final season = _seasons[idx];
        final newLeafCount = (season.leafCount ?? 1) - 1;
        if (newLeafCount <= 0) {
          // Season is now empty, remove it
          setState(() {
            _seasons.removeAt(idx);
          });

          // Otherwise we have no more seasons, so navigate up
          if (_seasons.isEmpty && mounted) {
            Navigator.of(context).pop();
            return;
          }
        } else {
          setState(() {
            // Otherwise just update the counts
            _seasons[idx] = season.copyWith(leafCount: newLeafCount);
          });
        }
        _refreshWatchState();
        return;
      }
    }
  }

  /// Lightweight refresh for watch state changes - no loader, preserves scroll
  Future<void> _refreshWatchState() async {
    final client = _getClientForMetadata(context);
    if (client == null) return;

    try {
      // Fetch updated metadata + next episode without showing loader
      final result = await client.getMetadataWithNextEpisode(widget.metadata.itemId);
      final metadata = result['metadata'] as MediaMetadata?;
      final nextEpisode = result['nextEpisode'] as MediaMetadata?;

      if (metadata != null && mounted) {
        setState(() {
          _fullMetadata = metadata.copyWith(serverId: widget.metadata.serverId, serverName: widget.metadata.serverName);
          _nextEpisode = nextEpisode?.copyWith(
            serverId: widget.metadata.serverId,
            serverName: widget.metadata.serverName,
          );
        });
      }

      // Refresh seasons for updated watched counts (also without loader)
      if (widget.metadata.isShow) {
        final seasons = await client.getChildren(widget.metadata.itemId);
        if (mounted) {
          setState(() {
            _seasons = seasons
                .map((s) => s.copyWith(serverId: widget.metadata.serverId, serverName: widget.metadata.serverName))
                .toList();
          });
        }
      }
    } catch (e) {
      // Silently fail - data will refresh on next navigation
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _seasonsFocusNode = FocusNode(debugLabel: 'seasons_row');
    _extrasFocusNode = FocusNode(debugLabel: 'extras_row');
    _playButtonFocusNode = FocusNode(debugLabel: 'play_button');
    _ratingChipFocusNode = FocusNode(debugLabel: 'rating_chip');
    _backButtonFocusNode = FocusNode(debugLabel: 'detail_back');
    _castFocusNode = FocusNode(debugLabel: 'cast_row');
    _similarItemsFocusNode = FocusNode(debugLabel: 'similar_items_row');
    _overviewFocusNode = FocusNode(debugLabel: 'overview_section');
    _loadFullMetadata();
  }

  void _onScroll() {
    setState(() {
      _scrollOffset = _scrollController.offset;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _seasonsScrollController.dispose();
    _extrasScrollController.dispose();
    _seasonsFocusNode.dispose();
    _extrasFocusNode.dispose();
    _playButtonFocusNode.dispose();
    _ratingChipFocusNode.dispose();
    _backButtonFocusNode.dispose();
    _castFocusNode.dispose();
    _castScrollController.dispose();
    _similarItemsFocusNode.dispose();
    _similarItemsScrollController.dispose();
    _overviewFocusNode.dispose();
    _selectKeyTimer?.cancel();
    super.dispose();
  }

  /// Build title text widget for clear logo fallback
  Widget _buildTitleText(BuildContext context, String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 8)],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// Build radial progress indicator for download button
  /// If progressPercent is null or 0, shows indeterminate spinner
  Widget _buildRadialProgress(double? progressPercent) {
    return SizedBox(
      width: 20,
      height: 20,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle (only show if we have determinate progress)
          if (progressPercent != null && progressPercent > 0)
            CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 2.0,
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
            ),
          // Progress circle (indeterminate if no progress, determinate otherwise)
          CircularProgressIndicator(
            value: (progressPercent != null && progressPercent > 0) ? progressPercent : null, // null = indeterminate
            strokeWidth: 2.0,
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
    );
  }

  /// Build action buttons row (play, download, mark watched)
  Widget _buildActionButtons(MediaMetadata metadata) {
    final playButtonLabel = _getPlayButtonLabel(metadata);
    final playButtonIcon = AppIcon(_getPlayButtonIcon(metadata), fill: 1, size: 20);

    Future<void> onPlayPressed() async {
      // For TV shows, play the next episode if available
      // Otherwise, play the first episode of the first season
      if (metadata.isShow) {
        if (_nextEpisode != null) {
          appLogger.d('Playing next episode: ${_nextEpisode!.title}');
          await navigateToVideoPlayerWithRefresh(
            context,
            metadata: _nextEpisode!,
            isOffline: widget.isOffline,
            onRefresh: _loadFullMetadata,
          );
        } else {
          // No next episode, fetch first episode of first season
          await _playFirstEpisode();
        }
      } else {
        appLogger.d('Playing: ${metadata.title}');
        // For movies or episodes, play directly
        await navigateToVideoPlayerWithRefresh(
          context,
          metadata: metadata,
          isOffline: widget.isOffline,
          onRefresh: _loadFullMetadata,
        );
      }
    }

    final primaryTrailer = _getPrimaryTrailer();

    return Focus(
      skipTraversal: true,
      onKeyEvent: _handlePlayButtonKeyEvent,
      child: Row(
        children: [
          IconButton.filledTonal(
            focusNode: _playButtonFocusNode,
            autofocus: InputModeTracker.isKeyboardMode(context),
            onPressed: onPlayPressed,
            icon: playButtonIcon,
            tooltip: playButtonLabel.isNotEmpty ? playButtonLabel : null,
            iconSize: 20,
            style: IconButton.styleFrom(minimumSize: const Size(48, 48), maximumSize: const Size(48, 48)),
          ),
          const SizedBox(width: 12),
          // Restart / Play from start (when play would resume — hide if play already starts from 0)
          if (!widget.isOffline &&
              (metadata.isMovie || metadata.isEpisode) &&
              metadata.hasActiveProgress) ...[
            IconButton.filledTonal(
              onPressed: () async {
                final fromStart = metadata.copyWith(resumePositionMs: 0);
                await navigateToVideoPlayerWithRefresh(
                  context,
                  metadata: fromStart,
                  isOffline: widget.isOffline,
                  onRefresh: _loadFullMetadata,
                );
              },
              icon: const AppIcon(Symbols.replay_rounded, fill: 1),
              tooltip: t.tooltips.playFromStart,
              iconSize: 20,
              style: IconButton.styleFrom(minimumSize: const Size(48, 48), maximumSize: const Size(48, 48)),
            ),
            const SizedBox(width: 12),
          ],
          // Trailer button (only if trailer is available)
          if (primaryTrailer != null) ...[
            IconButton.filledTonal(
              onPressed: () async {
                final key = primaryTrailer.itemId;
                if (key.startsWith('http://') || key.startsWith('https://')) {
                  final uri = Uri.parse(key);
                  if (await canLaunchUrl(uri)) {
                    // Save return context before launching external app (Android TV may kill process)
                    final storage = await StorageService.getInstance();
                    await storage.savePendingExternalReturn(
                      itemId: widget.metadata.itemId,
                      serverId: widget.metadata.serverId,
                    );
                    if (mounted) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  }
                } else {
                  await navigateToVideoPlayer(context, metadata: primaryTrailer);
                }
              },
              icon: const AppIcon(Symbols.theaters_rounded, fill: 1),
              tooltip: t.tooltips.playTrailer,
              iconSize: 20,
              style: IconButton.styleFrom(minimumSize: const Size(48, 48), maximumSize: const Size(48, 48)),
            ),
            const SizedBox(width: 12),
          ],
          // Download button (hide in offline mode - already downloaded)
          if (!widget.isOffline)
            Consumer<DownloadProvider>(
              builder: (context, downloadProvider, _) {
                final globalKey = '${metadata.serverId}:${metadata.itemId}';
                final progress = downloadProvider.getProgress(globalKey);
                final isQueueing = downloadProvider.isQueueing(globalKey);

                // Debug logging
                if (progress != null) {
                  appLogger.d(
                    'UI rebuilding for $globalKey: status=${progress.status}, progress=${progress.progress}%',
                  );
                }

                // State 1: Queueing (building download queue)
                if (isQueueing) {
                  return IconButton.filledTonal(
                    onPressed: null,
                    icon: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    iconSize: 20,
                    style: IconButton.styleFrom(minimumSize: const Size(48, 48), maximumSize: const Size(48, 48)),
                  );
                }

                // State 2: Queued (waiting to download)
                if (progress?.status == DownloadStatus.queued) {
                  final currentFile = progress?.currentFile;
                  final tooltip = currentFile != null && currentFile.contains('episodes')
                      ? 'Queued $currentFile'
                      : 'Queued';

                  return IconButton.filledTonal(
                    onPressed: null,
                    tooltip: tooltip,
                    icon: const AppIcon(Symbols.schedule_rounded, fill: 1),
                    iconSize: 20,
                    style: IconButton.styleFrom(minimumSize: const Size(48, 48), maximumSize: const Size(48, 48)),
                  );
                }

                // State 3: Downloading (active download)
                if (progress?.status == DownloadStatus.downloading) {
                  // Show episode count in tooltip for shows/seasons
                  final currentFile = progress?.currentFile;
                  final tooltip = currentFile != null && currentFile.contains('episodes')
                      ? 'Downloading $currentFile'
                      : 'Downloading...';

                  return IconButton.filledTonal(
                    onPressed: null,
                    tooltip: tooltip,
                    icon: _buildRadialProgress(progress?.progressPercent),
                    iconSize: 20,
                    style: IconButton.styleFrom(minimumSize: const Size(48, 48), maximumSize: const Size(48, 48)),
                  );
                }

                // State 4: Paused (can resume)
                if (progress?.status == DownloadStatus.paused) {
                  return IconButton.filledTonal(
                    onPressed: () async {
                      final client = _getClientForMetadata(context);
                      if (client == null) return;
                      await downloadProvider.resumeDownload(globalKey, client);
                      if (context.mounted) {
                        showAppSnackBar(context, 'Download resumed');
                      }
                    },
                    icon: const AppIcon(Symbols.pause_circle_outline_rounded, fill: 1),
                    tooltip: 'Resume download',
                    iconSize: 20,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      maximumSize: const Size(48, 48),
                      foregroundColor: Colors.amber,
                    ),
                  );
                }

                // State 5: Failed (can retry)
                if (progress?.status == DownloadStatus.failed) {
                  return IconButton.filledTonal(
                    onPressed: () async {
                      final client = _getClientForMetadata(context);
                      if (client == null) return;

                      // Delete failed download and retry
                      await downloadProvider.deleteDownload(globalKey);
                      try {
                        await downloadProvider.queueDownload(metadata, client);

                        if (context.mounted) {
                          showSuccessSnackBar(context, t.downloads.downloadQueued);
                        }
                      } on CellularDownloadBlockedException {
                        if (context.mounted) {
                          showErrorSnackBar(context, t.settings.cellularDownloadBlocked);
                        }
                      }
                    },
                    icon: const AppIcon(Symbols.error_outline_rounded, fill: 1),
                    tooltip: 'Retry download',
                    iconSize: 20,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      maximumSize: const Size(48, 48),
                      foregroundColor: Colors.red,
                    ),
                  );
                }

                // State 6: Cancelled (can delete or retry)
                if (progress?.status == DownloadStatus.cancelled) {
                  return IconButton.filledTonal(
                    onPressed: () async {
                      // Show options: Delete or Retry
                      final retry = await showConfirmDialog(
                        context,
                        title: 'Cancelled Download',
                        message: 'This download was cancelled. What would you like to do?',
                        cancelText: t.common.delete,
                        confirmText: 'Retry',
                      );

                      if (!retry && context.mounted) {
                        await downloadProvider.deleteDownload(globalKey);
                        if (context.mounted) {
                          showSuccessSnackBar(context, t.downloads.downloadDeleted);
                        }
                      } else if (retry && context.mounted) {
                        final client = _getClientForMetadata(context);
                        if (client == null) return;
                        await downloadProvider.deleteDownload(globalKey);
                        try {
                          await downloadProvider.queueDownload(metadata, client);
                          if (context.mounted) {
                            showSuccessSnackBar(context, t.downloads.downloadQueued);
                          }
                        } on CellularDownloadBlockedException {
                          if (context.mounted) {
                            showErrorSnackBar(context, t.settings.cellularDownloadBlocked);
                          }
                        }
                      }
                    },
                    icon: const AppIcon(Symbols.cancel_rounded, fill: 1),
                    tooltip: 'Cancelled download',
                    iconSize: 20,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      maximumSize: const Size(48, 48),
                      foregroundColor: Colors.grey,
                    ),
                  );
                }

                // State 7: Partial Download (some episodes downloaded, not all)
                if (progress?.status == DownloadStatus.partial) {
                  final currentFile = progress?.currentFile;
                  final tooltip = currentFile != null
                      ? 'Downloaded $currentFile - Click to complete'
                      : 'Partially downloaded - Click to complete';

                  return IconButton.filledTonal(
                    onPressed: () async {
                      final client = _getClientForMetadata(context);
                      if (client == null) return;

                      // Queue only the missing episodes
                      final count = await downloadProvider.queueMissingEpisodes(metadata, client);

                      if (context.mounted) {
                        final message = count > 0
                            ? t.downloads.episodesQueued(count: count)
                            : 'All episodes already downloaded';
                        showAppSnackBar(context, message);
                      }
                    },
                    tooltip: tooltip,
                    icon: const AppIcon(Symbols.downloading_rounded, fill: 1),
                    iconSize: 20,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      maximumSize: const Size(48, 48),
                      foregroundColor: Colors.orange,
                    ),
                  );
                }

                // State 8: Downloaded/Completed (can delete)
                if (downloadProvider.isDownloaded(globalKey)) {
                  return IconButton.filledTonal(
                    onPressed: () async {
                      // Show delete download confirmation
                      final confirmed = await showDeleteConfirmation(
                        context,
                        title: t.downloads.deleteDownload,
                        message: t.downloads.deleteConfirm(title: metadata.title),
                      );

                      if (confirmed && context.mounted) {
                        await downloadProvider.deleteDownload(globalKey);
                        if (context.mounted) {
                          showSuccessSnackBar(context, t.downloads.downloadDeleted);
                        }
                      }
                    },
                    icon: const AppIcon(Symbols.file_download_done_rounded, fill: 1),
                    tooltip: t.downloads.deleteDownload,
                    iconSize: 20,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      maximumSize: const Size(48, 48),
                      foregroundColor: Colors.green,
                    ),
                  );
                }

                // State 9: Not downloaded (default - can download)
                return IconButton.filledTonal(
                  onPressed: () async {
                    final client = _getClientForMetadata(context);
                    if (client == null) return;
                    final count = await downloadProvider.queueDownload(metadata, client);
                    if (context.mounted) {
                      final message = count > 1 ? t.downloads.episodesQueued(count: count) : t.downloads.downloadQueued;
                      showSuccessSnackBar(context, message);
                    }
                  },
                  icon: const AppIcon(Symbols.download_rounded, fill: 1),
                  tooltip: t.downloads.downloadNow,
                  iconSize: 20,
                  style: IconButton.styleFrom(minimumSize: const Size(48, 48), maximumSize: const Size(48, 48)),
                );
              },
            ),
          const SizedBox(width: 12),
          // Mark as watched/unwatched toggle (works offline too)
          IconButton.filledTonal(
            onPressed: () async {
              try {
                final isWatched = metadata.isWatched;
                if (widget.isOffline) {
                  // Offline mode: queue action for later sync
                  final offlineWatch = context.read<OfflineWatchProvider>();
                  if (isWatched) {
                    await offlineWatch.markAsUnwatched(serverId: metadata.serverId!, itemId: metadata.itemId);
                  } else {
                    await offlineWatch.markAsWatched(serverId: metadata.serverId!, itemId: metadata.itemId);
                  }
                  if (mounted) {
                    showAppSnackBar(
                      context,
                      isWatched ? t.messages.markedAsUnwatchedOffline : t.messages.markedAsWatchedOffline,
                    );
                    // Refresh offline next episode
                    _loadOfflineNextEpisode();
                  }
                } else {
                  // Online mode: send to server
                  final client = _getClientForMetadata(context);
                  if (client == null) return;

                  if (isWatched) {
                    await client.markAsUnwatched(metadata.itemId);
                  } else {
                    await client.markAsWatched(metadata.itemId);
                  }
                  if (mounted) {
                    _watchStateChanged = true;
                    showSuccessSnackBar(context, isWatched ? t.messages.markedAsUnwatched : t.messages.markedAsWatched);
                    // Update watch state without full rebuild
                    _updateWatchState();
                  }
                }
              } catch (e) {
                if (mounted) {
                  showErrorSnackBar(context, t.messages.errorLoading(error: e.toString()));
                }
              }
            },
            icon: AppIcon(metadata.isWatched ? Symbols.remove_done_rounded : Symbols.check_rounded, fill: 1),
            tooltip: metadata.isWatched ? t.tooltips.markAsUnwatched : t.tooltips.markAsWatched,
            iconSize: 20,
            style: IconButton.styleFrom(minimumSize: const Size(48, 48), maximumSize: const Size(48, 48)),
          ),
          // Favorite button
          if (!widget.isOffline) ...[
            const SizedBox(width: 12),
            IconButton.filledTonal(
              onPressed: () async {
                final client = _getClientForMetadata(context);
                if (client == null) return;
                final metadata = _fullMetadata ?? widget.metadata;
                try {
                  final newState = await client.toggleFavorite(
                    metadata.itemId,
                    isCurrentlyFavorite: metadata.isFavorite == true,
                  );
                  if (mounted && newState != null) {
                    setState(() {
                      _fullMetadata = metadata.copyWith(isFavorite: newState);
                      _watchStateChanged = true; // so back triggers list refresh
                    });
                    showSuccessSnackBar(
                      context,
                      newState ? 'Added to favorites' : 'Removed from favorites',
                    );
                  } else if (mounted) {
                    await _loadFullMetadata();
                  }
                } catch (e) {
                  if (mounted) {
                    showErrorSnackBar(context, t.messages.errorLoading(error: e.toString()));
                  }
                }
              },
              icon: AppIcon(
                metadata.isFavorite == true ? Symbols.favorite_rounded : Symbols.favorite_border_rounded,
                fill: metadata.isFavorite == true ? 1 : 0,
              ),
              tooltip: metadata.isFavorite == true ? 'Remove from favorites' : 'Add to favorites',
              iconSize: 20,
              style: IconButton.styleFrom(
                minimumSize: const Size(48, 48),
                maximumSize: const Size(48, 48),
                foregroundColor: metadata.isFavorite == true ? Colors.red : null,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build a metadata chip with optional leading icon or widget
  Widget _buildMetadataChip(String text, {IconData? icon, Widget? leading}) {
    final textWidget = Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSecondaryContainer,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );

    final hasLeading = leading != null || icon != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.8),
        borderRadius: const BorderRadius.all(Radius.circular(100)),
      ),
      child: hasLeading
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null)
                  leading
                else
                  AppIcon(icon!, fill: 1, color: Theme.of(context).colorScheme.onSecondaryContainer, size: 16),
                const SizedBox(width: 4),
                textWidget,
              ],
            )
          : textWidget,
    );
  }

  /// Format is determined by ratingImage (e.g. TMDB = 6.5, RT = 65%); unknown = percent.
  /// [useReadableLabel] avoids dark SVG logos (TMDB/IMDB) and uses the fallback icon + value only.
  Widget _buildRatingChip(String? imageUri, double value, IconData fallbackIcon, {bool useReadableLabel = false}) {
    final info = parseRatingImage(imageUri, value);
    if (info != null && !useReadableLabel) {
      return _buildMetadataChip(info.formattedValue, leading: SvgPicture.asset(info.assetPath, width: 16, height: 16));
    }
    final formatted = info?.formattedValue ?? value.toStringAsFixed(1);
    return _buildMetadataChip(formatted, icon: fallbackIcon);
  }

  /// Build all rating chips for the metadata.
  /// When both critic and audience ratings are from Rotten Tomatoes,
  /// they are combined into a single badge.
  List<Widget> _buildRatingChips(MediaMetadata metadata) {
    final chips = <Widget>[];
    final bothRT =
        metadata.rating != null &&
        metadata.audienceRating != null &&
        isRottenTomatoes(metadata.ratingImage) &&
        isRottenTomatoes(metadata.audienceRatingImage);

    if (bothRT) {
      final critic = parseRatingImage(metadata.ratingImage, metadata.rating)!;
      final audience = parseRatingImage(metadata.audienceRatingImage, metadata.audienceRating)!;
      chips.add(_buildCombinedRtChip(critic, audience));
    } else {
      if (metadata.rating != null) {
        chips.add(_buildRatingChip(
          metadata.ratingImage,
          metadata.rating!,
          Symbols.star_rounded,
          useReadableLabel: !isRottenTomatoes(metadata.ratingImage),
        ));
      }
      if (metadata.audienceRating != null) {
        chips.add(_buildRatingChip(
          metadata.audienceRatingImage,
          metadata.audienceRating!,
          Symbols.star_rounded,
          useReadableLabel: true,
        ));
      }
    }

    // User rating chip not shown (server handles ratings)

    return chips;
  }

  /// Build a combined RT chip showing critic + audience side by side.
  Widget _buildCombinedRtChip(RatingInfo critic, RatingInfo audience) {
    final textStyle = TextStyle(
      color: Theme.of(context).colorScheme.onSecondaryContainer,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.8),
        borderRadius: const BorderRadius.all(Radius.circular(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(critic.assetPath, width: 16, height: 16),
          const SizedBox(width: 4),
          Text(critic.formattedValue, style: textStyle),
          const SizedBox(width: 10),
          SvgPicture.asset(audience.assetPath, width: 16, height: 16),
          const SizedBox(width: 4),
          Text(audience.formattedValue, style: textStyle),
        ],
      ),
    );
  }

  /// Get the correct JellyfinClient for this metadata's server
  /// Returns null in offline mode or if serverId is null
  JellyfinClient? _getClientForMetadata(BuildContext context) {
    if (widget.isOffline || widget.metadata.serverId == null) {
      return null;
    }
    return context.getClientForServer(widget.metadata.serverId!);
  }

  Future<void> _loadFullMetadata() async {
    setState(() {
      _isLoadingMetadata = true;
    });

    // Offline mode: try to load full metadata from cache (has clearLogo, summary, etc.)
    if (widget.isOffline) {
      final cachedMetadata = await ApiCache.instance.getMetadata(
        widget.metadata.serverId ?? '',
        widget.metadata.itemId,
      );
      if (!mounted) return;
      setState(() {
        _fullMetadata = cachedMetadata ?? widget.metadata;
        _isLoadingMetadata = false;
      });

      if (widget.metadata.isShow) {
        _loadSeasonsFromDownloads();
        // Get offline next episode
        _loadOfflineNextEpisode();
      }
      return;
    }

    try {
      // Use server-specific client for this metadata
      final client = _getClientForMetadata(context);
      if (client == null) {
        // No client available, use passed metadata
        setState(() {
          _fullMetadata = widget.metadata;
          _isLoadingMetadata = false;
        });
        return;
      }

      // Fetch full metadata with clearLogo and next episode
      final result = await client.getMetadataWithNextEpisode(widget.metadata.itemId);
      final metadata = result['metadata'] as MediaMetadata?;
      final nextEpisode = result['nextEpisode'] as MediaMetadata?;

      if (!mounted) return;

      if (metadata != null) {
        // Preserve serverId from original metadata
        final metadataWithServerId = metadata.copyWith(
          serverId: widget.metadata.serverId,
          serverName: widget.metadata.serverName,
        );
        final nextEpisodeWithServerId = nextEpisode?.copyWith(
          serverId: widget.metadata.serverId,
          serverName: widget.metadata.serverName,
        );

        setState(() {
          _fullMetadata = metadataWithServerId;
          _nextEpisode = nextEpisodeWithServerId;
          _isLoadingMetadata = false;
        });

        // Load seasons if it's a show
        if (metadata.isShow) {
          _loadSeasons();
        }

        // Load extras (trailers, behind-the-scenes, etc.)
        _loadExtras();

        // Load similar items ("More Like This")
        _loadSimilarItems();

        return;
      }

      // Fallback to passed metadata
      setState(() {
        _fullMetadata = widget.metadata;
        _isLoadingMetadata = false;
      });

      if (widget.metadata.isShow) {
        _loadSeasons();
      }
    } catch (e) {
      // Fallback to passed metadata on error
      if (!mounted) return;
      setState(() {
        _fullMetadata = widget.metadata;
        _isLoadingMetadata = false;
      });

      if (widget.metadata.isShow) {
        _loadSeasons();
      }
    }
  }

  Future<void> _loadSeasons() async {
    setState(() {
      _isLoadingSeasons = true;
    });

    try {
      // Use server-specific client for this metadata
      final client = _getClientForMetadata(context);

      final seasons = await client?.getChildren(widget.metadata.itemId) ?? [];
      // Preserve serverId for each season
      final seasonsWithServerId = seasons
          .map((season) => season.copyWith(serverId: widget.metadata.serverId, serverName: widget.metadata.serverName))
          .toList();
      if (!mounted) return;
      setState(() {
        _seasons = seasonsWithServerId;
        _isLoadingSeasons = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingSeasons = false;
      });
    }
  }

  /// Load seasons from downloaded episodes (offline mode)
  void _loadSeasonsFromDownloads() {
    setState(() {
      _isLoadingSeasons = true;
    });

    final downloadProvider = context.read<DownloadProvider>();
    final episodes = downloadProvider.getDownloadedEpisodesForShow(widget.metadata.itemId);

    // Group episodes by season
    final Map<int, List<MediaMetadata>> seasonMap = {};
    for (final episode in episodes) {
      final seasonNum = episode.parentIndex ?? 0;
      seasonMap.putIfAbsent(seasonNum, () => []).add(episode);
    }

    // Create season metadata from episodes
    final seasons = seasonMap.entries.map((entry) {
      final firstEp = entry.value.first;
      return MediaMetadata(
        itemId: firstEp.seasonId ?? '',
        key: '${ApiCache.itemPrefix}${firstEp.seasonId}',
        type: 'season',
        title: firstEp.seasonTitle ?? 'Season ${entry.key}',
        index: entry.key,
        thumb: firstEp.seasonImageId,
        seasonId: firstEp.seriesId,
        serverId: widget.metadata.serverId,
        serverName: widget.metadata.serverName,
      );
    }).toList()..sort((a, b) => (a.index ?? 0).compareTo(b.index ?? 0));

    setState(() {
      _seasons = seasons;
      _isLoadingSeasons = false;
    });
  }

  /// Load extras (trailers, behind-the-scenes, etc.)
  Future<void> _loadExtras() async {
    // Only load extras for movies and shows
    if (!widget.metadata.isMovie && !widget.metadata.isShow) {
      return;
    }

    // Skip in offline mode (no server available)
    if (widget.isOffline) {
      return;
    }

    try {
      final client = _getClientForMetadata(context);
      if (client == null) {
        return;
      }

      final extras = await client.getExtras(widget.metadata.itemId);

      // Preserve serverId for each extra (needed for multi-server setups)
      final extrasWithServerId = extras
          .map((extra) => extra.copyWith(serverId: widget.metadata.serverId, serverName: widget.metadata.serverName))
          .toList();

      if (mounted) {
        setState(() {
          _extras = extrasWithServerId;
        });
      }
    } catch (e) {
      // Silently fail - extras section won't appear if fetch fails
    }
  }

  /// Load similar items for "More Like This" section
  Future<void> _loadSimilarItems() async {
    if (!widget.metadata.isMovie && !widget.metadata.isShow) return;
    if (widget.isOffline) return;

    try {
      final client = _getClientForMetadata(context);
      if (client == null) return;

      final items = await client.getSimilarItems(widget.metadata.itemId);

      final itemsWithServerId = items
          .map((item) => item.copyWith(serverId: widget.metadata.serverId, serverName: widget.metadata.serverName))
          .toList();

      if (mounted) {
        setState(() {
          _similarItems = itemsWithServerId;
        });
      }
    } catch (e) {
      // Silently fail - section won't appear
    }
  }

  /// Navigate to a season detail screen
  Future<void> _navigateToSeason(MediaMetadata season) async {
    final watchStateChanged = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => SeasonDetailScreen(season: season, isOffline: widget.isOffline),
      ),
    );
    if (watchStateChanged == true) {
      _watchStateChanged = true;
      _updateWatchState();
    }
  }

  /// Scroll the main CustomScrollView so the section with the given key is visible
  void _scrollSectionIntoView(GlobalKey key) {
    final disableAnimations = context.read<SettingsProvider>().disableAnimations;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, duration: disableAnimations ? Duration.zero : const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  /// Handle key events for the back button
  KeyEventResult _handleBackButtonKeyEvent(FocusNode _, KeyEvent event) {
    final key = event.logicalKey;
    if (!event.isActionable) return KeyEventResult.ignored;

    if (key.isUpKey || key.isRightKey) {
      return KeyEventResult.handled;
    }
    if (key.isLeftKey) {
      if (event is KeyUpEvent) {
        Navigator.pop(context, _watchStateChanged);
      }
      return KeyEventResult.handled;
    }

    if (key.isDownKey) {
      _playButtonFocusNode.requestFocus();
      return KeyEventResult.handled;
    }

    if (key.isSelectKey) {
      Navigator.pop(context, _watchStateChanged);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// Intercept DOWN from the play button row to focus the first available section
  KeyEventResult _handlePlayButtonKeyEvent(FocusNode _, KeyEvent event) {
    final key = event.logicalKey;
    if (!event.isActionable) return KeyEventResult.ignored;

    if (key.isUpKey) {
      if (context.read<SettingsProvider>().disableAnimations) {
        _scrollController.jumpTo(0);
      } else {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
      _backButtonFocusNode.requestFocus();
      return KeyEventResult.handled;
    }

    if (!key.isDownKey) return KeyEventResult.ignored;

    final metadata = _fullMetadata ?? widget.metadata;

    // DOWN order: overview → seasons → cast → similar
    if (metadata.summary != null || metadata.studio != null || metadata.contentRating != null) {
      _overviewFocusNode.requestFocus();
      _scrollSectionIntoView(_overviewSectionKey);
      return KeyEventResult.handled;
    }

    if (metadata.isShow && _seasons.isNotEmpty) {
      _seasonsFocusNode.requestFocus();
      _scrollSectionIntoView(_seasonsSectionKey);
      return KeyEventResult.handled;
    }

    if (metadata.role != null && metadata.role!.isNotEmpty) {
      _castFocusNode.requestFocus();
      _scrollSectionIntoView(_castSectionKey);
      return KeyEventResult.handled;
    }

    return KeyEventResult.handled;
  }

  /// Handle key events for the overview/summary section
  KeyEventResult _handleOverviewKeyEvent(FocusNode _, KeyEvent event) {
    final key = event.logicalKey;
    if (!event.isActionable) return KeyEventResult.ignored;

    if (key.isUpKey) {
      if (context.read<SettingsProvider>().disableAnimations) {
        _scrollController.jumpTo(0);
      } else {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
      _playButtonFocusNode.requestFocus();
      return KeyEventResult.handled;
    }

    if (key.isDownKey) {
      final metadata = _fullMetadata ?? widget.metadata;
      if (metadata.isShow && _seasons.isNotEmpty) {
        _seasonsFocusNode.requestFocus();
        _scrollSectionIntoView(_seasonsSectionKey);
      } else if (metadata.role != null && metadata.role!.isNotEmpty) {
        _castFocusNode.requestFocus();
        _scrollSectionIntoView(_castSectionKey);
      } else if (_similarItems != null && _similarItems!.isNotEmpty) {
        _similarItemsFocusNode.requestFocus();
        _scrollSectionIntoView(_similarSectionKey);
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// Get the responsive card width used by seasons/extras/cast rows
  double _getResponsiveCardWidth() {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 1400) return 220.0;
    if (screenWidth >= 900) return 200.0;
    if (screenWidth >= 700) return 190.0;
    return 160.0;
  }

  /// Handle key events for the seasons row (locked focus pattern)
  KeyEventResult _handleSeasonsKeyEvent(FocusNode _, KeyEvent event) {
    final key = event.logicalKey;

    // Let back key propagate to parent Focus handler
    if (key.isBackKey) {
      return KeyEventResult.ignored;
    }

    // Handle SELECT with long-press detection
    if (key.isSelectKey) {
      if (event is KeyDownEvent) {
        // Always reset state on KeyDown to handle cases where KeyUp was
        // consumed by a modal (e.g., context menu) and we didn't see it
        _selectKeyTimer?.cancel();
        _isSelectKeyDown = true;
        _longPressTriggered = false;
        _selectKeyTimer = Timer(_longPressDuration, () {
          if (!mounted) return;
          if (_isSelectKeyDown) {
            _longPressTriggered = true;
            SelectKeyUpSuppressor.suppressSelectUntilKeyUp();
            // Long-press: show context menu for the focused season
            _seasonCardKeys[_focusedSeasonIndex]?.currentState?.showContextMenu();
          }
        });
        return KeyEventResult.handled;
      } else if (event is KeyRepeatEvent) {
        return KeyEventResult.handled;
      } else if (event is KeyUpEvent) {
        final timerWasActive = _selectKeyTimer?.isActive ?? false;
        _selectKeyTimer?.cancel();
        if (!_longPressTriggered && timerWasActive && _isSelectKeyDown) {
          // Short tap: navigate to season
          if (_focusedSeasonIndex < _seasons.length) {
            _navigateToSeason(_seasons[_focusedSeasonIndex]);
          }
        }
        _isSelectKeyDown = false;
        _longPressTriggered = false;
        return KeyEventResult.handled;
      }
    }

    if (!event.isActionable) return KeyEventResult.ignored;
    if (_seasons.isEmpty) return KeyEventResult.ignored;

    final disableAnims = context.read<SettingsProvider>().disableAnimations;

    // LEFT: previous season
    if (key.isLeftKey) {
      if (_focusedSeasonIndex > 0) {
        setState(() {
          _focusedSeasonIndex--;
        });
        scrollListToIndex(_seasonsScrollController, _focusedSeasonIndex, itemExtent: _getResponsiveCardWidth() + 4, disableAnimations: disableAnims);
      }
      return KeyEventResult.handled;
    }

    // RIGHT: next season
    if (key.isRightKey) {
      if (_focusedSeasonIndex < _seasons.length - 1) {
        setState(() {
          _focusedSeasonIndex++;
        });
        scrollListToIndex(_seasonsScrollController, _focusedSeasonIndex, itemExtent: _getResponsiveCardWidth() + 4, disableAnimations: disableAnims);
      }
      return KeyEventResult.handled;
    }

    // UP: overview → play button
    if (key.isUpKey) {
      final metadata = _fullMetadata ?? widget.metadata;
      if (metadata.summary != null || metadata.studio != null || metadata.contentRating != null) {
        _overviewFocusNode.requestFocus();
        _scrollSectionIntoView(_overviewSectionKey);
      } else {
        if (disableAnims) {
          _scrollController.jumpTo(0);
        } else {
          _scrollController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        }
        _playButtonFocusNode.requestFocus();
      }
      return KeyEventResult.handled;
    }

    // DOWN: cast → (extras section removed)
    if (key.isDownKey) {
      final metadata = _fullMetadata ?? widget.metadata;
      if (metadata.role != null && metadata.role!.isNotEmpty) {
        _castFocusNode.requestFocus();
        _scrollSectionIntoView(_castSectionKey);
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// Build horizontal seasons list for larger screens (>=600px)
  /// Uses locked focus pattern for D-pad centered scrolling
  Widget _buildHorizontalSeasons() {
    final cardWidth = _getResponsiveCardWidth();
    final posterHeight = (cardWidth - 16) * 1.5;
    final containerHeight = posterHeight + 66;

    final hasFocus = _seasonsFocusNode.hasFocus;

    return Focus(
      focusNode: _seasonsFocusNode,
      onKeyEvent: _handleSeasonsKeyEvent,
      child: SizedBox(
        height: containerHeight,
        child: HorizontalScrollWithArrows(
          controller: _seasonsScrollController,
          builder: (scrollController) => ListView.builder(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
            itemCount: _seasons.length,
            itemBuilder: (context, index) {
              final season = _seasons[index];
              final isFocused = hasFocus && index == _focusedSeasonIndex;
              // Get or create a GlobalKey for this season card
              final cardKey = _seasonCardKeys.putIfAbsent(index, () => GlobalKey<MediaCardState>());

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FocusBuilders.buildLockedFocusWrapper(
                  context: context,
                  isFocused: isFocused,
                  onTap: () => _navigateToSeason(season),
                  child: MediaCard(
                    key: cardKey,
                    item: season,
                    width: cardWidth,
                    height: posterHeight,
                    forceGridMode: true,
                    isOffline: widget.isOffline,
                    onRefresh: (_) {
                      _watchStateChanged = true;
                      _updateWatchState();
                    },
                    onListRefresh: () {
                      if (widget.isOffline) {
                        _loadSeasonsFromDownloads();
                      } else {
                        _loadSeasons();
                      }
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }


  /// Handle key events for the cast row (locked focus pattern)
  KeyEventResult _handleCastKeyEvent(FocusNode _, KeyEvent event) {
    final key = event.logicalKey;
    if (key.isBackKey) return KeyEventResult.ignored;
    if (!event.isActionable) return KeyEventResult.ignored;

    final metadata = _fullMetadata ?? widget.metadata;
    final roleCount = metadata.role?.length ?? 0;
    final disableAnims = context.read<SettingsProvider>().disableAnimations;

    // LEFT: previous cast member
    if (key.isLeftKey) {
      if (_focusedCastIndex > 0) {
        setState(() => _focusedCastIndex--);
        scrollListToIndex(_castScrollController, _focusedCastIndex, itemExtent: 120.0 + 4, disableAnimations: disableAnims);
      }
      return KeyEventResult.handled;
    }

    // RIGHT: next cast member
    if (key.isRightKey) {
      if (_focusedCastIndex < roleCount - 1) {
        setState(() => _focusedCastIndex++);
        scrollListToIndex(_castScrollController, _focusedCastIndex, itemExtent: 120.0 + 4, disableAnimations: disableAnims);
      }
      return KeyEventResult.handled;
    }

    // UP: seasons → overview → play button
    if (key.isUpKey) {
      if (metadata.isShow && _seasons.isNotEmpty) {
        _seasonsFocusNode.requestFocus();
        _scrollSectionIntoView(_seasonsSectionKey);
      } else if (metadata.summary != null || metadata.studio != null || metadata.contentRating != null) {
        _overviewFocusNode.requestFocus();
        _scrollSectionIntoView(_overviewSectionKey);
      } else {
        if (disableAnims) {
          _scrollController.jumpTo(0);
        } else {
          _scrollController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        }
        _playButtonFocusNode.requestFocus();
      }
      return KeyEventResult.handled;
    }

    // DOWN: similar items (if available) → consume
    if (key.isDownKey) {
      if (_similarItems != null && _similarItems!.isNotEmpty) {
        _similarItemsFocusNode.requestFocus();
        _scrollSectionIntoView(_similarSectionKey);
      }
      return KeyEventResult.handled;
    }

    // SELECT: navigate to person detail (TV/remote)
    if (key.isSelectKey) {
      if (event is KeyDownEvent && _focusedCastIndex < roleCount) {
        final actor = metadata.role![_focusedCastIndex];
        final client = _getClientForMetadata(context);
        if (client != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PersonDetailScreen(
                actor: actor,
                client: client,
                serverId: widget.metadata.serverId ?? '',
              ),
            ),
          );
        }
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// Handle key events for the similar items row (locked focus pattern)
  KeyEventResult _handleSimilarItemsKeyEvent(FocusNode _, KeyEvent event) {
    final key = event.logicalKey;
    if (key.isBackKey) return KeyEventResult.ignored;
    if (!event.isActionable) return KeyEventResult.ignored;
    if (_similarItems == null || _similarItems!.isEmpty) return KeyEventResult.ignored;

    final disableAnims = context.read<SettingsProvider>().disableAnimations;

    // LEFT
    if (key.isLeftKey) {
      if (_focusedSimilarIndex > 0) {
        setState(() => _focusedSimilarIndex--);
        scrollListToIndex(_similarItemsScrollController, _focusedSimilarIndex, itemExtent: _getResponsiveCardWidth() + 4, disableAnimations: disableAnims);
      }
      return KeyEventResult.handled;
    }

    // RIGHT
    if (key.isRightKey) {
      if (_focusedSimilarIndex < _similarItems!.length - 1) {
        setState(() => _focusedSimilarIndex++);
        scrollListToIndex(_similarItemsScrollController, _focusedSimilarIndex, itemExtent: _getResponsiveCardWidth() + 4, disableAnimations: disableAnims);
      }
      return KeyEventResult.handled;
    }

    // UP: cast → seasons → overview → play button
    if (key.isUpKey) {
      final metadata = _fullMetadata ?? widget.metadata;
      if (metadata.role != null && metadata.role!.isNotEmpty) {
        _castFocusNode.requestFocus();
        _scrollSectionIntoView(_castSectionKey);
      } else if (metadata.isShow && _seasons.isNotEmpty) {
        _seasonsFocusNode.requestFocus();
        _scrollSectionIntoView(_seasonsSectionKey);
      } else if (metadata.summary != null || metadata.studio != null || metadata.contentRating != null) {
        _overviewFocusNode.requestFocus();
        _scrollSectionIntoView(_overviewSectionKey);
      } else {
        if (disableAnims) {
          _scrollController.jumpTo(0);
        } else {
          _scrollController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        }
        _playButtonFocusNode.requestFocus();
      }
      return KeyEventResult.handled;
    }

    // DOWN: consume (nothing below similar items)
    if (key.isDownKey) {
      return KeyEventResult.handled;
    }

    // SELECT: open the focused similar item
    if (key.isSelectKey) {
      if (event is KeyDownEvent) {
        _similarCardKeys[_focusedSimilarIndex]?.currentState?.handleTap();
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// Build vertical seasons list for smaller screens (<600px)
  Widget _buildVerticalSeasons() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: _seasons.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final season = _seasons[index];
        // Look up each season's artwork, not the show's
        String? seasonPosterPath;
        if (widget.isOffline && season.serverId != null) {
          seasonPosterPath = context.read<DownloadProvider>().getArtworkLocalPath(season.serverId!, season.thumb);
        }
        return _SeasonCard(
          season: season,
          client: _getClientForMetadata(context),
          isOffline: widget.isOffline,
          localPosterPath: seasonPosterPath,
          onTap: () => _navigateToSeason(season),
          onRefresh: () {
            _watchStateChanged = true;
            _updateWatchState();
          },
          onListRefresh: () {
            if (widget.isOffline) {
              _loadSeasonsFromDownloads();
            } else {
              _loadSeasons();
            }
          },
        );
      },
    );
  }

  /// Load the next unwatched episode for offline mode
  Future<void> _loadOfflineNextEpisode() async {
    final offlineWatchProvider = context.read<OfflineWatchProvider>();
    final nextEpisode = await offlineWatchProvider.getNextUnwatchedEpisode(widget.metadata.itemId);

    if (nextEpisode != null && mounted) {
      setState(() {
        _nextEpisode = nextEpisode;
      });
      appLogger.d('Offline next episode: S${nextEpisode.parentIndex}E${nextEpisode.index} - ${nextEpisode.title}');
    }
  }

  /// Update watch state without full screen rebuild
  /// This preserves scroll position and only updates watch-related data
  Future<void> _updateWatchState() async {
    // Skip in offline mode
    if (widget.isOffline) return;

    try {
      // Use server-specific client for this metadata
      final client = _getClientForMetadata(context);
      if (client == null) return;

      final metadata = await client.getMetadataWithImages(widget.metadata.itemId);

      if (metadata != null) {
        // Preserve serverId from original metadata
        final metadataWithServerId = metadata.copyWith(
          serverId: widget.metadata.serverId,
          serverName: widget.metadata.serverName,
        );

        // For shows, also refetch seasons to update their watch counts
        List<MediaMetadata>? updatedSeasons;
        if (metadata.isShow) {
          final seasons = await client.getChildren(widget.metadata.itemId);
          // Preserve serverId for each season
          updatedSeasons = seasons
              .map(
                (season) => season.copyWith(serverId: widget.metadata.serverId, serverName: widget.metadata.serverName),
              )
              .toList();
        }

        // Single setState to minimize rebuilds - scroll position is preserved by controller
        if (!mounted) return;
        setState(() {
          _fullMetadata = metadataWithServerId;
          if (updatedSeasons != null) {
            _seasons = updatedSeasons;
          }
        });
      }
    } catch (e) {
      appLogger.e('Failed to update watch state', error: e);
      // Silently fail - user can manually refresh if needed
    }
  }

  Future<void> _playFirstEpisode() async {
    try {
      // If seasons aren't loaded yet, wait for them or load them
      if (_seasons.isEmpty && !_isLoadingSeasons) {
        if (widget.isOffline) {
          _loadSeasonsFromDownloads();
        } else {
          await _loadSeasons();
        }
      }

      // Wait for seasons to finish loading if they're currently loading
      while (_isLoadingSeasons) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (!mounted) return;

      if (_seasons.isEmpty) {
        if (mounted) {
          showErrorSnackBar(context, t.messages.noSeasonsFound);
        }
        return;
      }

      // Get the first season (usually Season 1, but could be Season 0 for specials)
      final firstSeason = _seasons.first;

      // Get episodes of the first season
      List<MediaMetadata> episodes;
      if (!mounted) return;
      if (widget.isOffline) {
        // In offline mode, get episodes from downloads
        final downloadProvider = context.read<DownloadProvider>();
        final allEpisodes = downloadProvider.getDownloadedEpisodesForShow(widget.metadata.itemId);
        // Filter to episodes of this season
        episodes = allEpisodes.where((ep) => ep.parentIndex == firstSeason.index).toList()
          ..sort((a, b) => (a.index ?? 0).compareTo(b.index ?? 0));
      } else {
        final client = _getClientForMetadata(context);
        if (client == null) return;
        episodes = await client.getChildren(firstSeason.itemId);
      }

      if (episodes.isEmpty) {
        if (mounted) {
          showErrorSnackBar(context, t.messages.noEpisodesFound);
        }
        return;
      }

      // Play the first episode
      final firstEpisode = episodes.first;
      // Preserve serverId for the episode
      final episodeWithServerId = firstEpisode.copyWith(
        serverId: widget.metadata.serverId,
        serverName: widget.metadata.serverName,
      );
      if (mounted) {
        appLogger.d('Playing first episode: ${episodeWithServerId.title}');
        await navigateToVideoPlayerWithRefresh(
          context,
          metadata: episodeWithServerId,
          isOffline: widget.isOffline,
          onRefresh: _loadFullMetadata,
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, t.messages.errorLoading(error: e.toString()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use full metadata if loaded, otherwise use passed metadata
    final metadata = _fullMetadata ?? widget.metadata;
    final isShow = metadata.isShow;
    final isMobile = PlatformDetector.isMobile(context);
    final isTv = PlatformDetector.isTV();

    KeyEventResult handleBack(FocusNode _, KeyEvent event) =>
        handleBackOrLeftKeyNavigation(context, event, result: _watchStateChanged);

    // Show loading state while fetching full metadata
    if (_isLoadingMetadata) {
      final loading = Focus(
        onKeyEvent: handleBack,
        child: Scaffold(
          appBar: AppBar(),
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
      final blockSystemBack = Platform.isAndroid && InputModeTracker.isKeyboardMode(context);
      if (!blockSystemBack) {
        return loading;
      }
      return PopScope(
        canPop: false, // Prevent system back from double-popping on Android keyboard/TV
        // ignore: no-empty-block - required callback, blocks system back on Android TV
        onPopInvokedWithResult: (didPop, result) {},
        child: loading,
      );
    }

    // Determine header height based on screen size
    final size = MediaQuery.of(context).size;
    final headerHeight = size.height * 0.6;

    final content = Focus(
      onKeyEvent: handleBack,
      child: Scaffold(
        body: Stack(
          children: [
            CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Hero header with background art
                SliverToBoxAdapter(
                  child: Stack(
                    children: [
                      // Background Art (fixed height, no parallax)
                      SizedBox(
                        height: headerHeight,
                        width: double.infinity,
                        child: metadata.art != null
                            ? Builder(
                                builder: (context) {
                                  // Check for offline local file first
                                  if (widget.isOffline && widget.metadata.serverId != null) {
                                    final localPath = context.read<DownloadProvider>().getArtworkLocalPath(
                                      widget.metadata.serverId!,
                                      metadata.art,
                                    );
                                    if (localPath != null && File(localPath).existsSync()) {
                                      return Image.file(
                                        File(localPath),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => const PlaceholderContainer(),
                                      );
                                    }
                                    // Offline but no local file - show placeholder
                                    return const PlaceholderContainer();
                                  }

                                  // Online - use network image
                                  final client = _getClientForMetadata(context);
                                  final mediaQuery = MediaQuery.of(context);
                                  final dpr = MediaImageHelper.effectiveDevicePixelRatio(context);
                                  final imageUrl = MediaImageHelper.getOptimizedImageUrl(
                                    client: client,
                                    thumbPath: metadata.art,
                                    maxWidth: mediaQuery.size.width,
                                    maxHeight: mediaQuery.size.height * 0.6,
                                    devicePixelRatio: dpr,
                                    imageType: ImageType.art,
                                  );

                                  return blurArtwork(CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const PlaceholderContainer(),
                                    errorWidget: (context, url, error) => const PlaceholderContainer(),
                                  ));
                                },
                              )
                            : const PlaceholderContainer(),
                      ),

                      // Gradient overlay (IgnorePointer so back button receives taps)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        bottom: -1, // Extend 1px past to prevent subpixel gap
                        child: IgnorePointer(
                          child: Builder(
                            builder: (context) {
                              final bgColor = Theme.of(context).scaffoldBackgroundColor;
                              return Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, bgColor.withValues(alpha: 0.9), bgColor],
                                    stops: const [0.3, 0.8, 1.0],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // Content at bottom
                      Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Clear logo or title
                                if (metadata.clearLogo != null)
                                  SizedBox(
                                    height: 120,
                                    width: 400,
                                    child: Builder(
                                      builder: (context) {
                                        // Check for offline local file first
                                        if (widget.isOffline && widget.metadata.serverId != null) {
                                          final localPath = context.read<DownloadProvider>().getArtworkLocalPath(
                                            widget.metadata.serverId!,
                                            metadata.clearLogo,
                                          );
                                          if (localPath != null && File(localPath).existsSync()) {
                                            return Image.file(
                                              File(localPath),
                                              fit: BoxFit.contain,
                                              alignment: Alignment.centerLeft,
                                              errorBuilder: (context, error, stackTrace) =>
                                                  _buildTitleText(context, metadata.title),
                                            );
                                          }
                                          // Offline but no local file - show title text
                                          return _buildTitleText(context, metadata.title);
                                        }

                                        // Online - use network image
                                        final client = _getClientForMetadata(context);
                                        final dpr = MediaImageHelper.effectiveDevicePixelRatio(context);
                                        final logoUrl = MediaImageHelper.getOptimizedImageUrl(
                                          client: client,
                                          thumbPath: metadata.clearLogo,
                                          maxWidth: 400,
                                          maxHeight: 120,
                                          devicePixelRatio: dpr,
                                          imageType: ImageType.logo,
                                        );

                                        return blurArtwork(CachedNetworkImage(
                                          imageUrl: logoUrl,
                                          filterQuality: FilterQuality.medium,
                                          fit: BoxFit.contain,
                                          alignment: Alignment.centerLeft,
                                          memCacheWidth: (400 * dpr).clamp(200, 800).round(),
                                          placeholder: (context, url) => Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              metadata.title,
                                              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                                color: Colors.white.withValues(alpha: 0.3),
                                                fontWeight: FontWeight.bold,
                                                shadows: [
                                                  Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 8),
                                                ],
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          errorWidget: (context, url, error) {
                                            return _buildTitleText(context, metadata.title);
                                          },
                                        ), sigma: 10, clip: false);
                                      },
                                    ),
                                  )
                                else
                                  Text(
                                    metadata.title,
                                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      shadows: [Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 8)],
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const SizedBox(height: 12),

                                // Metadata chips
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (metadata.year != null) _buildMetadataChip('${metadata.year}'),
                                    if (metadata.contentRating != null)
                                      _buildMetadataChip(formatContentRating(metadata.contentRating!)),
                                    if (metadata.duration != null)
                                      _buildMetadataChip(formatDurationTextual(metadata.duration!)),
                                    if (isShow &&
                                        metadata.effectiveUnwatchedCount != null &&
                                        metadata.effectiveUnwatchedCount! > 0)
                                      _buildMetadataChip(
                                        '${metadata.effectiveUnwatchedCount!} ${t.accessibility.mediaCardUnwatched}',
                                      ),
                                    ..._buildRatingChips(metadata),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Action buttons
                                _buildActionButtons(metadata),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Back button last so it's always on top (hover + tap work)
                      Positioned(
                        top: 0,
                        left: 0,
                        child: FocusableAppBarBackButton(
                          focusNode: _backButtonFocusNode,
                          onKeyEvent: _handleBackButtonKeyEvent,
                          onPressed: () => Navigator.pop(context, _watchStateChanged),
                          useAdjustedLeading: true,
                        ),
                      ),
                    ],
                  ),
                ),

                // Main content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (metadata.summary != null || metadata.studio != null || metadata.contentRating != null) ...[
                          Focus(
                            focusNode: _overviewFocusNode,
                            onKeyEvent: _handleOverviewKeyEvent,
                            child: ListenableBuilder(
                              listenable: _overviewFocusNode,
                              builder: (context, _) {
                                final focused = _overviewFocusNode.hasFocus;
                                return Container(
                                  key: _overviewSectionKey,
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                                    border: focused
                                        ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                                        : null,
                                    color: focused
                                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
                                        : null,
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (metadata.summary != null) ...[
                                        Text(
                                          t.discover.overview,
                                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 12),
                                        isTv
                                            ? Text(
                                                metadata.summary!,
                                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
                                              )
                                            : CollapsibleText(
                                                text: metadata.summary!,
                                                maxLines: focused ? 100 : (isMobile ? 6 : 4),
                                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
                                              ),
                                      ],
                                      if (metadata.studio != null) ...[
                                        if (metadata.summary != null) const SizedBox(height: 16),
                                        _buildInfoRow(t.discover.studio, metadata.studio!),
                                      ],
                                      if (metadata.contentRating != null) ...[
                                        const SizedBox(height: 12),
                                        _buildInfoRow(t.discover.rating, formatContentRating(metadata.contentRating!)),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Seasons (for TV shows)
                        if (isShow) ...[
                          Row(
                            key: _seasonsSectionKey,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                t.discover.seasons,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              if (metadata.effectiveUnwatchedCount != null &&
                                  metadata.effectiveUnwatchedCount! > 0) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '${metadata.effectiveUnwatchedCount!} ${t.accessibility.mediaCardUnwatched}',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_isLoadingSeasons)
                            const Center(
                              child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()),
                            )
                          else if (_seasons.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(32),
                              child: Center(
                                child: Text(
                                  t.messages.noSeasonsFound,
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                                ),
                              ),
                            )
                          else if (size.width >= 600)
                            _buildHorizontalSeasons()
                          else
                            _buildVerticalSeasons(),
                          const SizedBox(height: 24),
                        ],

                        // Cast
                        if (metadata.role != null && metadata.role!.isNotEmpty) ...[
                          Text(
                            key: _castSectionKey,
                            t.discover.cast,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          _buildCastSection(metadata),
                          const SizedBox(height: 24),
                        ],

                        // More Like This
                        if (_similarItems != null && _similarItems!.isNotEmpty) ...[
                          Text(
                            key: _similarSectionKey,
                            t.discover.moreLikeThis,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          _buildSimilarItemsSection(),
                          const SizedBox(height: 24),
                        ],
                      ],
                    ),
                  ),
                ),
                SliverPadding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom)),
              ],
            ),
            // Sticky top bar with fading background
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: _scrollOffset < 50,
                child: AnimatedOpacity(
                  opacity: (_scrollOffset / 100).clamp(0.0, 1.0),
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    height: MediaQuery.of(context).padding.top + 58,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.8),
                          Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5),
                          Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0),
                        ],
                        stops: const [0.0, 0.3, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final blockSystemBack = Platform.isAndroid && InputModeTracker.isKeyboardMode(context);
    if (!blockSystemBack) {
      return content;
    }

    return PopScope(
      canPop: false, // Prevent system back from double-popping on Android keyboard/TV
      // ignore: no-empty-block - required callback, blocks system back on Android TV
      onPopInvokedWithResult: (didPop, result) {},
      child: content,
    );
  }

  /// Get the primary trailer from the extras list
  MediaMetadata? _getPrimaryTrailer() {
    if (_extras == null || _extras!.isEmpty) return null;

    // If there's a primaryExtraKey, try to find that specific trailer
    final metadata = _fullMetadata ?? widget.metadata;
    if (metadata.primaryExtraKey != null) {
        // Extract item ID from primaryExtraKey (e.g., "/items/52601" -> "52601")
      final primaryKey = metadata.primaryExtraKey!.split('/').last;
      try {
        return _extras!.firstWhere((extra) => extra.itemId == primaryKey);
      } catch (_) {
        // Primary key not found, fall through to find any trailer
      }
    }

    // Otherwise, find the first item with subtype 'trailer'
    try {
      return _extras!.firstWhere((extra) => extra.subtype == 'trailer');
    } catch (_) {
      // No trailer found, return null (button won't appear)
      return null;
    }
  }

  /// Build the cast section with locked focus pattern for D-pad navigation
  /// Uses same layout pattern as seasons/extras (ListView.builder + Padding(horizontal: 2))
  Widget _buildCastSection(MediaMetadata metadata) {
    const cardWidth = 120.0;
    const innerPadding = 6.0;
    // image + inner padding + text area + outer list padding + focus scale headroom
    const containerHeight = 120.0 + innerPadding * 2 + 66 + 16;

    final hasFocus = _castFocusNode.hasFocus;

    return Focus(
      focusNode: _castFocusNode,
      onKeyEvent: _handleCastKeyEvent,
      onFocusChange: (_) => setState(() {}),
      child: SizedBox(
        height: containerHeight,
        child: HorizontalScrollWithArrows(
          controller: _castScrollController,
          builder: (scrollController) => ListView.builder(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
            itemCount: metadata.role!.length,
            itemBuilder: (context, index) {
              final actor = metadata.role![index];
              final isFocused = hasFocus && index == _focusedCastIndex;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: GestureDetector(
                  onTap: () {
                    final client = _getClientForMetadata(context);
                    if (client == null) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PersonDetailScreen(
                          actor: actor,
                          client: client,
                          serverId: widget.metadata.serverId ?? '',
                        ),
                      ),
                    );
                  },
                  child: FocusBuilders.buildLockedFocusWrapper(
                    context: context,
                    isFocused: isFocused,
                    borderRadius: tokens(context).radiusSm,
                    child: Padding(
                      padding: const EdgeInsets.all(innerPadding),
                      child: SizedBox(
                        width: cardWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(tokens(context).radiusSm),
                              child: OptimizedImage(
                                client: _getClientForMetadata(context),
                                imagePath: actor.thumb,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                                imageType: ImageType.avatar,
                                fallbackIcon: Symbols.person_rounded,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    actor.tag,
                                    style:
                                        Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (actor.role != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      actor.role!,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSimilarItemsSection() {
    final cardWidth = _getResponsiveCardWidth();
    final posterHeight = (cardWidth - 16) * 1.5;
    final containerHeight = posterHeight + 66;

    final hasFocus = _similarItemsFocusNode.hasFocus;

    return Focus(
      focusNode: _similarItemsFocusNode,
      onKeyEvent: _handleSimilarItemsKeyEvent,
      child: SizedBox(
        height: containerHeight,
        child: HorizontalScrollWithArrows(
          controller: _similarItemsScrollController,
          builder: (scrollController) => ListView.builder(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
            itemCount: _similarItems!.length,
            itemBuilder: (context, index) {
              final item = _similarItems![index];
              final isFocused = hasFocus && index == _focusedSimilarIndex;
              final cardKey = _similarCardKeys.putIfAbsent(index, () => GlobalKey<MediaCardState>());

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FocusBuilders.buildLockedFocusWrapper(
                  context: context,
                  isFocused: isFocused,
                  child: MediaCard(
                    key: cardKey,
                    item: item,
                    width: cardWidth,
                    height: posterHeight,
                    forceGridMode: true,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
        Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyLarge)),
      ],
    );
  }

  String _getPlayButtonLabel(MediaMetadata metadata) {
    // For TV shows - use compact S1E1 format
    if (metadata.isShow) {
      if (_nextEpisode != null) {
        final episode = _nextEpisode!;
        final seasonNum = episode.parentIndex ?? 0;
        final episodeNum = episode.index ?? 0;

        // Use the same format for both play and resume
        // (icon will indicate the difference)
        return t.discover.playEpisode(season: seasonNum.toString(), episode: episodeNum.toString());
      } else {
        // No next episode, will play first episode
        return t.discover.playEpisode(season: '1', episode: '1');
      }
    }

    // For movies or episodes - NO TEXT, just icon
    return '';
  }

  IconData _getPlayButtonIcon(MediaMetadata metadata) {
    // For TV shows
    if (metadata.isShow) {
      if (_nextEpisode != null) {
        final episode = _nextEpisode!;
        // Check if episode has been partially watched
        if (episode.resumePositionMs != null && episode.resumePositionMs! > 0) {
          return Symbols.resume_rounded; // Resume icon
        }
      }
    } else {
      // For movies or episodes
      if (metadata.resumePositionMs != null && metadata.resumePositionMs! > 0) {
        return Symbols.resume_rounded; // Resume icon
      }
    }

    return Symbols.play_arrow_rounded; // Default play icon
  }
}

/// Season card widget with D-pad long-press support
class _SeasonCard extends StatefulWidget {
  final MediaMetadata season;
  final JellyfinClient? client;
  final VoidCallback onTap;
  final VoidCallback onRefresh;
  final VoidCallback? onListRefresh;
  final bool isOffline;
  final String? localPosterPath;

  const _SeasonCard({
    required this.season,
    this.client,
    required this.onTap,
    required this.onRefresh,
    this.onListRefresh,
    this.isOffline = false,
    this.localPosterPath,
  });

  @override
  State<_SeasonCard> createState() => _SeasonCardState();
}

class _SeasonCardState extends State<_SeasonCard> {
  final _contextMenuKey = GlobalKey<MediaContextMenuState>();

  void _showContextMenu() {
    _contextMenuKey.currentState?.showContextMenu(context);
  }

  @override
  Widget build(BuildContext context) {
    return FocusableWrapper(
      enableLongPress: true,
      onSelect: widget.onTap,
      onLongPress: _showContextMenu,
      borderRadius: 12, // Match card border radius
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: MediaContextMenu(
          key: _contextMenuKey,
          item: widget.season,
          onRefresh: (itemId) => widget.onRefresh(),
          onListRefresh: widget.onListRefresh,
          onTap: widget.onTap,
          child: Semantics(
            label: "media-season-${widget.season.itemId}",
            identifier: "media-season-${widget.season.itemId}",
            button: true,
            hint: "Tap to view ${widget.season.title}",
            child: InkWell(
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Season poster
                    ClipRRect(borderRadius: const BorderRadius.all(Radius.circular(6)), child: _buildSeasonPoster()),
                    const SizedBox(width: 16),

                    // Season info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.season.title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          if (widget.season.leafCount != null)
                            Text(
                              t.discover.episodeCount(count: widget.season.leafCount.toString()),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                            ),
                          if (widget.season.userRating != null && widget.season.userRating! > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Symbols.star_rounded, size: 14, fill: 1, color: Colors.amber)),
                                const SizedBox(width: 3),
                                Text(
                                  (widget.season.userRating! / 2) == (widget.season.userRating! / 2).truncateToDouble()
                                      ? '${(widget.season.userRating! / 2).toInt()}'
                                      : (widget.season.userRating! / 2).toStringAsFixed(1),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                          // Hide watch progress when offline (not tracked)
                          if (!widget.isOffline) ...[
                            const SizedBox(height: 8),
                            if (widget.season.watchedEpisodeCount != null && widget.season.leafCount != null)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 200,
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                                      child: LinearProgressIndicator(
                                        value: widget.season.watchedEpisodeCount! / widget.season.leafCount!,
                                        backgroundColor: tokens(context).outline,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Theme.of(context).colorScheme.primary,
                                        ),
                                        minHeight: 6,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    t.discover.watchedProgress(
                                      watched: widget.season.watchedEpisodeCount.toString(),
                                      total: widget.season.leafCount.toString(),
                                    ),
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                                  ),
                                ],
                              ),
                          ],
                        ],
                      ),
                    ),

                    const AppIcon(Symbols.chevron_right_rounded, fill: 1),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSeasonPoster() {
    if (widget.isOffline && widget.localPosterPath != null) {
      return Image.file(
        File(widget.localPosterPath!),
        width: 80,
        height: 120,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 80,
          height: 120,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const AppIcon(Symbols.movie_rounded, fill: 1, size: 32),
        ),
      );
    }
    if (widget.season.thumb != null) {
      return OptimizedImage.poster(
        client: widget.client,
        imagePath: widget.season.thumb,
        width: 80,
        height: 120,
        fit: BoxFit.cover,
        placeholder: (context, url) =>
            Container(width: 80, height: 120, color: Theme.of(context).colorScheme.surfaceContainerHighest),
        errorWidget: (context, url, error) => Container(
          width: 80,
          height: 120,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const AppIcon(Symbols.movie_rounded, fill: 1, size: 32),
        ),
      );
    }
    return Container(
      width: 80,
      height: 120,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const AppIcon(Symbols.movie_rounded, fill: 1, size: 32),
    );
  }
}

