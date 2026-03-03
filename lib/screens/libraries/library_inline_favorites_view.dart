import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../models/hub.dart';
import '../../models/media_library.dart';
import '../../models/media_metadata.dart';
import '../../providers/settings_provider.dart';
import '../../screens/main_screen.dart';
import '../../utils/grid_size_calculator.dart';
import '../../utils/layout_constants.dart';
import '../../utils/provider_extensions.dart';
import '../../widgets/focusable_media_card.dart';

/// Inline view for a library's favorites from the global Favorites sidebar (Jellyfin).
/// Shows back button + library title + grid of favorites. Back returns to Favorites list.
class LibraryInlineFavoritesView extends StatefulWidget {
  final Hub hub;
  final MediaLibrary library;
  final VoidCallback onBack;

  /// Called when UP is pressed from the top row (navigate to app bar).
  final VoidCallback? onNavigateUp;

  const LibraryInlineFavoritesView({
    super.key,
    required this.hub,
    required this.library,
    required this.onBack,
    this.onNavigateUp,
  });

  @override
  State<LibraryInlineFavoritesView> createState() => _LibraryInlineFavoritesViewState();
}

class _LibraryInlineFavoritesViewState extends State<LibraryInlineFavoritesView> {
  List<MediaMetadata> _items = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _firstItemFocusNode = FocusNode(debugLabel: 'inline_favorites_first_item');

  void focusFirstItem() {
    if (_items.isNotEmpty) {
      _firstItemFocusNode.requestFocus();
    }
  }

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.hub.items);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _firstItemFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollController.position;
    if (!_isLoadingMore && _hasMore && widget.hub.more && pos.pixels >= pos.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    if (!widget.hub.more) return;

    setState(() {
      _isLoadingMore = true;
      _errorMessage = null;
    });

    try {
      final client = context.getClientForLibrary(widget.library);
      final moreItems = await client.getLibraryFavorites(
        widget.library.key,
        start: _items.length,
        limit: 20,
      );
      final tagged = moreItems
          .map((item) => item.copyWith(
                serverId: widget.library.serverId,
                serverName: widget.library.serverName,
              ))
          .toList();
      if (!mounted) return;
      setState(() {
        _items.addAll(tagged);
        _isLoadingMore = false;
        if (tagged.length < 20) _hasMore = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Symbols.arrow_back_rounded),
                onPressed: widget.onBack,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.hub.title,
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                )
              : _items.isEmpty
                  ? Center(
                      child: Text(
                        'No favorites',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    )
                  : Consumer<SettingsProvider>(
                      builder: (context, settingsProvider, _) {
                        final density = settingsProvider.libraryDensity;
                        final episodePosterMode = settingsProvider.episodePosterMode;
                        final useWideLayout = _items.any((item) =>
                            item.usesWideAspectRatio(episodePosterMode));
                        final maxCrossAxisExtent =
                            GridSizeCalculator.getMaxCrossAxisExtent(context, density);
                        if (useWideLayout) {
                          final wideExtent = GridSizeCalculator.getMaxCrossAxisExtentWithPadding(
                                  context, density, 16) *
                              1.8;
                          final availableWidth = MediaQuery.of(context).size.width - 32;
                          final columnCount = GridSizeCalculator.getColumnCount(availableWidth, wideExtent);
                          return GridView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: wideExtent,
                              childAspectRatio: 16 / 9,
                              mainAxisSpacing: GridLayoutConstants.mainAxisSpacing,
                              crossAxisSpacing: GridLayoutConstants.crossAxisSpacing,
                            ),
                            itemCount: _items.length + (_hasMore && _isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _items.length) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  ),
                                );
                              }
                              final item = _items[index];
                              final isFirstRow = GridSizeCalculator.isFirstRow(index, columnCount);
                              final isFirstColumn = index % columnCount == 0;
                              return FocusableMediaCard(
                                key: Key(item.itemId),
                                item: item,
                                focusNode: index == 0 ? _firstItemFocusNode : null,
                                onListRefresh: () async {
                                  _items = List.from(widget.hub.items);
                                  _hasMore = widget.hub.more;
                                  await _loadMore();
                                },
                                onBack: widget.onBack,
                                onNavigateUp: isFirstRow ? widget.onNavigateUp : null,
                                onNavigateLeft: isFirstColumn ? () => MainScreenFocusScope.of(context)?.focusSidebar() : null,
                              );
                            },
                          );
                        }
                        final availableWidth = MediaQuery.of(context).size.width - 32;
                        final columnCount = GridSizeCalculator.getColumnCount(availableWidth, maxCrossAxisExtent);
                        return GridView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: maxCrossAxisExtent,
                            childAspectRatio: GridLayoutConstants.posterAspectRatio,
                            mainAxisSpacing: GridLayoutConstants.mainAxisSpacing,
                            crossAxisSpacing: GridLayoutConstants.crossAxisSpacing,
                          ),
                          itemCount: _items.length + (_hasMore && _isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _items.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              );
                            }
                            final item = _items[index];
                            final isFirstRow = GridSizeCalculator.isFirstRow(index, columnCount);
                            final isFirstColumn = index % columnCount == 0;
                            return FocusableMediaCard(
                              key: Key(item.itemId),
                              item: item,
                              focusNode: index == 0 ? _firstItemFocusNode : null,
                              onListRefresh: () async {
                                _items = List.from(widget.hub.items);
                                _hasMore = widget.hub.more;
                                await _loadMore();
                              },
                              onBack: widget.onBack,
                              onNavigateUp: isFirstRow ? widget.onNavigateUp : null,
                              onNavigateLeft: isFirstColumn ? () => MainScreenFocusScope.of(context)?.focusSidebar() : null,
                            );
                          },
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
