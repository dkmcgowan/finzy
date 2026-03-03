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
/// Shows playlists that contain items from the current library
class LibraryPlaylistsTab extends BaseLibraryTab<Playlist> {
  /// When set, tapping a playlist shows it inline in the library (no push to detail screen).
  /// Receives (item, index) so the caller can restore focus to that index when closing.
  final void Function(Playlist item, int index)? onPlaylistTap;

  const LibraryPlaylistsTab({
    super.key,
    required super.library,
    super.viewMode,
    super.density,
    super.onDataLoaded,
    super.isActive,
    super.suppressAutoFocus,
    super.onBack,
    this.onPlaylistTap,
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
    return FocusableMediaCard(
      key: Key(playlist.itemId),
      item: playlist,
      focusNode: focusNode,
      onListRefresh: loadItems,
      onBack: widget.onBack,
      onNavigateUp: gridContext?.isFirstRow == true ? widget.onBack : null,
      onNavigateLeft: gridContext?.isFirstColumn == true ? gridContext?.navigateToSidebar : null,
      onTapOverride: widget.onPlaylistTap != null ? () => widget.onPlaylistTap!(playlist, index) : null,
    );
  }
}
