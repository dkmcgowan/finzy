import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../models/plex_library.dart';
import '../../models/plex_metadata.dart';
import '../../models/plex_playlist.dart';
import '../../providers/settings_provider.dart';
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
                  : _items.isEmpty
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
                                return GridView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: maxCrossAxisExtent,
                                    childAspectRatio: GridLayoutConstants.posterAspectRatio,
                                    mainAxisSpacing: GridLayoutConstants.mainAxisSpacing,
                                    crossAxisSpacing: GridLayoutConstants.crossAxisSpacing,
                                  ),
                                  itemCount: _items.length,
                                  itemBuilder: (context, index) {
                                    final item = _items[index];
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
