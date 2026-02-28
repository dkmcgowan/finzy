import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/deletion_notifier.dart';

/// Mixin for screens that need to react to deletion events.
///
/// Provides automatic subscription management and filtering based on
/// which items the screen cares about.
///
/// Example usage:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with DeletionAware {
///   List<MediaMetadata> _items = [];
///
///   @override
///   Set<String>? get deletionItemIds =>
///       _items.map((e) => e.itemId).toSet();
///
///   @override
///   void onDeletionEvent(DeletionEvent event) {
///     setState(() {
///       _items.removeWhere((e) => e.itemId == event.itemId);
///     });
///   }
/// }
/// ```
mixin DeletionAware<T extends StatefulWidget> on State<T> {
  StreamSubscription<DeletionEvent>? _deletionSubscription;

  /// Override to scope events to a specific server.
  ///
  /// Return null to receive events from all servers.
  String? get deletionServerId => null;

  /// Override to specify which global keys this screen cares about.
  ///
  /// Use format `serverId:itemId`.
  /// Return null to fall back to [deletionItemIds] matching.
  Set<String>? get deletionGlobalKeys => null;

  /// Override to specify which itemIds this screen cares about.
  ///
  /// Return null to receive ALL events (not recommended for performance).
  /// Return an empty set to receive no events.
  ///
  /// The set should include:
  /// - Direct items displayed (e.g., episode itemIds in a season view)
  /// - Parent items that affect display (e.g., show itemId for seasons)
  Set<String>? get deletionItemIds;

  /// Called when a relevant deletion event occurs.
  ///
  /// Only called if [deletionItemIds] is null or contains an affected key.
  void onDeletionEvent(DeletionEvent event);

  @override
  void initState() {
    super.initState();
    _subscribeToDeletions();
  }

  void _subscribeToDeletions() {
    _deletionSubscription = DeletionNotifier().stream.listen((event) {
      if (!mounted) return;

      final serverId = deletionServerId;
      if (serverId != null && event.serverId != serverId) return;

      final globalKeys = deletionGlobalKeys;
      if (globalKeys != null) {
        if (event.affectsAnyGlobalKey(globalKeys)) {
          onDeletionEvent(event);
        }
        return;
      }

      final itemIds = deletionItemIds;
      // If keys is null, receive all events
      // Otherwise, filter to events that affect our keys
      if (itemIds == null || event.affectsAnyOf(itemIds)) {
        onDeletionEvent(event);
      }
    });
  }

  @override
  void dispose() {
    _deletionSubscription?.cancel();
    _deletionSubscription = null;
    super.dispose();
  }
}
