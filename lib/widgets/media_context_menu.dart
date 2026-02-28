import 'dart:io';
import 'package:flutter/material.dart';
import 'package:finzy/widgets/app_icon.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import '../services/jellyfin_client.dart';
import '../services/play_queue_launcher.dart';
import '../models/media_metadata.dart';
import '../models/playlist.dart';
import '../providers/download_provider.dart';
import '../providers/offline_mode_provider.dart';
import '../providers/offline_watch_provider.dart';
import '../utils/provider_extensions.dart';
import '../utils/app_logger.dart';
import '../utils/library_refresh_notifier.dart';
import '../utils/snackbar_helper.dart';
import '../utils/dialogs.dart';
import '../utils/focus_utils.dart';
import '../focus/dpad_navigator.dart';
import '../screens/media_detail_screen.dart';
import '../screens/season_detail_screen.dart';
import '../utils/smart_deletion_handler.dart';
import '../utils/deletion_notifier.dart';
import '../theme/mono_tokens.dart';
import '../widgets/file_info_bottom_sheet.dart';
import '../widgets/focusable_list_tile.dart';
import '../widgets/overlay_sheet.dart';
import '../i18n/strings.g.dart';

/// Helper class to store menu action data
class _MenuAction {
  final String value;
  final IconData icon;
  final String label;
  final Color? hoverColor;

  _MenuAction({required this.value, required this.icon, required this.label, this.hoverColor});
}

/// A reusable wrapper widget that adds a context menu (long press / right click)
/// to any media item with appropriate actions based on the item type.
class MediaContextMenu extends StatefulWidget {
  final dynamic item; // Can be MediaMetadata or Playlist
  final void Function(String itemId)? onRefresh;
  final VoidCallback? onListRefresh; // For refreshing list after deletion
  final VoidCallback? onTap;
  final Widget child;
  final String? collectionId; // The collection ID if displaying within a collection

  const MediaContextMenu({
    super.key,
    required this.item,
    this.onRefresh,
    this.onListRefresh,
    this.onTap,
    required this.child,
    this.collectionId,
  });

  @override
  State<MediaContextMenu> createState() => MediaContextMenuState();
}

class MediaContextMenuState extends State<MediaContextMenu> {
  Offset? _tapPosition;

  void _storeTapPosition(TapDownDetails details) {
    _tapPosition = details.globalPosition;
  }

  bool _openedFromKeyboard = false;
  bool _isContextMenuOpen = false;

  bool get isContextMenuOpen => _isContextMenuOpen;

  /// Show the context menu programmatically.
  /// Used for keyboard/gamepad long-press activation.
  /// If [position] is null, the menu will appear at the center of this widget.
  void showContextMenu(BuildContext menuContext, {Offset? position}) {
    _openedFromKeyboard = true;
    if (position != null) {
      _tapPosition = position;
    } else {
      // Calculate center of the widget for keyboard activation
      final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final size = renderBox.size;
        final topLeft = renderBox.localToGlobal(Offset.zero);
        _tapPosition = Offset(topLeft.dx + size.width / 2, topLeft.dy + size.height / 2);
      }
    }
    _showContextMenu(menuContext);
  }

  /// Get the serverId from the item (MediaMetadata or Playlist)
  String? get _itemServerId {
    if (widget.item is MediaMetadata) return (widget.item as MediaMetadata).serverId;
    if (widget.item is Playlist) return (widget.item as Playlist).serverId;
    return null;
  }

  /// Get the correct JellyfinClient for this item's server
  JellyfinClient _getClientForItem() => context.getClientWithFallback(_itemServerId);

  void _handleTap() {
    if (_isContextMenuOpen) return;
    widget.onTap?.call();
  }

  void _showContextMenu(BuildContext context) async {
    if (_isContextMenuOpen) return;
    _isContextMenuOpen = true;

    // Capture the currently focused node for restoration after menu closes
    final previousFocus = FocusManager.instance.primaryFocus;
    bool didNavigate = false;

    final isPlaylist = widget.item is Playlist;
    final metadata = isPlaylist ? null : widget.item as MediaMetadata;
    final mediaType = isPlaylist ? null : metadata!.mediaType;
    final isCollection = mediaType == MediaType.collection;

    final isPartiallyWatched =
        !isPlaylist &&
        metadata!.watchedEpisodeCount != null &&
        metadata.leafCount != null &&
        metadata.watchedEpisodeCount! > 0 &&
        metadata.watchedEpisodeCount! < metadata.leafCount!;

    final hasActiveProgress =
        mediaType != null &&
        (mediaType == MediaType.movie || mediaType == MediaType.episode) &&
        metadata?.hasActiveProgress == true;

    // Check if we should use bottom sheet (on iOS and Android)
    final useBottomSheet = Platform.isIOS || Platform.isAndroid;

    final client = _getClientForItem();

    // Build menu actions
    final menuActions = <_MenuAction>[];

    // Special actions for collections and playlists
    if (isCollection || isPlaylist) {
      // Play
      menuActions.add(_MenuAction(value: 'play', icon: Symbols.play_arrow_rounded, label: t.common.play));

      // Shuffle
      menuActions.add(_MenuAction(value: 'shuffle', icon: Symbols.shuffle_rounded, label: t.mediaMenu.shufflePlay));

      // Delete (playlists always, collections only with permission)
      if (isPlaylist || client.canDeleteContent) {
        menuActions.add(_MenuAction(value: 'delete', icon: Symbols.delete_rounded, label: t.common.delete));
      }

      // Skip other menu items for collections and playlists
    } else {
      // Regular menu items for other types

      // Mark as Watched
      if (!metadata!.isWatched || isPartiallyWatched || hasActiveProgress) {
        menuActions.add(
          _MenuAction(value: 'watch', icon: Symbols.check_circle_outline_rounded, label: t.mediaMenu.markAsWatched),
        );
      }

      // Mark as Unwatched
      if (metadata.isWatched || isPartiallyWatched || hasActiveProgress) {
        menuActions.add(
          _MenuAction(
            value: 'unwatch',
            icon: Symbols.remove_circle_outline_rounded,
            label: t.mediaMenu.markAsUnwatched,
          ),
        );
      }

      // Remove from Collection (only when viewing items within a collection)
      if (widget.collectionId != null) {
        menuActions.add(
          _MenuAction(
            value: 'remove_from_collection',
            icon: Symbols.delete_outline_rounded,
            label: t.collections.removeFromCollection,
          ),
        );
      }

      // Go to Series (for episodes and seasons)
      if ((mediaType == MediaType.episode || mediaType == MediaType.season) &&
          metadata.seriesTitle != null) {
        menuActions.add(_MenuAction(value: 'series', icon: Symbols.tv_rounded, label: t.mediaMenu.goToSeries));
      }

      // Go to Season (for episodes)
      if (mediaType == MediaType.episode && metadata.seasonTitle != null) {
        menuActions.add(
          _MenuAction(value: 'season', icon: Symbols.playlist_play_rounded, label: t.mediaMenu.goToSeason),
        );
      }

      // File Info (for episodes and movies)
      if (mediaType == MediaType.episode || mediaType == MediaType.movie) {
        menuActions.add(_MenuAction(value: 'fileinfo', icon: Symbols.info_rounded, label: t.mediaMenu.fileInfo));
      }

      // Download options (for episodes, movies, shows, and seasons)
      if (mediaType == MediaType.episode ||
          mediaType == MediaType.movie ||
          mediaType == MediaType.show ||
          mediaType == MediaType.season) {
        final downloadProvider = Provider.of<DownloadProvider>(context, listen: false);
        final globalKey = '${metadata.serverId}:${metadata.itemId}';
        final isDownloaded = downloadProvider.isDownloaded(globalKey);

        if (isDownloaded) {
          // Show delete download option
          menuActions.add(
            _MenuAction(value: 'delete_download', icon: Symbols.delete_rounded, label: t.downloads.deleteDownload),
          );
        } else {
          // Show download option
          menuActions.add(
            _MenuAction(value: 'download', icon: Symbols.download_rounded, label: t.downloads.downloadNow),
          );
        }
      }

      // Add to Playlist / Collection (for episodes, movies, shows, and seasons)
      if (mediaType == MediaType.episode ||
          mediaType == MediaType.movie ||
          mediaType == MediaType.show ||
          mediaType == MediaType.season) {
        menuActions.add(_MenuAction(value: 'add_to_playlist', icon: Symbols.playlist_add_rounded, label: t.playlists.addToPlaylist));
        menuActions.add(_MenuAction(value: 'add_to_collection', icon: Symbols.collections_rounded, label: t.collections.addToCollection));
      }

      // Delete media item (only if user has permission)
      if (client.canDeleteContent &&
          (mediaType == MediaType.episode ||
          mediaType == MediaType.movie ||
          mediaType == MediaType.show ||
          mediaType == MediaType.season)) {
        menuActions.add(
          _MenuAction(
            value: 'delete_media',
            icon: Symbols.delete_rounded,
            label: t.common.delete,
            hoverColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } // End of regular menu items else block

    String? selected;

    final openedFromKeyboard = _openedFromKeyboard;
    _openedFromKeyboard = false;

    if (useBottomSheet) {
      // Show overlay sheet if available, otherwise fall back to modal bottom sheet
      final overlayController = OverlaySheetController.maybeOf(context);
      if (overlayController != null) {
        selected = await overlayController.show<String>(
          builder: (context) => _FocusableContextMenuSheet(
            title: widget.item.title,
            actions: menuActions,
            focusFirstItem: openedFromKeyboard,
          ),
        );
      } else {
        selected = await showModalBottomSheet<String>(
          context: context,
          builder: (context) => _FocusableContextMenuSheet(
            title: widget.item.title,
            actions: menuActions,
            focusFirstItem: openedFromKeyboard,
          ),
        );
      }
    } else {
      // Show custom focusable popup menu on larger screens
      // Use stored tap position or fallback to widget position
      final RenderBox? overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;

      Offset position;
      if (_tapPosition != null) {
        position = _tapPosition!;
      } else {
        final RenderBox renderBox = context.findRenderObject() as RenderBox;
        position = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
      }

      selected = await showDialog<String>(
        context: context,
        barrierColor: Colors.transparent,
        builder: (dialogContext) =>
            _FocusablePopupMenu(actions: menuActions, position: position, focusFirstItem: openedFromKeyboard),
      );
    }

    try {
      if (!context.mounted) return;

      // Check if we're in offline mode for watch actions
      final offlineModeProvider = context.read<OfflineModeProvider>();
      final isOffline = offlineModeProvider.isOffline;

      switch (selected) {
        case 'watch':
          if (isOffline && metadata?.serverId != null) {
            // Offline mode: queue action for later sync (emits WatchStateEvent)
            final offlineWatch = context.read<OfflineWatchProvider>();
            await offlineWatch.markAsWatched(serverId: metadata!.serverId!, itemId: metadata.itemId);
            if (context.mounted) {
              showAppSnackBar(context, t.messages.markedAsWatchedOffline);
              widget.onRefresh?.call(metadata.itemId);
            }
          } else {
            // Pass metadata to emit WatchStateEvent for cross-screen updates
            await _executeAction(
              context,
              () => client.markAsWatched(metadata!.itemId, metadata: metadata),
              t.messages.markedAsWatched,
            );
          }
          break;

        case 'unwatch':
          if (isOffline && metadata?.serverId != null) {
            // Offline mode: queue action for later sync (emits WatchStateEvent)
            final offlineWatch = context.read<OfflineWatchProvider>();
            await offlineWatch.markAsUnwatched(serverId: metadata!.serverId!, itemId: metadata.itemId);
            if (context.mounted) {
              showAppSnackBar(context, t.messages.markedAsUnwatchedOffline);
              widget.onRefresh?.call(metadata.itemId);
            }
          } else {
            // Pass metadata to emit WatchStateEvent for cross-screen updates
            await _executeAction(
              context,
              () => client.markAsUnwatched(metadata!.itemId, metadata: metadata),
              t.messages.markedAsUnwatched,
            );
          }
          break;

        case 'remove_from_collection':
          await _handleRemoveFromCollection(context, metadata!);
          break;

        case 'series':
          didNavigate = true;
          await _navigateToRelated(
            context,
            metadata!.seriesId,
            (metadata) => MediaDetailScreen(metadata: metadata),
            t.messages.errorLoadingSeries,
          );
          break;

        case 'season':
          didNavigate = true;
          await _navigateToRelated(
            context,
            metadata!.seasonId,
            (metadata) => SeasonDetailScreen(season: metadata),
            t.messages.errorLoadingSeason,
          );
          break;

        case 'fileinfo':
          await _showFileInfo(context);
          break;

        case 'add_to_playlist':
          await _showAddToPlaylistDialog(context);
          break;

        case 'add_to_collection':
          await _showAddToCollectionDialog(context);
          break;

        case 'play':
          await _handlePlay(context, isCollection, isPlaylist);
          break;

        case 'shuffle':
          await _handleShuffle(context, isCollection, isPlaylist);
          break;

        case 'delete':
          await _handleDelete(context, isCollection, isPlaylist);
          break;

        case 'download':
          await _handleDownload(context);
          break;

        case 'delete_download':
          await _handleDeleteDownload(context);
          break;

        case 'delete_media':
          await _handleDeleteMediaItem(context, mediaType);
          break;
      }
    } finally {
      _isContextMenuOpen = false;

      // Restore focus to the previously focused item after the menu closes,
      // but only if no navigation occurred and the focus node is still valid
      if (!didNavigate && previousFocus != null && previousFocus.canRequestFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (previousFocus.canRequestFocus) {
            previousFocus.requestFocus();
          }
        });
      }
    }
  }

  /// Execute an action with error handling and refresh
  Future<void> _executeAction(BuildContext context, Future<void> Function() action, String successMessage) async {
    try {
      await action();
      if (context.mounted) {
        showSuccessSnackBar(context, successMessage);
        widget.onRefresh?.call(widget.item.itemId);
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, t.messages.errorLoading(error: e.toString()));
      }
    }
  }

  /// Navigate to a related item (series or season)
  Future<void> _navigateToRelated(
    BuildContext context,
    String? itemId,
    Widget Function(MediaMetadata) screenBuilder,
    String errorPrefix,
  ) async {
    if (itemId == null) return;

    final client = _getClientForItem();

    try {
      final metadata = await client.getMetadataWithImages(itemId);
      if (metadata != null && context.mounted) {
        await Navigator.push(context, MaterialPageRoute(builder: (context) => screenBuilder(metadata)));
        widget.onRefresh?.call(widget.item.itemId);
      }
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, '$errorPrefix: $e');
      }
    }
  }

  /// Show file info bottom sheet
  Future<void> _showFileInfo(BuildContext context) async {
    final client = _getClientForItem();

    try {
      // Show loading indicator
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );
      }

      // Fetch file info
      final metadata = widget.item as MediaMetadata;
      final fileInfo = await client.getFileInfo(metadata.itemId);

      // Close loading indicator
      if (context.mounted) {
        Navigator.pop(context);
      }

      if (fileInfo != null && context.mounted) {
        // Show file info bottom sheet
        final overlayController = OverlaySheetController.maybeOf(context);
        if (overlayController != null) {
          await overlayController.show(
            builder: (context) => FileInfoBottomSheet(fileInfo: fileInfo, title: metadata.title),
          );
        } else {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => FileInfoBottomSheet(fileInfo: fileInfo, title: metadata.title),
          );
        }
      } else if (context.mounted) {
        showErrorSnackBar(context, t.messages.fileInfoNotAvailable);
      }
    } catch (e) {
      // Close loading indicator if it's still open
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (context.mounted) {
        showErrorSnackBar(context, t.messages.errorLoadingFileInfo(error: e.toString()));
      }
    }
  }

  /// Show dialog to select playlist and add item
  Future<void> _showAddToPlaylistDialog(BuildContext context) async {
    final client = _getClientForItem();

    try {
      final metadata = widget.item as MediaMetadata;
      final itemType = metadata.type.toLowerCase();

      // Load playlists
      final playlists = await client.getPlaylists(playlistType: 'video');

      if (!context.mounted) return;

      // Show dialog to select playlist or create new
      final result = await showDialog<String>(
        context: context,
        builder: (context) => _PlaylistSelectionDialog(playlists: playlists),
      );

      if (result == null || !context.mounted) return;

      // Build URI for the item (works for all types: movies, episodes, seasons, shows)
      // For seasons/shows, the server API should automatically expand to include all episodes
      final itemUri = await client.buildMetadataUri(metadata.itemId);
      appLogger.d('Built URI for $itemType: $itemUri');

      if (!context.mounted) return;

      if (result == '_create_new') {
        // Create new playlist flow
        final playlistName = await showTextInputDialog(
          context,
          title: t.playlists.create,
          labelText: t.playlists.playlistName,
          hintText: t.playlists.enterPlaylistName,
        );

        if (playlistName == null || playlistName.isEmpty || !context.mounted) {
          return;
        }

        // Create playlist with the item(s)
        appLogger.d('Creating playlist "$playlistName" with URI length: ${itemUri.length}');
        final newPlaylist = await client.createPlaylist(title: playlistName, uri: itemUri);

        if (!context.mounted) return;

        if (context.mounted) {
          if (newPlaylist != null) {
            appLogger.d('Successfully created playlist: ${newPlaylist.title}');
            showSuccessSnackBar(context, t.playlists.created);
            // Trigger refresh of playlists tab
            LibraryRefreshNotifier().notifyPlaylistsChanged();
          } else {
            appLogger.e('Failed to create playlist - API returned null');
            showErrorSnackBar(context, t.playlists.errorCreating);
          }
        }
      } else {
        // Add to existing playlist
        appLogger.d('Adding to playlist $result with URI: $itemUri');
        final success = await client.addToPlaylist(playlistId: result, uri: itemUri);

        if (!context.mounted) return;

        if (context.mounted) {
          if (success) {
            appLogger.d('Successfully added item(s) to playlist $result');
            showSuccessSnackBar(context, t.playlists.itemAdded);
            // Trigger refresh of playlists tab
            LibraryRefreshNotifier().notifyPlaylistsChanged();
          } else {
            appLogger.e('Failed to add item(s) to playlist $result - API returned false');
            showErrorSnackBar(context, t.playlists.errorAdding);
          }
        }
      }
    } catch (e, stackTrace) {
      appLogger.e('Error in add to playlist flow', error: e, stackTrace: stackTrace);
      if (context.mounted) {
        showErrorSnackBar(context, '${t.playlists.errorLoading}: ${e.toString()}');
      }
    }
  }

  /// Show dialog to select collection and add item
  Future<void> _showAddToCollectionDialog(BuildContext context) async {
    final client = _getClientForItem();

    try {
      final metadata = widget.item as MediaMetadata;

      final collections = await client.getGlobalCollections();

      if (!context.mounted) return;

      final result = await showDialog<String>(
        context: context,
        builder: (context) => _CollectionSelectionDialog(collections: collections),
      );

      if (result == null || !context.mounted) return;

      if (result == '_create_new') {
        final collectionName = await showTextInputDialog(
          context,
          title: t.collections.createNewCollection,
          labelText: t.collections.collectionName,
          hintText: t.collections.enterCollectionName,
        );

        if (collectionName == null || collectionName.isEmpty || !context.mounted) {
          return;
        }

        final newCollectionId = await client.createCollection(
          title: collectionName,
          itemIds: [metadata.itemId],
        );

        if (!context.mounted) return;

        if (newCollectionId != null) {
          showSuccessSnackBar(context, t.collections.created);
          LibraryRefreshNotifier().notifyCollectionsChanged();
        } else {
          showErrorSnackBar(context, t.collections.errorAddingToCollection);
        }
      } else {
        final success = await client.addToCollection(collectionId: result, itemIds: [metadata.itemId]);

        if (!context.mounted) return;

        if (success) {
          showSuccessSnackBar(context, t.collections.addedToCollection);
          LibraryRefreshNotifier().notifyCollectionsChanged();
        } else {
          showErrorSnackBar(context, t.collections.errorAddingToCollection);
        }
      }
    } catch (e, stackTrace) {
      appLogger.e('Error in add to collection flow', error: e, stackTrace: stackTrace);
      if (context.mounted) {
        showErrorSnackBar(context, '${t.collections.errorAddingToCollection}: ${e.toString()}');
      }
    }
  }

  Future<void> _handleRemoveFromCollection(BuildContext context, MediaMetadata metadata) async {
    final client = _getClientForItem();

    if (widget.collectionId == null) {
      appLogger.e('Cannot remove from collection: collectionId is null');
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDeleteConfirmation(
      context,
      title: t.collections.removeFromCollection,
      message: t.collections.removeFromCollectionConfirm(title: metadata.title),
    );

    if (!confirmed || !context.mounted) return;

    try {
      appLogger.d('Removing item ${metadata.itemId} from collection ${widget.collectionId}');
      final success = await client.removeFromCollection(collectionId: widget.collectionId!, itemId: metadata.itemId);

      if (context.mounted) {
        if (success) {
          showSuccessSnackBar(context, t.collections.removedFromCollection);
          // Trigger refresh of collections tab
          LibraryRefreshNotifier().notifyCollectionsChanged();
          // Trigger list refresh to remove the item from the view
          widget.onListRefresh?.call();
        } else {
          showErrorSnackBar(context, t.collections.removeFromCollectionFailed);
        }
      }
    } catch (e) {
      appLogger.e('Failed to remove from collection', error: e);
      if (context.mounted) {
        showErrorSnackBar(context, t.collections.removeFromCollectionError(error: e.toString()));
      }
    }
  }

  /// Handle play action for collections and playlists
  Future<void> _handlePlay(BuildContext context, bool _, bool _) async {
    await _launchCollectionOrPlaylist(context, shuffle: false);
  }

  /// Handle shuffle action for collections and playlists
  Future<void> _handleShuffle(BuildContext context, bool _, bool _) async {
    await _launchCollectionOrPlaylist(context, shuffle: true);
  }

  /// Launch playback for collection or playlist
  Future<void> _launchCollectionOrPlaylist(BuildContext context, {required bool shuffle}) async {
    final client = _getClientForItem();
    final item = widget.item;

    final launcher = PlayQueueLauncher(
      context: context,
      client: client,
      serverId: item is MediaMetadata ? item.serverId : (item as Playlist).serverId,
      serverName: item is MediaMetadata ? item.serverName : (item as Playlist).serverName,
    );

    await launcher.launchFromCollectionOrPlaylist(item: item, shuffle: shuffle, showLoadingIndicator: false);
  }

  /// Handle delete action for collections and playlists
  Future<void> _handleDelete(BuildContext context, bool isCollection, bool isPlaylist) async {
    final client = _getClientForItem();

    final itemTitle = widget.item.title;
    final itemTypeLabel = isCollection ? t.collections.collection : t.playlists.playlist;

    // Show confirmation dialog
    final confirmed = await showDeleteConfirmation(
      context,
      title: isCollection ? t.collections.deleteCollection : t.playlists.delete,
      message: isCollection
          ? t.collections.deleteConfirm(title: itemTitle)
          : t.playlists.deleteMessage(name: itemTitle),
    );

    if (!confirmed || !context.mounted) return;

    try {
      bool success = false;

      if (isCollection) {
        final metadata = widget.item as MediaMetadata;
        success = await client.deleteCollection(metadata.itemId);
      } else if (isPlaylist) {
        final playlist = widget.item as Playlist;
        success = await client.deletePlaylist(playlist.itemId);
      }

      if (context.mounted) {
        if (success) {
          showSuccessSnackBar(context, isCollection ? t.collections.deleted : t.playlists.deleted);
          // Trigger list refresh
          widget.onListRefresh?.call();
        } else {
          showErrorSnackBar(context, isCollection ? t.collections.deleteFailed : t.playlists.errorDeleting);
        }
      }
    } catch (e) {
      appLogger.e('Failed to delete $itemTypeLabel', error: e);
      if (context.mounted) {
        showErrorSnackBar(
          context,
          isCollection ? t.collections.deleteFailedWithError(error: e.toString()) : t.playlists.errorDeleting,
        );
      }
    }
  }

  /// Handle download action
  Future<void> _handleDownload(BuildContext context) async {
    final downloadProvider = Provider.of<DownloadProvider>(context, listen: false);
    final metadata = widget.item as MediaMetadata;
    final client = _getClientForItem();

    try {
      final count = await downloadProvider.queueDownload(metadata, client);
      if (context.mounted) {
        // Show appropriate message based on count
        final message = count > 1 ? t.downloads.episodesQueued(count: count) : t.downloads.downloadQueued;
        showSuccessSnackBar(context, message);
      }
    } on CellularDownloadBlockedException {
      if (context.mounted) {
        showErrorSnackBar(context, t.settings.cellularDownloadBlocked);
      }
    } catch (e) {
      appLogger.e('Failed to queue download', error: e);
      if (context.mounted) {
        showErrorSnackBar(context, t.messages.errorLoading(error: e.toString()));
      }
    }
  }

  /// Handle delete download action
  Future<void> _handleDeleteDownload(BuildContext context) async {
    final downloadProvider = Provider.of<DownloadProvider>(context, listen: false);
    final metadata = widget.item as MediaMetadata;
    final globalKey = '${metadata.serverId}:${metadata.itemId}';

    // Show confirmation dialog
    final confirmed = await showDeleteConfirmation(
      context,
      title: t.downloads.deleteDownload,
      message: t.downloads.deleteConfirm(title: metadata.title),
    );

    if (!confirmed || !context.mounted) return;

    try {
      // Use smart deletion handler (shows progress only if >500ms)
      await SmartDeletionHandler.deleteWithProgress(context: context, provider: downloadProvider, globalKey: globalKey);

      if (context.mounted) {
        showSuccessSnackBar(context, t.downloads.downloadDeleted);
        // Notify DeletionAware screens (e.g. offline season detail)
        DeletionNotifier().notifyDeleted(metadata: metadata, isDownloadOnly: true);
        // Refresh the view if needed
        widget.onRefresh?.call(metadata.itemId);
      }
    } catch (e) {
      appLogger.e('Failed to delete download', error: e);
      if (context.mounted) {
        showErrorSnackBar(context, t.messages.errorLoading(error: e.toString()));
      }
    }
  }

  /// Handle delete media item action
  /// This permanently removes the media item and its associated files from the server
  Future<void> _handleDeleteMediaItem(BuildContext context, MediaType? mediaType) async {
    final metadata = widget.item as MediaMetadata;
    final isMultipleMediaItems = mediaType == MediaType.show || mediaType == MediaType.season;

    // Show confirmation dialog
    final confirmed = await showDeleteConfirmation(
      context,
      title: t.common.delete,
      message: "${t.mediaMenu.confirmDelete}${isMultipleMediaItems ? "\n${t.mediaMenu.deleteMultipleWarning}" : ""}",
    );

    if (!confirmed || !context.mounted) return;

    try {
      final client = _getClientForItem();
      final success = await client.deleteMediaItem(metadata.itemId);

      if (context.mounted) {
        if (success) {
          showSuccessSnackBar(context, t.mediaMenu.mediaDeletedSuccessfully);
          // Broadcast deletion event for cross-screen propagation
          DeletionNotifier().notifyDeleted(metadata: metadata);
          // Backward-compatible list refresh for screens that are not DeletionAware yet
          widget.onListRefresh?.call();
        } else {
          showErrorSnackBar(context, t.mediaMenu.mediaFailedToDelete);
        }
      }
    } catch (e) {
      appLogger.e(t.mediaMenu.mediaFailedToDelete, error: e);
      if (context.mounted) {
        showErrorSnackBar(context, t.mediaMenu.mediaFailedToDelete);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      onTapDown: _storeTapPosition,
      onLongPress: () => _showContextMenu(context),
      onSecondaryTapDown: _storeTapPosition,
      onSecondaryTap: () => _showContextMenu(context),
      child: widget.child,
    );
  }
}

/// Dialog to select a playlist or create a new one
class _PlaylistSelectionDialog extends StatelessWidget {
  final List<Playlist> playlists;

  const _PlaylistSelectionDialog({required this.playlists});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t.playlists.selectPlaylist),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: playlists.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              // Create new playlist option (always shown first)
              return ListTile(
                leading: const AppIcon(Symbols.add_rounded, fill: 1),
                title: Text(t.playlists.createNewPlaylist),
                onTap: () => Navigator.pop(context, '_create_new'),
              );
            }

            final playlist = playlists[index - 1];
            final subtitleText = playlist.leafCount == 1
                ? t.playlists.oneItem
                : t.playlists.itemCount(count: playlist.leafCount!);
            return ListTile(
              leading: playlist.smart
                  ? const AppIcon(Symbols.auto_awesome_rounded, fill: 1)
                  : const AppIcon(Symbols.playlist_play_rounded, fill: 1),
              title: Text(playlist.title),
              subtitle: playlist.leafCount != null ? Text(subtitleText) : null,
              onTap: playlist.smart
                  ? null // Disable smart playlists
                  : () => Navigator.pop(context, playlist.itemId),
              enabled: !playlist.smart,
            );
          },
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(t.common.cancel))],
    );
  }
}

/// Dialog to select a collection or create a new one
class _CollectionSelectionDialog extends StatelessWidget {
  final List<MediaMetadata> collections;

  const _CollectionSelectionDialog({required this.collections});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t.collections.selectCollection),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: collections.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              // Create new collection option (always shown first)
              return ListTile(
                leading: const AppIcon(Symbols.add_rounded, fill: 1),
                title: Text(t.collections.createNewCollection),
                onTap: () => Navigator.pop(context, '_create_new'),
              );
            }

            final collection = collections[index - 1];
            return ListTile(
              leading: const AppIcon(Symbols.collections_rounded, fill: 1),
              title: Text(collection.title),
              subtitle: collection.childCount != null ? Text('${collection.childCount} items') : null,
              onTap: () => Navigator.pop(context, collection.itemId),
            );
          },
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(t.common.cancel))],
    );
  }
}

/// Focusable context menu sheet for keyboard/gamepad navigation (mobile)
class _FocusableContextMenuSheet extends StatefulWidget {
  final String title;
  final List<_MenuAction> actions;
  final bool focusFirstItem;

  const _FocusableContextMenuSheet({required this.title, required this.actions, this.focusFirstItem = false});

  @override
  State<_FocusableContextMenuSheet> createState() => _FocusableContextMenuSheetState();
}

class _FocusableContextMenuSheetState extends State<_FocusableContextMenuSheet> {
  late final FocusNode _initialFocusNode;

  @override
  void initState() {
    super.initState();
    _initialFocusNode = FocusNode(debugLabel: 'ContextMenuSheetInitialFocus');
  }

  @override
  void dispose() {
    _initialFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              widget.title,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...widget.actions.asMap().entries.map((entry) {
                    final index = entry.key;
                    final action = entry.value;
                    return FocusableListTile(
                      focusNode: index == 0 ? _initialFocusNode : null,
                      leading: AppIcon(action.icon, fill: 1),
                      title: Text(action.label),
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      visualDensity: const VisualDensity(vertical: -3),
                      onTap: () {
                        final controller = OverlaySheetController.maybeOf(context);
                        if (controller != null) {
                          controller.close(action.value);
                        } else {
                          Navigator.pop(context, action.value);
                        }
                      },
                      hoverColor: action.hoverColor,
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Focusable popup menu for keyboard/gamepad navigation (desktop)
class _FocusablePopupMenu extends StatefulWidget {
  final List<_MenuAction> actions;
  final Offset position;
  final bool focusFirstItem;

  const _FocusablePopupMenu({required this.actions, required this.position, this.focusFirstItem = false});

  @override
  State<_FocusablePopupMenu> createState() => _FocusablePopupMenuState();
}

class _FocusablePopupMenuState extends State<_FocusablePopupMenu> {
  late final FocusNode _initialFocusNode;

  @override
  void initState() {
    super.initState();
    _initialFocusNode = FocusNode(debugLabel: 'PopupMenuInitialFocus');
    if (widget.focusFirstItem) {
      FocusUtils.requestFocusAfterBuild(this, _initialFocusNode);
    }
  }

  @override
  void dispose() {
    _initialFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    const menuWidth = 220.0;

    // Calculate menu position, keeping it on screen
    double left = widget.position.dx;
    double top = widget.position.dy;

    // Adjust if menu would go off right edge
    if (left + menuWidth > screenSize.width) {
      left = screenSize.width - menuWidth - 8;
    }

    // Estimate menu height and adjust if would go off bottom
    final estimatedHeight = widget.actions.length * 40.0 + 16;
    if (top + estimatedHeight > screenSize.height) {
      top = screenSize.height - estimatedHeight - 8;
    }

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (SelectKeyUpSuppressor.consumeIfSuppressed(event)) {
          return KeyEventResult.handled;
        }
        if (BackKeyUpSuppressor.consumeIfSuppressed(event)) {
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Stack(
        children: [
          // Barrier to close menu when clicking outside
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          // Menu
          Positioned(
            left: left,
            top: top,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(tokens(context).radiusSm),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: menuWidth, maxWidth: menuWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: widget.actions.asMap().entries.map((entry) {
                    final index = entry.key;
                    final action = entry.value;
                    return FocusableListTile(
                      focusNode: index == 0 ? _initialFocusNode : null,
                      leading: AppIcon(action.icon, fill: 1, size: 20),
                      title: Text(action.label),
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      visualDensity: const VisualDensity(vertical: -3),
                      onTap: () => Navigator.pop(context, action.value),
                      hoverColor: action.hoverColor,
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
