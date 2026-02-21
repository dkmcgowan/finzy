import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../services/media_server_client.dart';
import '../../services/play_queue_launcher.dart';
import '../../models/plex_playlist.dart';
import '../../models/plex_metadata.dart';
import '../../utils/app_logger.dart';
import '../../utils/provider_extensions.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/desktop_app_bar.dart';
import '../../focus/dpad_navigator.dart';
import '../../focus/input_mode_tracker.dart';
import '../../focus/key_event_utils.dart';
import 'playlist_item_card.dart';
import '../../i18n/strings.g.dart';
import '../../utils/dialogs.dart';
import '../../utils/media_navigation_helper.dart';
import '../../utils/snackbar_helper.dart';
import '../base_media_list_detail_screen.dart';
import '../focusable_detail_screen_mixin.dart';
import '../../mixins/grid_focus_node_mixin.dart';

/// Screen to display the contents of a playlist
class PlaylistDetailScreen extends StatefulWidget {
  final PlexPlaylist playlist;

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

  // Navigation state for regular (non-smart) playlists
  int _focusedIndex = 0;
  int _focusedColumn = 0; // 0=content, 1=drag handle, 2=remove button

  // Move mode state
  int? _movingIndex;
  int? _originalIndex;
  List<PlexMetadata>? _originalOrder;

  // Estimated item height for scroll-into-view (card + vertical margins)
  static const double _estimatedItemHeight = 114.0;

  /// Fetched series metadata for show cards that lacked unwatched count (e.g. from playlist API).
  Map<String, PlexMetadata> _enrichedShowCounts = {};

  @override
  void dispose() {
    _listFocusNode.dispose();
    disposeFocusResources();
    super.dispose();
  }

  @override
  Future<List<PlexMetadata>> fetchItems() async {
    return await client.getPlaylist(widget.playlist.ratingKey);
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
            _focusedIndex = 0;
            _focusedColumn = 0;
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

  /// Get the correct MediaServerClient for this playlist's server
  MediaServerClient _getClientForPlaylist() {
    return context.getClientForServer(widget.playlist.serverId!);
  }

  /// Fetch series metadata for show cards that lack unwatched count so the badge can display.
  Future<void> _enrichShowCounts() async {
    if (!mounted || widget.playlist.serverId == null) return;
    final displayItems = _getGroupedDisplayItems();
    final toFetch = <String>[];
    for (final item in displayItems) {
      if (item.mediaType != PlexMediaType.show) continue;
      if (item.effectiveUnwatchedCount != null) continue;
      final key = item.ratingKey;
      if (key.isEmpty || _enrichedShowCounts.containsKey(key)) continue;
      toFetch.add(key);
    }
    if (toFetch.isEmpty) return;
    final client = _getClientForPlaylist();
    final results = await Future.wait(
      toFetch.map((key) => client.getMetadataWithImages(key)),
    );
    if (!mounted) return;
    final Map<String, PlexMetadata> next = Map.from(_enrichedShowCounts);
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
  List<PlexMetadata> _getGroupedDisplayItems() {
    final seenShowKeys = <String>{};
    final result = <PlexMetadata>[];
    for (final item in items) {
      if (item.mediaType == PlexMediaType.episode || item.mediaType == PlexMediaType.clip) {
        final showKey = item.grandparentRatingKey ?? item.parentRatingKey ?? item.ratingKey;
        if (showKey.isEmpty) continue;
        if (seenShowKeys.add(showKey)) {
          // Build synthetic show metadata from this episode so the card shows the series poster and title
          result.add(item.copyWith(
            ratingKey: showKey,
            key: showKey,
            type: 'show',
            title: item.grandparentTitle ?? item.title,
            thumb: item.grandparentThumb,
            art: item.grandparentArt,
            grandparentRatingKey: null,
            grandparentTitle: null,
            grandparentThumb: null,
            grandparentArt: null,
            parentRatingKey: null,
            parentTitle: null,
            parentThumb: null,
            parentIndex: null,
            index: null,
          ));
        }
      } else if (item.mediaType == PlexMediaType.season) {
        // Group season under its show; preserve unwatched/leaf counts so badge can show
        final showKey = item.parentRatingKey ?? item.ratingKey;
        if (showKey.isEmpty) continue;
        if (seenShowKeys.add(showKey)) {
          result.add(item.copyWith(
            ratingKey: showKey,
            key: showKey,
            type: 'show',
            title: item.parentTitle ?? item.grandparentTitle ?? item.title,
            thumb: item.parentThumb ?? item.grandparentThumb,
            art: item.grandparentArt,
            grandparentRatingKey: null,
            grandparentTitle: null,
            grandparentThumb: null,
            grandparentArt: null,
            parentRatingKey: null,
            parentTitle: null,
            parentThumb: null,
            parentIndex: null,
            index: null,
            unwatchedCount: item.unwatchedCount,
            leafCount: item.leafCount,
            viewedLeafCount: item.viewedLeafCount,
          ));
        }
      } else if (item.mediaType == PlexMediaType.movie) {
        result.add(item);
      }
      // Other types (e.g. show already in playlist) add as-is
      else if (item.mediaType == PlexMediaType.show) {
        if (seenShowKeys.add(item.ratingKey)) result.add(item);
      } else {
        result.add(item);
      }
    }
    // Merge enriched series metadata (unwatched count) when playlist API didn't provide it
    final merged = result.map((item) {
      if (item.mediaType != PlexMediaType.show) return item;
      final enriched = _enrichedShowCounts[item.ratingKey];
      if (enriched == null) return item;
      final m = item.copyWith(
        unwatchedCount: enriched.unwatchedCount,
        leafCount: enriched.leafCount,
        viewedLeafCount: enriched.viewedLeafCount,
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
      final success = await client.deletePlaylist(widget.playlist.ratingKey);

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

  /// Get the afterPlaylistItemId for reordering at the given index.
  /// Returns null if validation fails, showing an error if [showError] is true.
  int? _getAfterPlaylistItemId(int newIndex, {bool showError = true}) {
    if (newIndex == 0) return 0;
    final afterItem = items[newIndex - 1];
    if (afterItem.playlistItemID == null) {
      appLogger.e('Cannot reorder: after item missing playlistItemID');
      if (showError && mounted) showErrorSnackBar(context, t.playlists.errorReordering);
      return null;
    }
    return afterItem.playlistItemID!;
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    // Adjust newIndex if moving down in the list
    if (newIndex > oldIndex) {
      newIndex--;
    }

    // Can't reorder if indices are the same
    if (oldIndex == newIndex) return;

    final movedItem = items[oldIndex];

    // Check if item has playlistItemID (required for reordering)
    if (movedItem.playlistItemID == null) {
      appLogger.e('Cannot reorder: item missing playlistItemID');
      if (mounted) {
        showErrorSnackBar(context, t.playlists.errorReordering);
      }
      return;
    }

    // Determine the "after" item ID
    final afterPlaylistItemId = _getAfterPlaylistItemId(newIndex);
    if (afterPlaylistItemId == null) return;

    appLogger.d('Reordering item from $oldIndex to $newIndex (after ID: $afterPlaylistItemId)');

    // Optimistically update UI
    setState(() {
      final item = items.removeAt(oldIndex);
      items.insert(newIndex, item);
    });

    // Call API to persist the change
    final success = await client.movePlaylistItem(
      playlistId: widget.playlist.ratingKey,
      playlistItemId: movedItem.playlistItemID!,
      afterPlaylistItemId: afterPlaylistItemId,
    );

    if (!success) {
      // Revert on failure
      appLogger.e('Failed to reorder playlist item, reverting UI');
      if (mounted) {
        setState(() {
          final item = items.removeAt(newIndex);
          items.insert(oldIndex, item);
        });

        showErrorSnackBar(context, t.playlists.errorReordering);
      }
    }
  }

  /// Persist a move that was already done in the UI (during move mode).
  /// The item is already at newIndex in the items list.
  Future<void> _persistMoveToServer(int originalIndex, int newIndex) async {
    // Item is already at newIndex in the list
    final movedItem = items[newIndex];

    // Check if item has playlistItemID (required for reordering)
    if (movedItem.playlistItemID == null) {
      appLogger.e('Cannot persist move: item missing playlistItemID');
      if (mounted) {
        showErrorSnackBar(context, t.playlists.errorReordering);
        _revertMove(newIndex, originalIndex);
      }
      return;
    }

    // Determine the "after" item ID based on where the item is now
    final afterPlaylistItemId = _getAfterPlaylistItemId(newIndex, showError: false);
    if (afterPlaylistItemId == null) {
      if (mounted) {
        showErrorSnackBar(context, t.playlists.errorReordering);
        _revertMove(newIndex, originalIndex);
      }
      return;
    }

    appLogger.d('Persisting move from $originalIndex to $newIndex (after ID: $afterPlaylistItemId)');

    // Call API to persist the change (UI is already updated)
    final success = await client.movePlaylistItem(
      playlistId: widget.playlist.ratingKey,
      playlistItemId: movedItem.playlistItemID!,
      afterPlaylistItemId: afterPlaylistItemId,
    );

    if (!success) {
      // Revert on failure
      appLogger.e('Failed to persist move, reverting UI');
      if (mounted) {
        _revertMove(newIndex, originalIndex);
        showErrorSnackBar(context, t.playlists.errorReordering);
      }
    }
  }

  /// Revert a move in the UI by moving item from [fromIndex] back to [toIndex].
  void _revertMove(int fromIndex, int toIndex) {
    setState(() {
      final item = items.removeAt(fromIndex);
      items.insert(toIndex, item);
      _focusedIndex = toIndex;
    });
  }

  Future<void> _removeItem(int index) async {
    final item = items[index];

    // Check if item has playlistItemID (required for removal)
    if (item.playlistItemID == null) {
      appLogger.e('Cannot remove: item missing playlistItemID');
      if (mounted) {
        showErrorSnackBar(context, t.playlists.errorRemoving);
      }
      return;
    }

    appLogger.d('Removing item ${item.title} (playlistItemID: ${item.playlistItemID}) from playlist');

    // Optimistically update UI
    setState(() {
      items.removeAt(index);
    });

    // Call API to persist the change
    final success = await client.removeFromPlaylist(
      playlistId: widget.playlist.ratingKey,
      playlistItemId: item.playlistItemID.toString(),
    );

    if (mounted) {
      if (success) {
        showSuccessSnackBar(context, t.playlists.itemRemoved);
      } else {
        // Revert on failure
        appLogger.e('Failed to remove playlist item, reverting UI');
        setState(() {
          items.insert(index, item);
        });

        showErrorSnackBar(context, t.playlists.errorRemoving);
      }
    }
  }

  /// Handle tap on a playlist item: show detail for show/season/movie (same as Browse), play for episode/clip.
  Future<void> _onPlaylistItemTap(int index) async {
    if (items.isEmpty || index < 0 || index >= items.length) return;

    final item = items[index];
    final mediaType = item.mediaType;

    // For episode or clip, start playback from this item in the playlist
    if (mediaType == PlexMediaType.episode || mediaType == PlexMediaType.clip) {
      final plexClient = _getClientForPlaylist();
      final launcher = PlayQueueLauncher(
        context: context,
        client: plexClient,
        serverId: widget.playlist.serverId,
        serverName: widget.playlist.serverName,
      );
      await launcher.launchFromPlaylistItem(
        playlist: widget.playlist,
        selectedItem: item,
        showLoadingIndicator: true,
      );
      return;
    }

    // For show, season, or movie, navigate to the same detail view as Library Browse
    await navigateToMediaItem(context, item, onRefresh: updateItem);
  }

  Future<void> _playFromItem(int index) async {
    await _onPlaylistItemTap(index);
  }

  /// Ensure the focused item is visible in the list using scroll arithmetic.
  /// Uses estimated item height instead of per-item GlobalKeys.
  void _ensureFocusedVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scrollController.hasClients) return;
      final targetOffset = _focusedIndex * _estimatedItemHeight;
      final viewportHeight = scrollController.position.viewportDimension;
      final currentOffset = scrollController.offset;

      // Check if the item is outside the visible area (with some padding)
      if (targetOffset < currentOffset || targetOffset > currentOffset + viewportHeight - _estimatedItemHeight) {
        // Scroll so the item sits ~25% from the top of the viewport
        final scrollTo = (targetOffset - viewportHeight * 0.25).clamp(
          scrollController.position.minScrollExtent,
          scrollController.position.maxScrollExtent,
        );
        scrollController.animateTo(scrollTo, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  /// Handle key events for list navigation
  KeyEventResult _handleListKeyEvent(FocusNode _, KeyEvent event) {
    final key = event.logicalKey;

    final backResult = handleBackKeyAction(event, () {
      if (_movingIndex != null) {
        // Cancel move mode, set flag to prevent PopScope exit
        backHandledByKeyEvent = true;
        _cancelMoveMode();
      } else {
        // Navigate to app bar on BACK, set flag to prevent PopScope exit
        handleBackFromContent();
      }
    });
    if (backResult != KeyEventResult.ignored) {
      return backResult;
    }

    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (_movingIndex != null) {
      // Move mode - arrows reorder the item
      if (key.isUpKey && _movingIndex! > 0) {
        setState(() {
          final item = items.removeAt(_movingIndex!);
          items.insert(_movingIndex! - 1, item);
          _movingIndex = _movingIndex! - 1;
          _focusedIndex = _movingIndex!;
        });
        _ensureFocusedVisible();
        return KeyEventResult.handled;
      }
      if (key.isDownKey && _movingIndex! < items.length - 1) {
        setState(() {
          final item = items.removeAt(_movingIndex!);
          items.insert(_movingIndex! + 1, item);
          _movingIndex = _movingIndex! + 1;
          _focusedIndex = _movingIndex!;
        });
        _ensureFocusedVisible();
        return KeyEventResult.handled;
      }
      if (key.isSelectKey) {
        // Confirm move - persist to server (UI is already updated during move)
        final oldIndex = _originalIndex!;
        final newIndex = _movingIndex!;
        setState(() {
          _movingIndex = null;
          _originalIndex = null;
          _originalOrder = null;
          // Keep focus on the moved item at its new position
          _focusedIndex = newIndex;
          _focusedColumn = 0;
        });
        // Persist the change via API (list is already in correct order)
        _persistMoveToServer(oldIndex, newIndex);
        return KeyEventResult.handled;
      }
    } else {
      // Navigation mode
      if (key.isUpKey) {
        if (_focusedIndex > 0) {
          setState(() {
            _focusedIndex--;
            _focusedColumn = 0; // Reset to row when changing rows
          });
          _ensureFocusedVisible();
        } else {
          // First item - navigate to app bar
          navigateToAppBar();
        }
        return KeyEventResult.handled;
      }
      if (key.isDownKey && _focusedIndex < items.length - 1) {
        setState(() {
          _focusedIndex++;
          _focusedColumn = 0; // Reset to row when changing rows
        });
        _ensureFocusedVisible();
        return KeyEventResult.handled;
      }
      if (key.isLeftKey) {
        // Navigate left within columns
        if (_focusedColumn == 0 && !widget.playlist.smart) {
          // Go to drag handle (column 1)
          setState(() => _focusedColumn = 1);
          return KeyEventResult.handled;
        } else if (_focusedColumn == 2) {
          // Go back to content
          setState(() => _focusedColumn = 0);
          return KeyEventResult.handled;
        }
      }
      if (key.isRightKey) {
        // Navigate right within columns
        if (_focusedColumn == 0) {
          // Go to remove button (column 2)
          setState(() => _focusedColumn = 2);
          return KeyEventResult.handled;
        } else if (_focusedColumn == 1) {
          // Go to content from drag handle
          setState(() => _focusedColumn = 0);
          return KeyEventResult.handled;
        }
      }
      if (key.isSelectKey) {
        if (_focusedColumn == 0) {
          // Play from this item
          _playFromItem(_focusedIndex);
        } else if (_focusedColumn == 1 && !widget.playlist.smart) {
          // Enter move mode
          setState(() {
            _movingIndex = _focusedIndex;
            _originalIndex = _focusedIndex;
            _originalOrder = List.from(items);
          });
        } else if (_focusedColumn == 2) {
          // Remove item
          _removeItem(_focusedIndex);
        }
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  /// Cancel move mode if active, returns true if cancelled
  bool _cancelMoveMode() {
    if (_movingIndex != null) {
      setState(() {
        if (_originalOrder != null) {
          items = List.from(_originalOrder!);
        }
        _focusedIndex = _originalIndex ?? 0;
        _movingIndex = null;
        _originalIndex = null;
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
    final isKeyboardMode = InputModeTracker.isKeyboardMode(context);

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

  /// Build a reorderable list for regular playlists with focus support
  Widget _buildReorderableList(bool _) {
    return SliverReorderableList(
      onReorder: _onReorder,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        // Check keyboard mode directly to ensure we get latest value
        final inKeyboardMode = InputModeTracker.isKeyboardMode(context);
        final isFocused = inKeyboardMode && index == _focusedIndex && !isAppBarFocused;
        final isMoving = index == _movingIndex;

        return RepaintBoundary(
          key: ValueKey(item.playlistItemID ?? item.ratingKey),
          child: PlaylistItemCard(
            item: item,
            index: index,
            onRemove: () => _removeItem(index),
            onTap: () => _onPlaylistItemTap(index),
            onRefresh: updateItem,
            canReorder: !widget.playlist.smart,
            isFocused: isFocused,
            focusedColumn: isFocused ? _focusedColumn : null,
            isMoving: isMoving,
          ),
        );
      },
    );
  }
}
