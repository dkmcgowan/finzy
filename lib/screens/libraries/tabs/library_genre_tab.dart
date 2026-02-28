import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../i18n/strings.g.dart';
import '../../../models/hub.dart';
import '../../../widgets/hub_section.dart';
import '../../main_screen.dart';
import 'base_library_tab.dart';

/// Genre tab for library screen.
/// Shows library content grouped by genre — one section per genre with items.
class LibraryGenreTab extends BaseLibraryTab<Hub> {
  /// When set, tapping a genre header shows that genre's grid inline (Browse style) instead of pushing a route.
  final void Function(Hub hub)? onGenreHeaderTap;

  const LibraryGenreTab({
    super.key,
    required super.library,
    super.onDataLoaded,
    super.isActive,
    super.suppressAutoFocus,
    super.onBack,
    this.onGenreHeaderTap,
  });

  @override
  State<LibraryGenreTab> createState() => _LibraryGenreTabState();
}

class _LibraryGenreTabState extends BaseLibraryTabState<Hub, LibraryGenreTab> {
  final List<GlobalKey<HubSectionState>> _hubKeys = [];

  static const int _itemsPerGenre = 20;

  @override
  IconData get emptyIcon => Symbols.category_rounded;

  @override
  String get emptyMessage => t.libraries.noGenres;

  @override
  String get errorContext => t.libraries.tabs.genres;

  @override
  Future<List<Hub>> loadData() async {
    final client = getClientForLibrary();
    final sectionId = widget.library.key;
    final type = widget.library.type.toLowerCase();
    final typeId = type == 'movie' ? '1' : (type == 'show' ? '2' : '');

    final genreValues = await client.getFilterValues('genre:$sectionId');
    if (genreValues.isEmpty) return [];

    final hubs = <Hub>[];
    for (final g in genreValues) {
      final genreName = g.title.isNotEmpty ? g.title : g.key;
      final filters = <String, String>{
        'genre': g.key,
        if (typeId.isNotEmpty) 'type': typeId,
      };
      final items = await client.getLibraryContent(
        sectionId,
        size: _itemsPerGenre,
        filters: filters,
      );
      if (items.isEmpty) continue;
      hubs.add(Hub(
        hubKey: 'genre_${sectionId}_${g.key}',
        title: genreName,
        type: type,
        hubIdentifier: 'genre',
        size: items.length,
        more: true,
        items: items,
        serverId: widget.library.serverId,
        serverName: widget.library.serverName,
      ));
    }

    return hubs;
  }

  void _ensureHubKeys(int count) {
    while (_hubKeys.length < count) {
      _hubKeys.add(GlobalKey<HubSectionState>());
    }
  }

  bool _handleVerticalNavigation(int hubIndex, bool isUp) {
    final targetIndex = isUp ? hubIndex - 1 : hubIndex + 1;
    if (targetIndex < 0) return false;
    if (targetIndex >= _hubKeys.length) return true;
    final targetState = _hubKeys[targetIndex].currentState;
    if (targetState != null) {
      targetState.requestFocusFromMemory();
      return true;
    }
    return true;
  }

  void _navigateToSidebar() {
    MainScreenFocusScope.of(context)?.focusSidebar();
  }

  @override
  void focusFirstItem() {
    if (_hubKeys.isNotEmpty && items.isNotEmpty) {
      _hubKeys.first.currentState?.requestFocusAt(0);
    }
  }

  static const double _focusDecorationPadding = 8.0;

  @override
  Widget buildContent(List<Hub> items) {
    _ensureHubKeys(items.length);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 8 + _focusDecorationPadding, 0, 8),
      clipBehavior: Clip.none,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final hub = items[index];
        return HubSection(
          key: index < _hubKeys.length ? _hubKeys[index] : null,
          hub: hub,
          icon: Symbols.category_rounded,
          onRefresh: null,
          onVerticalNavigation: (isUp) => _handleVerticalNavigation(index, isUp),
          onBack: widget.onBack,
          onNavigateUp: index == 0 ? widget.onBack : null,
          onNavigateToSidebar: _navigateToSidebar,
          onHeaderTap: widget.onGenreHeaderTap != null ? () => widget.onGenreHeaderTap!(hub) : null,
        );
      },
    );
  }
}
