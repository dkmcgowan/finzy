import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/watch_state_notifier.dart';

/// Mixin for screens that need to react to watch state changes.
///
/// Provides automatic subscription management and filtering based on
/// which items the screen cares about.
///
/// Example usage:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with WatchStateAware {
///   List<MediaMetadata> _items = [];
///
///   @override
///   Set<String>? get watchedItemIds =>
///       _items.map((e) => e.itemId).toSet();
///
///   @override
///   void onWatchStateChanged(WatchStateEvent event) {
///     // Refresh affected item
///     _refreshItem(event.itemId);
///   }
/// }
/// ```
mixin WatchStateAware<T extends StatefulWidget> on State<T> {
  StreamSubscription<WatchStateEvent>? _watchStateSubscription;

  /// Override to scope events to a specific server.
  ///
  /// Return null to receive events from all servers.
  String? get watchStateServerId => null;

  /// Override to specify which global keys this screen cares about.
  ///
  /// Use format `serverId:itemId`.
  /// Return null to fall back to [watchedItemIds] matching.
  Set<String>? get watchedGlobalKeys => null;

  /// Override to specify which itemIds this screen cares about.
  ///
  /// Return null to receive ALL events (not recommended for performance).
  /// Return an empty set to receive no events.
  ///
  /// The set should include:
  /// - Direct items displayed (e.g., episode itemIds in a season view)
  /// - Parent items that affect display (e.g., show itemId for continue watching)
  Set<String>? get watchedItemIds;

  /// Called when a relevant watch state change occurs.
  ///
  /// Only called if [watchedItemIds] is null or contains an affected key.
  void onWatchStateChanged(WatchStateEvent event);

  @override
  void initState() {
    super.initState();
    _subscribeToWatchState();
  }

  void _subscribeToWatchState() {
    _watchStateSubscription = WatchStateNotifier().stream.listen((event) {
      if (!mounted) return;

      final serverId = watchStateServerId;
      if (serverId != null && event.serverId != serverId) return;

      final globalKeys = watchedGlobalKeys;
      if (globalKeys != null) {
        if (event.affectsAnyGlobalKey(globalKeys)) {
          onWatchStateChanged(event);
        }
        return;
      }

      final keys = watchedItemIds;
      // If keys is null, receive all events
      // Otherwise, filter to events that affect our keys
      if (keys == null || event.affectsAnyOf(keys)) {
        onWatchStateChanged(event);
      }
    });
  }

  @override
  void dispose() {
    _watchStateSubscription?.cancel();
    _watchStateSubscription = null;
    super.dispose();
  }
}
