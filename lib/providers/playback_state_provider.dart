import 'package:flutter/foundation.dart';
import '../models/media_metadata.dart';
import '../models/play_queue_response.dart';
import '../services/jellyfin_client.dart';

/// Playback mode types
enum PlaybackMode {
  playQueue,
}

/// Manages client-side playback queue state.
/// Queues are built locally (Jellyfin has no server-side play queue API).
/// This provider is session-only and does not persist across app restarts.
class PlaybackStateProvider with ChangeNotifier {
  int? _playQueueId;
  int _playQueueTotalCount = 0;
  bool _playQueueShuffled = false;
  int? _currentPlayQueueItemID;
  List<MediaMetadata> _loadedItems = [];
  String? _contextKey;
  PlaybackMode? _playbackMode;

  PlaybackMode? get playbackMode => _playbackMode;
  bool get isShuffleActive => _playQueueShuffled;
  bool get isPlaylistActive => _playbackMode == PlaybackMode.playQueue;
  bool get isQueueActive => _playQueueId != null && _playbackMode == PlaybackMode.playQueue;
  String? get shuffleContextKey => _contextKey;
  int? get playQueueId => _playQueueId;
  int get queueLength => _playQueueTotalCount;

  int get currentPosition {
    if (_currentPlayQueueItemID == null || _loadedItems.isEmpty) return 0;
    final index = _loadedItems.indexWhere((item) => item.playQueueItemID == _currentPlayQueueItemID);
    return index != -1 ? index + 1 : 0;
  }

  void setClient(JellyfinClient client) {
    // Client may be used for future server queue sync.
  }

  void setCurrentItem(MediaMetadata metadata) {
    if (_playbackMode == PlaybackMode.playQueue && metadata.playQueueItemID != null) {
      _currentPlayQueueItemID = metadata.playQueueItemID;
      notifyListeners();
    }
  }

  Future<void> setPlaybackFromPlayQueue(PlayQueueResponse playQueue, String? contextKey) async {
    _playQueueId = playQueue.playQueueID;
    _playQueueTotalCount = playQueue.playQueueTotalCount ?? playQueue.size ?? (playQueue.items?.length ?? 0);
    _playQueueShuffled = playQueue.playQueueShuffled;
    _currentPlayQueueItemID = playQueue.playQueueSelectedItemID;
    _loadedItems = playQueue.items ?? [];
    _contextKey = contextKey;
    _playbackMode = PlaybackMode.playQueue;
    notifyListeners();
  }

  int? _currentIndex() {
    if (_playbackMode != PlaybackMode.playQueue || _loadedItems.isEmpty || _currentPlayQueueItemID == null) {
      return null;
    }
    final idx = _loadedItems.indexWhere((item) => item.playQueueItemID == _currentPlayQueueItemID);
    return idx != -1 ? idx : null;
  }

  /// Gets the next item in the playback queue.
  /// Returns null if queue is exhausted or current item is not in queue.
  Future<MediaMetadata?> getNextEpisode(String currentItemKey, {bool loopQueue = false}) async {
    if (_playbackMode != PlaybackMode.playQueue) return null;

    final currentIndex = _currentIndex();
    if (currentIndex == null) return null;

    if (currentIndex + 1 < _loadedItems.length) {
      return _loadedItems[currentIndex + 1];
    }

    if (loopQueue && _loadedItems.isNotEmpty) {
      return _loadedItems.first;
    }

    return null;
  }

  /// Gets the previous item in the playback queue.
  /// Returns null if at the beginning of the queue.
  Future<MediaMetadata?> getPreviousEpisode(String currentItemKey) async {
    if (_playbackMode != PlaybackMode.playQueue) return null;

    final currentIndex = _currentIndex();
    if (currentIndex == null || currentIndex == 0) return null;

    return _loadedItems[currentIndex - 1];
  }

  void clearShuffle() {
    _playQueueId = null;
    _playQueueTotalCount = 0;
    _playQueueShuffled = false;
    _currentPlayQueueItemID = null;
    _loadedItems = [];
    _contextKey = null;
    _playbackMode = null;
    notifyListeners();
  }
}
