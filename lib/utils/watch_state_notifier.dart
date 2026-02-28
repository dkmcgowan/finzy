import '../models/media_metadata.dart';
import 'app_logger.dart';
import 'base_notifier.dart';
import 'hierarchical_event_mixin.dart';

/// Types of watch state changes
enum WatchStateChangeType { watched, unwatched, progressUpdate }

/// Event representing a watch state change with parent chain for hierarchical invalidation
class WatchStateEvent with HierarchicalEventMixin {
  /// The item that changed
  @override
  final String itemId;

  /// Composite key: serverId:itemId
  @override
  final String globalKey;

  /// Server this item belongs to
  @override
  final String serverId;

  /// Type of change
  final WatchStateChangeType changeType;

  /// Parent chain for hierarchical invalidation
  /// For an episode: [seasonRatingKey, showRatingKey]
  /// For a season: [showRatingKey]
  /// For a movie: []
  @override
  final List<String> parentChain;

  /// Media type that changed
  final String mediaType;

  /// New progress value (for progressUpdate)
  final int? viewOffset;

  /// Whether item is now considered watched (>90% progress or marked)
  final bool? isNowWatched;

  WatchStateEvent({
    required this.itemId,
    required this.serverId,
    required this.changeType,
    required this.parentChain,
    required this.mediaType,
    this.viewOffset,
    this.isNowWatched,
  }) : globalKey = '$serverId:$itemId';

  @override
  String toString() => 'WatchStateEvent($changeType, $globalKey, parents: $parentChain)';
}

/// Notifier for watch state changes across the app.
///
/// Singleton pattern following [LibraryRefreshNotifier]. Screens subscribe
/// to receive events when items are marked watched/unwatched or progress updates.
class WatchStateNotifier extends BaseNotifier<WatchStateEvent> {
  static final WatchStateNotifier _instance = WatchStateNotifier._internal();

  factory WatchStateNotifier() => _instance;

  WatchStateNotifier._internal();

  /// Filter for events affecting a specific server
  Stream<WatchStateEvent> forServer(String serverId) => stream.where((e) => e.serverId == serverId);

  /// Filter for events affecting a specific item or its children
  Stream<WatchStateEvent> forItem(String itemId) => stream.where((e) => e.affectsItem(itemId));

  /// Emit a watch state event with logging
  @override
  void notify(WatchStateEvent event) {
    appLogger.d('WatchStateNotifier: $event');
    super.notify(event);
  }

  /// Helper to emit a watched/unwatched event from metadata
  void notifyWatched({required MediaMetadata metadata, bool isNowWatched = true}) {
    notify(
      WatchStateEvent(
        itemId: metadata.itemId,
        serverId: metadata.serverId ?? '',
        changeType: isNowWatched ? WatchStateChangeType.watched : WatchStateChangeType.unwatched,
        parentChain: _buildParentChain(metadata),
        mediaType: metadata.type,
        isNowWatched: isNowWatched,
      ),
    );
  }

  /// Helper to emit a progress update event
  void notifyProgress({required MediaMetadata metadata, required int viewOffset, required int duration}) {
    const threshold = 0.9;
    final isNowWatched = duration > 0 && (viewOffset / duration) >= threshold;

    notify(
      WatchStateEvent(
        itemId: metadata.itemId,
        serverId: metadata.serverId ?? '',
        changeType: WatchStateChangeType.progressUpdate,
        parentChain: _buildParentChain(metadata),
        mediaType: metadata.type,
        viewOffset: viewOffset,
        isNowWatched: isNowWatched,
      ),
    );
  }

  /// Build parent chain from metadata's parent keys
  List<String> _buildParentChain(MediaMetadata metadata) {
    final chain = <String>[];
    if (metadata.seasonId != null) {
      chain.add(metadata.seasonId!);
    }
    if (metadata.seriesId != null) {
      chain.add(metadata.seriesId!);
    }
    return chain;
  }
}
