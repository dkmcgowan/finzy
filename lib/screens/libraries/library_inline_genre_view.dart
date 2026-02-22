import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../models/plex_hub.dart';
import '../../models/plex_library.dart';
import '../../models/plex_metadata.dart';
import '../../providers/settings_provider.dart';
import '../../utils/grid_size_calculator.dart';
import '../../utils/layout_constants.dart';
import '../../utils/provider_extensions.dart';
import '../../widgets/focusable_media_card.dart';

/// Inline view for a genre inside the library screen (Genre tab).
/// Shows back button + genre title + grid of movies/shows (Browse style). No dialog; Back returns to Genre tab.
class LibraryInlineGenreView extends StatefulWidget {
  final PlexHub hub;
  final PlexLibrary library;
  final VoidCallback onBack;

  const LibraryInlineGenreView({
    super.key,
    required this.hub,
    required this.library,
    required this.onBack,
  });

  @override
  State<LibraryInlineGenreView> createState() => _LibraryInlineGenreViewState();
}

class _LibraryInlineGenreViewState extends State<LibraryInlineGenreView> {
  List<PlexMetadata> _items = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;
  final ScrollController _scrollController = ScrollController();

  /// Parse hubKey "genre_sectionId_genreKey" into (sectionId, genreKey). GenreKey may contain underscores.
  static (String sectionId, String genreKey)? _parseGenreHubKey(String hubKey) {
    if (!hubKey.startsWith('genre_')) return null;
    final parts = hubKey.split('_');
    if (parts.length < 3) return null;
    final sectionId = parts[1];
    final genreKey = parts.sublist(2).join('_');
    return (sectionId, genreKey);
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
    final parsed = _parseGenreHubKey(widget.hub.hubKey);
    if (parsed == null || !widget.hub.more) return;

    final (sectionId, genreKey) = parsed;
    final type = widget.library.type.toLowerCase();
    final typeId = type == 'movie' ? '1' : (type == 'show' ? '2' : '');

    setState(() {
      _isLoadingMore = true;
      _errorMessage = null;
    });

    try {
      final client = context.getClientForLibrary(widget.library);
      final moreItems = await client.getLibraryContent(
        sectionId,
        start: _items.length,
        size: 20,
        filters: {
          'genre': genreKey,
          if (typeId.isNotEmpty) 'type': typeId,
        },
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(moreItems);
        _isLoadingMore = false;
        if (moreItems.length < 20) _hasMore = false;
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
                        'No items',
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
                                context, density, 16) * 1.8;
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
                              return FocusableMediaCard(
                                key: Key(item.ratingKey),
                                item: item,
                                onListRefresh: () async {
                                  _items = List.from(widget.hub.items);
                                  await _loadMore();
                                },
                                onBack: widget.onBack,
                              );
                            },
                          );
                        }
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
                            return FocusableMediaCard(
                              key: Key(item.ratingKey),
                              item: item,
                              onListRefresh: () async {
                                _items = List.from(widget.hub.items);
                                await _loadMore();
                              },
                              onBack: widget.onBack,
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
