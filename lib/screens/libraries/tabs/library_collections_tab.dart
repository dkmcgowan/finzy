import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../models/media_metadata.dart';
import '../../../utils/library_refresh_notifier.dart';
import '../../../widgets/focusable_media_card.dart';
import '../../../i18n/strings.g.dart';
import '../adaptive_media_grid.dart';
import 'base_library_tab.dart';
import 'library_grid_tab_state.dart';

/// Collections tab for library screen
/// Shows collections for the current library.
/// Tapping a collection pushes CollectionDetailScreen (like movies/shows).
class LibraryCollectionsTab extends BaseLibraryTab<MediaMetadata> {
  const LibraryCollectionsTab({
    super.key,
    required super.library,
    super.viewMode,
    super.density,
    super.onDataLoaded,
    super.isActive,
    super.suppressAutoFocus,
    super.onBack,
  });

  @override
  State<LibraryCollectionsTab> createState() => _LibraryCollectionsTabState();
}

class _LibraryCollectionsTabState extends LibraryGridTabState<MediaMetadata, LibraryCollectionsTab> {
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
  Future<List<MediaMetadata>> loadData() async {
    final client = getClientForLibrary();
    final t = widget.library.type.toLowerCase();
    if (t == 'collection' || t == 'boxsets') {
      return await client.getGlobalCollections();
    }
    return await client.getLibraryCollections(widget.library.key);
  }

  @override
  Widget buildGridItem(BuildContext context, MediaMetadata item, int index, [GridItemContext? gridContext]) {
    final focusNode = index == 0 ? firstItemFocusNode : getGridItemFocusNode(index, prefix: 'collections_grid_item');
    return FocusableMediaCard(
      key: Key(item.itemId),
      item: item,
      focusNode: focusNode,
      onListRefresh: loadItems,
      onBack: widget.onBack,
      onNavigateUp: gridContext?.isFirstRow == true ? widget.onBack : null,
      onNavigateLeft: gridContext?.isFirstColumn == true ? gridContext?.navigateToSidebar : null,
      scrollTopOffset: gridContext?.isFirstRow == true ? 8 : null,
    );
  }
}
