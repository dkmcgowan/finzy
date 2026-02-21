import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../models/plex_metadata.dart';
import '../../../utils/library_refresh_notifier.dart';
import '../../../widgets/focusable_media_card.dart';
import '../../../i18n/strings.g.dart';
import '../adaptive_media_grid.dart';
import 'base_library_tab.dart';
import 'library_grid_tab_state.dart';

/// Collections tab for library screen
/// Shows collections for the current library
class LibraryCollectionsTab extends BaseLibraryTab<PlexMetadata> {
  /// When set, tapping a collection shows it inline in the library (no push to detail screen).
  final void Function(PlexMetadata)? onCollectionTap;

  const LibraryCollectionsTab({
    super.key,
    required super.library,
    super.viewMode,
    super.density,
    super.onDataLoaded,
    super.isActive,
    super.suppressAutoFocus,
    super.onBack,
    this.onCollectionTap,
  });

  @override
  State<LibraryCollectionsTab> createState() => _LibraryCollectionsTabState();
}

class _LibraryCollectionsTabState extends LibraryGridTabState<PlexMetadata, LibraryCollectionsTab> {
  @override
  String get focusNodeDebugLabel => 'collections_first_item';

  @override
  IconData get emptyIcon => Symbols.collections_rounded;

  @override
  String get emptyMessage => t.libraries.noCollections;

  @override
  String get errorContext => t.collections.title;

  @override
  Stream<void>? getRefreshStream() => LibraryRefreshNotifier().collectionsStream;

  @override
  Future<List<PlexMetadata>> loadData() async {
    final client = getClientForLibrary();
    // Jellyfin: when this is the top-level Collections library, load all BoxSets (actual collections)
    final t = widget.library.type.toLowerCase();
    if (client.isJellyfin && (t == 'collection' || t == 'boxsets')) {
      return await client.getGlobalCollections();
    }
    return await client.getLibraryCollections(widget.library.key);
  }

  @override
  Widget buildGridItem(BuildContext context, PlexMetadata item, int index, [GridItemContext? gridContext]) {
    return FocusableMediaCard(
      key: Key(item.ratingKey),
      item: item,
      focusNode: index == 0 ? firstItemFocusNode : null,
      onListRefresh: loadItems,
      onBack: widget.onBack,
      onNavigateLeft: gridContext?.isFirstColumn == true ? gridContext?.navigateToSidebar : null,
      onTapOverride: widget.onCollectionTap != null ? () => widget.onCollectionTap!(item) : null,
    );
  }
}
