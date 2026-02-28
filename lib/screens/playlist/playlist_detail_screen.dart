import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../services/jellyfin_client.dart';
import '../../models/playlist.dart';
import '../../models/media_metadata.dart';
import '../../utils/provider_extensions.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/desktop_app_bar.dart';
import '../../focus/input_mode_tracker.dart';
import '../../focus/key_event_utils.dart';
import '../../i18n/strings.g.dart';
import '../../utils/dialogs.dart';
import '../../utils/snackbar_helper.dart';
import '../base_media_list_detail_screen.dart';
import '../focusable_detail_screen_mixin.dart';
import '../../mixins/grid_focus_node_mixin.dart';

/// Screen to display the contents of a playlist
class PlaylistDetailScreen extends StatefulWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends BaseMediaListDetailScreen<PlaylistDetailScreen>
    with
        StandardItemLoader<PlaylistDetailScreen>,
        GridFocusNodeMixin<PlaylistDetailScreen>,
        FocusableDetailScreenMixin<PlaylistDetailScreen> {
  @override
  dynamic get mediaItem => widget.playlist;

  @override
  String get title => widget.playlist.title;

  @override
  String get emptyMessage => t.playlists.emptyPlaylist;

  @override
  IconData get emptyIcon => Symbols.playlist_play_rounded;

  @override
  bool get hasItems => items.isNotEmpty;

  @override
  int get appBarButtonCount {
    int count = 0;
    if (items.isNotEmpty) count += 2; // play + shuffle
    if (!widget.playlist.smart) count += 1; // delete
    return count;
  }

  @override
  List<AppBarButtonConfig> getAppBarButtons() {
    final buttons = <AppBarButtonConfig>[];
    if (items.isNotEmpty) {
      buttons.add(AppBarButtonConfig(icon: Symbols.play_arrow_rounded, tooltip: t.common.play, onPressed: playItems));
      buttons.add(
        AppBarButtonConfig(icon: Symbols.shuffle_rounded, tooltip: t.common.shuffle, onPressed: shufflePlayItems),
      );
    }
    if (!widget.playlist.smart) {
      buttons.add(
        AppBarButtonConfig(
          icon: Symbols.delete_rounded,
          tooltip: t.playlists.delete,
          onPressed: _deletePlaylist,
          color: Colors.red,
        ),
      );
    }
    return buttons;
  }

  // Focus management for regular (non-smart) reorderable lists
  final FocusNode _listFocusNode = FocusNode(debugLabel: 'playlist_list');

  // Move mode state
  int? _movingIndex;
  List<MediaMetadata>? _originalOrder;

  /// Fetched series metadata for show cards that lacked unwatched count (e.g. from playlist API).
  Map<String, MediaMetadata> _enrichedShowCounts = {};

  @override
  void dispose() {
    _listFocusNode.dispose();
    disposeFocusResources();
    super.dispose();
  }

  @override
  Future<List<MediaMetadata>> fetchItems() async {
    return await client.getPlaylist(widget.playlist.itemId);
  }

  @override
  Future<void> loadItems() async {
    setState(() => _enrichedShowCounts = {});
    await super.loadItems();

    // Enrich show cards that lack unwatched count (playlist API often omits UserData for items).
    if (mounted && items.isNotEmpty) await _enrichShowCounts();

    // Auto-focus after load if in keyboard mode
    if (mounted && items.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (InputModeTracker.isKeyboardMode(context)) {
          setState(() {
            isAppBarFocused = false;
          });
          firstItemFocusNode.requestFocus();
        }
      });
    }
  }

  @override
  String getLoadSuccessMessage(int itemCount) {
    return 'Loaded $itemCount items for playlist: ${widget.playlist.title}';
  }

  /// Navigate from app bar down to content
  @override
  void navigateToGrid() {
    if (!hasItems) return;
    super.navigateToGrid();
  }

  /// Get the correct JellyfinClient for this playlist's server
  JellyfinClient _getClientForPlaylist() {
    return context.getClientForServer(widget.playlist.serverId!);
  }

  /// Fetch series metadata for show cards that lack unwatched count so the badge can display.
  Future<void> _enrichShowCounts() async {
    if (!mounted || widget.playlist.serverId == null) return;
    final displayItems = _getGroupedDisplayItems();
    final toFetch = <String>[];
    for (final item in displayItems) {
      if (item.mediaType != MediaType.show) continue;
      if (item.effectiveUnwatchedCount != null) continue;
      final key = item.itemId;
      if (key.isEmpty || _enrichedShowCounts.containsKey(key)) continue;
      toFetch.add(key);
    }
    if (toFetch.isEmpty) return;
    final client = _getClientForPlaylist();
    final results = await Future.wait(
      toFetch.map((key) => client.getMetadataWithImages(key)),
    );
    if (!mounted) return;
    final Map<String, MediaMetadata> next = Map.from(_enrichedShowCounts);
    for (var i = 0; i < toFetch.length; i++) {
      final meta = results[i];
      if (meta != null) next[toFetch[i]] = meta;
    }
    if (next.length > _enrichedShowCounts.length) {
      setState(() => _enrichedShowCounts = next);
    }
  }

  /// Group playlist items by series so we show one card per show (and one per movie), matching Library Browse.
  /// Episodes are collapsed into their show; movies appear as-is. Order is first occurrence in playlist.
  List<MediaMetadata> _getGroupedDisplayItems() {
    final seenShowKeys = <String>{};
    final result = <MediaMetadata>[];
    for (final item in items) {
      if (item.mediaType == MediaType.episode || item.mediaType == MediaType.clip) {
        final showKey = item.seriesId ?? item.seasonId ?? item.itemId;
        if (showKey.isEmpty) continue;
        if (seenShowKeys.add(showKey)) {
          // Build synthetic show metadata from this episode so the card shows the series poster and title
          result.add(item.copyWith(
            itemId: showKey,
            key: showKey,
            type: 'show',
            title: item.seriesTitle ?? item.title,
            thumb: item.seriesImageId,
            art: item.seriesArt,
            seriesId: null,
            seriesTitle: null,
            seriesImageId: null,
            seriesArt: null,
            seasonId: null,
            seasonTitle: null,
            seasonImageId: null,
            parentIndex: null,
            index: null,
          ));
        }
      } else if (item.mediaType == MediaType.season) {
        // Group season under its show; preserve unwatched/leaf counts so badge can show
        final showKey = item.seasonId ?? item.itemId;
        if (showKey.isEmpty) continue;
        if (seenShowKeys.add(showKey)) {
          result.add(item.copyWith(
            itemId: showKey,
            key: showKey,
            type: 'show',
            title: item.seasonTitle ?? item.seriesTitle ?? item.title,
            thumb: item.seasonImageId ?? item.seriesImageId,
            art: item.seriesArt,
            seriesId: null,
            seriesTitle: null,
            seriesImageId: null,
            seriesArt: null,
            seasonId: null,
            seasonTitle: null,
            seasonImageId: null,
            parentIndex: null,
            index: null,
            unwatchedCount: item.unwatchedCount,
            leafCount: item.leafCount,
            watchedEpisodeCount: item.watchedEpisodeCount,
          ));
        }
      } else if (item.mediaType == MediaType.movie) {
        result.add(item);
      }
      // Other types (e.g. show already in playlist) add as-is
      else if (item.mediaType == MediaType.show) {
        if (seenShowKeys.add(item.itemId)) result.add(item);
      } else {
        result.add(item);
      }
    }
    // Merge enriched series metadata (unwatched count) when playlist API didn't provide it
    final merged = result.map((item) {
      if (item.mediaType != MediaType.show) return item;
      final enriched = _enrichedShowCounts[item.itemId];
      if (enriched == null) return item;
      final m = item.copyWith(
        unwatchedCount: enriched.unwatchedCount,
        leafCount: enriched.leafCount,
        watchedEpisodeCount: enriched.watchedEpisodeCount,
      );
      return m;
    }).toList();
    return merged;
  }

  Future<void> _deletePlaylist() async {
    final confirmed = await showDeleteConfirmation(
      context,
      title: t.playlists.deleteConfirm,
      message: t.playlists.deleteMessage(name: widget.playlist.title),
    );

    if (confirmed && mounted) {
      final success = await client.deletePlaylist(widget.playlist.itemId);

      if (mounted) {
        if (success) {
          showSuccessSnackBar(context, t.playlists.deleted);
          Navigator.pop(context); // Return to playlists screen
        } else {
          showErrorSnackBar(context, t.playlists.errorDeleting);
        }
      }
    }
  }

  /// Cancel move mode if active, returns true if cancelled
  bool _cancelMoveMode() {
    if (_movingIndex != null) {
      setState(() {
        if (_originalOrder != null) {
          items = List.from(_originalOrder!);
        }
        _movingIndex = null;
        _originalOrder = null;
      });
      return true;
    }
    return false;
  }

  /// Handle back navigation for PopScope - extends mixin with move mode support
  bool _handleBackNavigation() {
    // If BACK was already handled by a key event, don't pop
    if (backHandledByKeyEvent) {
      backHandledByKeyEvent = false;
      return false;
    }

    // If in move mode, cancel move instead of navigating
    if (_movingIndex != null) {
      _cancelMoveMode();
      return false;
    }

    return handleBackNavigation();
  }

  @override
  Widget build(BuildContext context) {
    // Grid uses its own focus nodes (firstItemFocusNode, getGridItemFocusNode)
    Widget scrollView = CustomScrollView(
      controller: scrollController,
      slivers: [
        CustomAppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.playlist.title, style: const TextStyle(fontSize: 16)),
              if (widget.playlist.smart)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon(Symbols.auto_awesome_rounded, fill: 1, size: 12, color: Colors.blue[300]),
                    const SizedBox(width: 4),
                    Text(
                      t.playlists.smartPlaylist,
                      style: TextStyle(fontSize: 11, color: Colors.blue[300], fontWeight: FontWeight.normal),
                    ),
                  ],
                ),
            ],
          ),
          actions: buildFocusableAppBarActions(),
        ),
        ...buildStateSlivers(),
        if (items.isNotEmpty)
          // Show series and movies as cards (same as Library Browse); episodes grouped by show
          buildFocusableGrid(
            items: _getGroupedDisplayItems(),
            onRefresh: updateItem,
          ),
      ],
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (BackKeyCoordinator.consumeIfHandled()) return;
        if (didPop) return;
        final shouldPop = _handleBackNavigation();
        if (shouldPop && mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(body: scrollView),
    );
  }
}
