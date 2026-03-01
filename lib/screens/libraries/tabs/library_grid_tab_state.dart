import 'package:flutter/material.dart';

import '../adaptive_media_grid.dart';
import '../../../mixins/grid_focus_node_mixin.dart';
import '../../../mixins/library_tab_focus_mixin.dart';
import 'base_library_tab.dart';

/// Shared state implementation for simple grid-based library tabs.
///
/// Handles focus, item counting, and grid wiring so individual tabs only
/// implement data loading and per-item rendering.
abstract class LibraryGridTabState<T, W extends BaseLibraryTab<T>> extends BaseLibraryTabState<T, W>
    with LibraryTabFocusMixin, GridFocusNodeMixin {
  /// Build a single grid item.
  /// [gridContext] provides information about the item's position in the grid
  /// and callbacks for navigation (e.g., navigating to sidebar from first column).
  Widget buildGridItem(BuildContext context, T item, int index, [GridItemContext? gridContext]);

  @override
  int get itemCount => items.length;

  @override
  void dispose() {
    disposeGridFocusNodes();
    super.dispose();
  }

  @override
  Widget buildContent(List<T> items) {
    cleanupGridFocusNodes(items.length);
    return AdaptiveMediaGrid<T>(
      items: items,
      itemBuilder: (context, item, index, [gridContext]) => buildGridItem(context, item, index, gridContext),
      onRefresh: loadItems,
      firstItemFocusNode: firstItemFocusNode,
      onBack: widget.onBack,
      enableSidebarNavigation: true,
    );
  }
}
