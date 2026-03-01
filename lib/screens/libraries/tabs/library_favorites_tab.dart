import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../models/media_metadata.dart';
import '../../../widgets/focusable_media_card.dart';
import '../../../i18n/strings.g.dart';
import '../adaptive_media_grid.dart';
import 'base_library_tab.dart';
import 'library_grid_tab_state.dart';

/// Favorites tab for library screen.
/// Shows favorite movies or shows for the current library.
class LibraryFavoritesTab extends BaseLibraryTab<MediaMetadata> {
  const LibraryFavoritesTab({
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
  State<LibraryFavoritesTab> createState() => _LibraryFavoritesTabState();
}

class _LibraryFavoritesTabState extends LibraryGridTabState<MediaMetadata, LibraryFavoritesTab> {
  @override
  String get focusNodeDebugLabel => 'favorites_first_item';

  @override
  IconData get emptyIcon => Symbols.favorite_rounded;

  @override
  String get emptyMessage => t.libraries.noFavorites;

  @override
  String get errorContext => t.libraries.tabs.favorites;

  @override
  Future<List<MediaMetadata>> loadData() async {
    final client = getClientForLibrary();
    return await client.getLibraryFavorites(widget.library.key);
  }

  @override
  Widget buildGridItem(BuildContext context, MediaMetadata item, int index, [GridItemContext? gridContext]) {
    final focusNode = index == 0 ? firstItemFocusNode : getGridItemFocusNode(index, prefix: 'favorites_grid_item');
    return FocusableMediaCard(
      key: Key(item.itemId),
      item: item,
      focusNode: focusNode,
      onListRefresh: loadItems,
      onBack: widget.onBack,
      onNavigateUp: gridContext?.isFirstRow == true ? widget.onBack : null,
      onNavigateLeft: gridContext?.isFirstColumn == true ? gridContext?.navigateToSidebar : null,
    );
  }
}
