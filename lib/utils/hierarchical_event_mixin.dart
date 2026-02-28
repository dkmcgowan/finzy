/// Mixin providing hierarchical event matching methods.
///
/// Events that represent changes to media items often need to check if they
/// affect a specific item or any of its parents in the hierarchy. This mixin
/// provides common matching logic for such events.
mixin HierarchicalEventMixin {
  /// The itemId of the affected item.
  String get itemId;

  /// Composite key: serverId:itemId.
  String get globalKey;

  /// Server this item belongs to.
  String get serverId;

  /// Parent chain for hierarchical matching.
  /// For an episode: [seasonItemId, showItemId]
  /// For a season: [showItemId]
  /// For a movie: []
  List<String> get parentChain;

  /// Check if this event affects a specific item by itemId.
  bool affectsItem(String itemId) => this.itemId == itemId || parentChain.contains(itemId);

  /// Check if this event affects a specific globalKey.
  bool affectsGlobalKey(String globalKey) =>
      this.globalKey == globalKey || parentChain.any((pk) => '$serverId:$pk' == globalKey);

  /// Check if this event affects any item in a collection.
  bool affectsAnyOf(Iterable<String> itemIds) => itemIds.any(affectsItem);

  /// Check if this event affects any item in a global-key collection.
  bool affectsAnyGlobalKey(Iterable<String> globalKeys) => globalKeys.any(affectsGlobalKey);
}
