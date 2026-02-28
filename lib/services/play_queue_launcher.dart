import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/play_queue_response.dart';
import '../models/media_metadata.dart';
import '../models/playlist.dart';
import '../providers/playback_state_provider.dart';
import '../utils/app_logger.dart';
import '../utils/snackbar_helper.dart';
import '../utils/video_player_navigation.dart';
import '../i18n/strings.g.dart';
import 'jellyfin_client.dart';

/// Result type for play queue operations
sealed class PlayQueueResult {
  const PlayQueueResult();
}

class PlayQueueSuccess extends PlayQueueResult {
  const PlayQueueSuccess();
}

class PlayQueueEmpty extends PlayQueueResult {
  const PlayQueueEmpty();
}

class PlayQueueError extends PlayQueueResult {
  final Object error;
  const PlayQueueError(this.error);
}

/// Service to handle play queue creation and navigation.
///
/// Centralizes the common pattern of:
/// 1. Creating a play queue via various methods
/// 2. Setting up PlaybackStateProvider
/// 3. Navigating to the video player
/// 4. Handling errors with appropriate feedback
class PlayQueueLauncher {
  final BuildContext context;
  final JellyfinClient client;
  final String? serverId;
  final String? serverName;

  PlayQueueLauncher({required this.context, required this.client, this.serverId, this.serverName});

  /// Launch playback from a collection or playlist.
  Future<PlayQueueResult> launchFromCollectionOrPlaylist({
    required dynamic item, // MediaMetadata (collection) or Playlist
    required bool shuffle,
    bool showLoadingIndicator = true,
  }) async {
    final isCollection = item is MediaMetadata;
    final isPlaylist = item is Playlist;

    if (!isCollection && !isPlaylist) {
      return PlayQueueError(Exception('Item must be either a collection or playlist'));
    }

    return _executeWithLoading(
      showLoading: showLoadingIndicator,
      action: t.common.shuffle,
      execute: (dismissLoading) async {
        final String itemId = item.itemId;
        final String? itemServerId = item.serverId ?? serverId;
        final String? itemServerName = item.serverName ?? serverName;

        PlayQueueResponse? playQueue;

        if (isCollection) {
          // Build queue from collection items (Jellyfin has no server-side play queue API)
          final items = await client.getCollectionItems(item.itemId);
          if (items.isEmpty) {
            await dismissLoading();
            return const PlayQueueEmpty();
          }
          final order = List<int>.generate(items.length, (i) => i);
          if (shuffle) order.shuffle();
          final tagged = order
              .asMap()
              .entries
              .map((e) => items[e.value].copyWith(
                    playQueueItemID: e.key,
                    serverId: item.serverId ?? itemServerId,
                    serverName: item.serverName ?? itemServerName,
                  ))
              .toList();
          playQueue = PlayQueueResponse(
            playQueueID: 0,
            playQueueSelectedItemID: 0,
            playQueueShuffled: shuffle,
            playQueueTotalCount: tagged.length,
            playQueueVersion: 1,
            size: tagged.length,
            items: tagged,
          );
        } else {
          // Playlists: build queue from playlist items
          final items = await client.getPlaylist(item.itemId);
          if (items.isEmpty) {
            await dismissLoading();
            return const PlayQueueEmpty();
          }
          final order = List<int>.generate(items.length, (i) => i);
          if (shuffle) order.shuffle();
          final tagged = order
              .asMap()
              .entries
              .map((e) => items[e.value].copyWith(
                    playQueueItemID: e.key,
                    serverId: item.serverId ?? itemServerId,
                    serverName: item.serverName ?? itemServerName,
                  ))
              .toList();
          playQueue = PlayQueueResponse(
            playQueueID: 0,
            playQueueSelectedItemID: 0,
            playQueueShuffled: shuffle,
            playQueueTotalCount: tagged.length,
            playQueueVersion: 1,
            size: tagged.length,
            items: tagged,
          );
        }

        // Close loading dialog before navigating to the player
        await dismissLoading();

        return _launchFromQueue(
          playQueue: playQueue,
          itemId: itemId,
          serverId: itemServerId,
          serverName: itemServerName,
        );
      },
    );
  }

  /// Launch playback from a playlist starting at a specific item.
  Future<PlayQueueResult> launchFromPlaylistItem({
    required Playlist playlist,
    required MediaMetadata selectedItem,
    bool showLoadingIndicator = true,
  }) async {
    return _executeWithLoading(
      showLoading: showLoadingIndicator,
      action: t.common.play,
      execute: (dismissLoading) async {
        PlayQueueResponse? playQueue;
        MediaMetadata? selected;
        // Build queue from playlist items
        final items = await client.getPlaylist(playlist.itemId);
        if (items.isEmpty) {
          await dismissLoading();
          return const PlayQueueEmpty();
        }
        final selectedIndex = items.indexWhere((e) => e.itemId == selectedItem.itemId);
        final startIndex = selectedIndex >= 0 ? selectedIndex : 0;
        final tagged = items
            .asMap()
            .entries
            .map((e) => e.value.copyWith(
                  playQueueItemID: e.key,
                  serverId: playlist.serverId ?? serverId,
                  serverName: playlist.serverName ?? serverName,
                ))
            .toList();
        selected = tagged[startIndex];
        playQueue = PlayQueueResponse(
          playQueueID: 0,
          playQueueSelectedItemID: startIndex,
          playQueueShuffled: false,
          playQueueTotalCount: tagged.length,
          playQueueVersion: 1,
          size: tagged.length,
          items: tagged,
        );

        // Close loading dialog before navigating to the player
        await dismissLoading();

        return _launchFromQueue(
          playQueue: playQueue,
          itemId: playlist.itemId,
          serverId: serverId,
          serverName: serverName,
          selectedItem: selected,
        );
      },
    );
  }

  /// Core method to launch playback from a play queue.
  Future<PlayQueueResult> _launchFromQueue({
    required PlayQueueResponse? playQueue,
    required String itemId,
    String? serverId,
    String? serverName,
    MediaMetadata? selectedItem,
    bool copyServerInfo = false,
  }) async {
    if (playQueue == null || playQueue.items == null || playQueue.items!.isEmpty) {
      return const PlayQueueEmpty();
    }

    if (!context.mounted) return const PlayQueueError('Context not mounted');

    // Set up playback state
    final playbackState = context.read<PlaybackStateProvider>();
    playbackState.setClient(client);
    await playbackState.setPlaybackFromPlayQueue(playQueue, itemId);

    if (!context.mounted) return const PlayQueueError('Context not mounted');

    // Determine which item to navigate to
    var itemToPlay = selectedItem ?? playQueue.items!.first;

    // Copy server info if needed
    if (copyServerInfo && serverId != null) {
      itemToPlay = itemToPlay.copyWith(serverId: serverId, serverName: serverName);
    }

    // Navigate to video player
    await navigateToVideoPlayer(context, metadata: itemToPlay);

    return const PlayQueueSuccess();
  }

  /// Execute an action with optional loading indicator and error handling.
  Future<PlayQueueResult> _executeWithLoading({
    required bool showLoading,
    required String action,
    required Future<PlayQueueResult> Function(Future<void> Function() dismissLoading) execute,
  }) async {
    BuildContext? loadingDialogContext;
    var loadingVisible = false;

    // Show loading indicator
    if (showLoading && context.mounted) {
      loadingVisible = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          loadingDialogContext = dialogContext;
          return const Center(child: CircularProgressIndicator());
        },
      );
    }

    Future<void> dismissLoading() async {
      if (!showLoading || !loadingVisible) return;
      final dialogContext = loadingDialogContext;
      if (dialogContext == null) return;

      // Only dismiss if the dialog is still the current route to avoid
      // accidentally popping the player after navigation.
      final route = ModalRoute.of(dialogContext);
      if (route?.isCurrent ?? false) {
        Navigator.of(dialogContext).pop();
      }

      loadingVisible = false;
    }

    try {
      final result = await execute(dismissLoading);

      // Handle empty queue result
      if (result is PlayQueueEmpty && context.mounted) {
        showErrorSnackBar(context, t.messages.failedToCreatePlayQueueNoItems);
      }

      await dismissLoading();
      return result;
    } catch (e) {
      appLogger.e('Failed to $action', error: e);

      if (context.mounted) {
        showErrorSnackBar(context, t.messages.failedPlayback(action: action, error: e.toString()));
      }

      await dismissLoading();
      return PlayQueueError(e);
    } finally {
      await dismissLoading();
    }
  }
}
