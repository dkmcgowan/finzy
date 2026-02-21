import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../models/plex_library.dart';
import '../../models/plex_metadata.dart';
import '../../models/plex_playlist.dart';
import '../../providers/settings_provider.dart';
import '../../services/media_server_client.dart';
import '../../utils/grid_size_calculator.dart';
import '../../utils/layout_constants.dart';
import '../../utils/provider_extensions.dart';
import '../../widgets/focusable_media_card.dart';

/// Inline view for a single playlist or collection inside the library screen.
/// Shows back button + title + grid of items (same layout as Browse), without pushing a new route.
class LibraryInlineListView extends StatefulWidget {
  final PlexLibrary library;
  final dynamic item; // PlexPlaylist or PlexMetadata (collection)
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
  List<PlexMetadata> _items = [];
  bool _isLoading = true;
  String? _errorMessage;
  /// Fetched series metadata for show cards that lacked unwatched count (playlist API often omits UserData).
  Map<String, PlexMetadata> _enrichedShowCounts = {};

  String get _title {
    if (widget.item is PlexPlaylist) {
      return (widget.item as PlexPlaylist).title;
    }
    return (widget.item as PlexMetadata).title;
  }

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  /// Collapse playlist items so episodes/seasons show as one card per show (like collections).
  static List<PlexMetadata> _collapsePlaylistToShows(List<PlexMetadata> raw) {
    final result = <PlexMetadata>[];
    final seenShowKeys = <String>{};
    for (final item in raw) {
      switch (item.mediaType) {
        case PlexMediaType.episode:
          final showKey = item.grandparentRatingKey;
          if (showKey != null && showKey.isNotEmpty && seenShowKeys.add(showKey)) {
            final key = item.key.contains('/') ? '/library/metadata/$showKey' : showKey;
            result.add(item.copyWith(
              ratingKey: showKey,
              key: key,
              type: 'show',
              title: item.grandparentTitle ?? item.title,
              thumb: item.grandparentThumb ?? item.thumb,
              art: item.grandparentArt ?? item.art,
            ));
          }
          break;
        case PlexMediaType.season:
          final showKey = item.parentRatingKey;
          if (showKey != null && showKey.isNotEmpty && seenShowKeys.add(showKey)) {
            final key = item.key.contains('/') ? '/library/metadata/$showKey' : showKey;
            result.add(item.copyWith(
              ratingKey: showKey,
              key: key,
              type: 'show',
              title: item.parentTitle ?? item.title,
              thumb: item.parentThumb ?? item.thumb,
              art: item.art,
              unwatchedCount: item.unwatchedCount,
              leafCount: item.leafCount,
              viewedLeafCount: item.viewedLeafCount,
            ));
          }
          break;
        default:
          // movie, show, collection, etc. — add as-is
          if (item.mediaType == PlexMediaType.show) {
            if (!seenShowKeys.add(item.ratingKey)) continue;
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
      List<PlexMetadata> list;
      if (widget.item is PlexPlaylist) {
        final playlist = widget.item as PlexPlaylist;
        list = await client.getPlaylist(playlist.ratingKey);
        list = _collapsePlaylistToShows(list);
      } else {
        final collection = widget.item as PlexMetadata;
        list = await client.getChildren(collection.ratingKey);
      }
      if (mounted) {
        setState(() {
          _items = list;
          _isLoading = false;
        });
        if (widget.item is PlexPlaylist && list.isNotEmpty) {
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
  Future<void> _enrichShowCounts(MediaServerClient client) async {
    if (!mounted) return;
    final toFetch = <String>[];
    for (final item in _items) {
      if (item.mediaType != PlexMediaType.show) continue;
      if (item.effectiveUnwatchedCount != null) continue;
      final key = item.ratingKey;
      if (key.isEmpty || _enrichedShowCounts.containsKey(key)) continue;
      toFetch.add(key);
    }
    if (toFetch.isEmpty) return;
    final results = await Future.wait(
      toFetch.map((key) => client.getMetadataWithImages(key)),
    );
    if (!mounted) return;
    final next = Map<String, PlexMetadata>.from(_enrichedShowCounts);
    for (var i = 0; i < toFetch.length; i++) {
      final meta = results[i];
      if (meta != null) next[toFetch[i]] = meta;
    }
    if (next.length > _enrichedShowCounts.length) {
      setState(() => _enrichedShowCounts = next);
    }
  }

  /// Items to display: merge enriched series metadata (unwatched count) when available.
  List<PlexMetadata> get _displayItems {
    if (_enrichedShowCounts.isEmpty) return _items;
    return _items.map((item) {
      if (item.mediaType != PlexMediaType.show) return item;
      final enriched = _enrichedShowCounts[item.ratingKey];
      if (enriched == null) return item;
      return item.copyWith(
        unwatchedCount: enriched.unwatchedCount,
        leafCount: enriched.leafCount,
        viewedLeafCount: enriched.viewedLeafCount,
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
                                      key: Key(item.ratingKey),
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
