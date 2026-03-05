import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../models/playlist.dart';
import '../../../utils/library_refresh_notifier.dart';
import '../../../widgets/focusable_media_card.dart';
import '../../../i18n/strings.g.dart';
import '../adaptive_media_grid.dart';
import 'base_library_tab.dart';
import 'library_grid_tab_state.dart';

/// Playlists tab for library screen
/// Shows playlists that contain items from the current library.
/// Tapping a playlist pushes PlaylistDetailScreen (like movies/shows).
class LibraryPlaylistsTab extends BaseLibraryTab<Playlist> {
  const LibraryPlaylistsTab({
    super.key,
    required super.library,
    super.viewMode,
    super.density,
    super.onDataLoaded,
    super.isActive,
    super.suppressAutoFocus,
    super.onBack,
    super.onBackToNavigation,
  });

  @override
  State<LibraryPlaylistsTab> createState() => _LibraryPlaylistsTabState();
}

class _LibraryPlaylistsTabState extends LibraryGridTabState<Playlist, LibraryPlaylistsTab> {
  @override
  String get focusNodeDebugLabel => 'playlists_first_item';

  @override
  IconData get emptyIcon => Symbols.playlist_play_rounded;

  @override
  String get emptyMessage => t.playlists.noPlaylists;

  @override
  String get errorContext => t.playlists.title;

  @override
  Stream<void>? getRefreshStream() => LibraryRefreshNotifier().playlistsStream;

  @override
  Future<List<Playlist>> loadData() async {
    // Use server-specific client for this library
    final client = getClientForLibrary();

    // Playlists are automatically tagged with server info by JellyfinClient
    return await client.getLibraryPlaylists(playlistType: 'video');
  }

  @override
  Widget buildGridItem(BuildContext context, Playlist playlist, int index, [GridItemContext? gridContext]) {
    final focusNode = index == 0 ? firstItemFocusNode : getGridItemFocusNode(index, prefix: 'playlists_grid_item');
    final gc = gridContext;
    return FocusableMediaCard(
      key: Key(playlist.itemId),
      item: playlist,
      focusNode: focusNode,
      onListRefresh: loadItems,
      onBack: widget.onBackToNavigation ?? widget.onBack,
      onNavigateUp: gc?.isFirstRow == true ? widget.onBack : gc != null ? () => focusGridItemByIndex(gc.index - gc.columnCount, 'playlists_grid_item') : null,
      onNavigateDown: gc != null && !gc.isLastRow ? () => focusGridItemByIndex(gc.index + gc.columnCount, 'playlists_grid_item') : null,
      onNavigateLeft: gc?.isFirstColumn == true ? gc?.navigateToSidebar : gc != null ? () => focusGridItemByIndex(gc.index - 1, 'playlists_grid_item') : null,
      onNavigateRight: gc != null && !gc.isLastColumn ? () => focusGridItemByIndex(gc.index + 1, 'playlists_grid_item') : null,
      onFocusChange: (hasFocus) => trackGridItemFocus(index, hasFocus),
      scrollTopOffset: gc?.isFirstRow == true ? 8 : null,
    );
  }
}
