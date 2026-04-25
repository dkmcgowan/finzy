import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/media_metadata.dart';
import '../providers/settings_provider.dart';
import '../widgets/desktop_app_bar.dart';
import '../i18n/strings.g.dart';
import '../utils/error_message_utils.dart';
import 'base_media_list_detail_screen.dart';
import 'focusable_detail_screen_mixin.dart';
import '../mixins/grid_focus_node_mixin.dart';

/// Screen to display the contents of a collection
class CollectionDetailScreen extends StatefulWidget {
  final MediaMetadata collection;

  const CollectionDetailScreen({super.key, required this.collection});

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends BaseMediaListDetailScreen<CollectionDetailScreen>
    with
        StandardItemLoader<CollectionDetailScreen>,
        GridFocusNodeMixin<CollectionDetailScreen>,
        FocusableDetailScreenMixin<CollectionDetailScreen> {
  @override
  MediaMetadata get mediaItem => widget.collection;

  @override
  String get title => widget.collection.title;

  @override
  String get emptyMessage => t.collections.empty;

  @override
  bool get hasItems => items.isNotEmpty;

  @override
  int get appBarButtonCount => 0; // Simple layout: back + title + grid (matches former inline view)

  @override
  void dispose() {
    disposeFocusResources();
    super.dispose();
  }

  @override
  Future<List<MediaMetadata>> fetchItems() async {
    return await client.getCollectionItems(widget.collection.itemId);
  }

  @override
  Future<void> loadItems() async {
    await super.loadItems();
    autoFocusFirstItemAfterLoad();
  }

  @override
  String getLoadErrorMessage(Object error) {
    return t.collections.failedToLoadItems(error: safeUserMessage(error));
  }

  @override
  String getLoadSuccessMessage(int itemCount) {
    return 'Loaded $itemCount items for collection: ${widget.collection.title}';
  }

  @override
  List<AppBarButtonConfig> getAppBarButtons() => [];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context);
      },
      child: Scaffold(
        body: CustomScrollView(
          controller: scrollController,
          // Flutter deprecated cacheExtent on scrollables; keep until a replacement lands.
          // ignore: deprecated_member_use
          cacheExtent: context.read<SettingsProvider>().gridPreloadCacheExtent,
          slivers: [
            CustomAppBar(
              title: Text(widget.collection.title),
              leading: buildFocusableLeading(context),
              actions: buildFocusableAppBarActions(),
            ),
            ...buildStateSlivers(),
            if (items.isNotEmpty)
              buildFocusableGrid(
                items: items,
                onRefresh: updateItem,
                collectionId: widget.collection.itemId,
                onListRefresh: loadItems,
              ),
          ],
        ),
      ),
    );
  }
}
