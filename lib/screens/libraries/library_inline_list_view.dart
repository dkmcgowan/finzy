import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../models/media_library.dart';
import '../../models/media_metadata.dart';
import '../../models/playlist.dart';
import '../../providers/settings_provider.dart';
import '../../services/api_cache.dart';
import '../../services/jellyfin_client.dart';
import '../../utils/grid_size_calculator.dart';
import '../../utils/layout_constants.dart';
import '../../utils/provider_extensions.dart';
import '../../widgets/focusable_media_card.dart';

/// Inline view for a single playlist or collection inside the library screen.
/// Shows back button + title + grid of items (same layout as Browse), without pushing a new route.
class LibraryInlineListView extends StatefulWidget {
  final MediaLibrary library;
  final dynamic item; // Playlist or MediaMetadata (collection)
  final VoidCallback onBack;

  const LibraryInlineListView({
    super.key,
    required this.library,
    required this.item,
    required this.onBack,
  });

  @override
  State<LibraryInlineListView> createState() => _LibraryInlineListViewState();
}

class _LibraryInlineListViewState extends State<LibraryInlineListView> {
  List<MediaMetadata> _items = [];
  bool _isLoading = true;
  String? _errorMessage;
  /// Fetched series metadata for show cards that lacked unwatched count (playlist API often omits UserData).
  Map<String, MediaMetadata> _enrichedShowCounts = {};

  String get _title {
    if (widget.item is Playlist) {
      return (widget.item as Playlist).title;
    }
    return (widget.item as MediaMetadata).title;
  }

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  /// Collapse playlist items so episodes/seasons show as one card per show (like collections).
  static List<MediaMetadata> _collapsePlaylistToShows(List<MediaMetadata> raw) {
    final result = <MediaMetadata>[];
    final seenShowKeys = <String>{};
    for (final item in raw) {
      switch (item.mediaType) {
        case MediaType.episode:
          final showKey = item.seriesId;
          if (showKey != null && showKey.isNotEmpty && seenShowKeys.add(showKey)) {
            final key = item.key.contains('/') ? '${ApiCache.itemPrefix}$showKey' : showKey;
            result.add(item.copyWith(
              itemId: showKey,
              key: key,
              type: 'show',
              title: item.seriesTitle ?? item.title,
              thumb: item.seriesImageId ?? item.thumb,
              art: item.seriesArt ?? item.art,
            ));
          }
          break;
        case MediaType.season:
          final showKey = item.seasonId;
          if (showKey != null && showKey.isNotEmpty && seenShowKeys.add(showKey)) {
            final key = item.key.contains('/') ? '${ApiCache.itemPrefix}$showKey' : showKey;
            result.add(item.copyWith(
              itemId: showKey,
              key: key,
              type: 'show',
              title: item.seasonTitle ?? item.title,
              thumb: item.seasonImageId ?? item.thumb,
              art: item.art,
              unwatchedCount: item.unwatchedCount,
              leafCount: item.leafCount,
              watchedEpisodeCount: item.watchedEpisodeCount,
            ));
          }
          break;
        default:
          // movie, show, collection, etc. — add as-is
          if (item.mediaType == MediaType.show) {
            if (!seenShowKeys.add(item.itemId)) continue;
          }
          result.add(item);
      }
    }
    return result;
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _enrichedShowCounts = {};
    });
    try {
      final client = context.getClientForLibrary(widget.library);
      List<MediaMetadata> list;
      if (widget.item is Playlist) {
        final playlist = widget.item as Playlist;
        list = await client.getPlaylist(playlist.itemId);
        list = _collapsePlaylistToShows(list);
      } else {
        final collection = widget.item as MediaMetadata;
        list = await client.getChildren(collection.itemId);
      }
      if (mounted) {
        setState(() {
          _items = list;
          _isLoading = false;
        });
        if (widget.item is Playlist && list.isNotEmpty) {
          await _enrichShowCounts(client);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Fetch series metadata for show cards that lack unwatched count so the badge can display.
  Future<void> _enrichShowCounts(JellyfinClient client) async {
    if (!mounted) return;
    final toFetch = <String>[];
    for (final item in _items) {
      if (item.mediaType != MediaType.show) continue;
      if (item.effectiveUnwatchedCount != null) continue;
      final key = item.itemId;
      if (key.isEmpty || _enrichedShowCounts.containsKey(key)) continue;
      toFetch.add(key);
    }
    if (toFetch.isEmpty) return;
    final results = await Future.wait(
      toFetch.map((key) => client.getMetadataWithImages(key)),
    );
    if (!mounted) return;
    final next = Map<String, MediaMetadata>.from(_enrichedShowCounts);
    for (var i = 0; i < toFetch.length; i++) {
      final meta = results[i];
      if (meta != null) next[toFetch[i]] = meta;
    }
    if (next.length > _enrichedShowCounts.length) {
      setState(() => _enrichedShowCounts = next);
    }
  }

  /// Items to display: merge enriched series metadata (unwatched count) when available.
  List<MediaMetadata> get _displayItems {
    if (_enrichedShowCounts.isEmpty) return _items;
    return _items.map((item) {
      if (item.mediaType != MediaType.show) return item;
      final enriched = _enrichedShowCounts[item.itemId];
      if (enriched == null) return item;
      return item.copyWith(
        unwatchedCount: enriched.unwatchedCount,
        leafCount: enriched.leafCount,
        watchedEpisodeCount: enriched.watchedEpisodeCount,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Back + title row (same idea as "Browse" header)
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
                  _title,
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ),
                    )
                  : _displayItems.isEmpty
                      ? Center(
                          child: Text(
                            'No items',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            return Consumer<SettingsProvider>(
                              builder: (context, settingsProvider, _) {
                                final density = settingsProvider.libraryDensity;
                                final maxCrossAxisExtent = GridSizeCalculator.getMaxCrossAxisExtent(context, density);
                                final displayItems = _displayItems;
                                return GridView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: maxCrossAxisExtent,
                                    childAspectRatio: GridLayoutConstants.posterAspectRatio,
                                    mainAxisSpacing: GridLayoutConstants.mainAxisSpacing,
                                    crossAxisSpacing: GridLayoutConstants.crossAxisSpacing,
                                  ),
                                  itemCount: displayItems.length,
                                  itemBuilder: (context, index) {
                                    final item = displayItems[index];
                                    return FocusableMediaCard(
                                      key: Key(item.itemId),
                                      item: item,
                                      onListRefresh: _loadItems,
                                      onBack: widget.onBack,
                                    );
                                  },
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
