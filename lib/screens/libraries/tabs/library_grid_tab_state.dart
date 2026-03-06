import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../adaptive_media_grid.dart';
import '../../../mixins/grid_focus_node_mixin.dart';
import '../../../mixins/library_tab_focus_mixin.dart';
import '../../../providers/settings_provider.dart';
import '../../../utils/grid_size_calculator.dart';
import '../../../utils/layout_constants.dart';
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

  late final ScrollController _gridScrollController = ScrollController();

  @override
  void dispose() {
    _gridScrollController.dispose();
    disposeGridFocusNodes();
    super.dispose();
  }

  /// Estimate scroll offset to bring item at [index] into view (for off-screen items).
  double _estimateScrollOffsetForIndex(int index) {
    if (!mounted) return 0;
    final density = context.read<SettingsProvider>().libraryDensity;
    final maxExtent = GridSizeCalculator.getMaxCrossAxisExtent(context, density);
    final availableWidth = MediaQuery.of(context).size.width - 16;
    final columnCount = GridSizeCalculator.getColumnCount(availableWidth, maxExtent);
    final cellWidth = availableWidth / columnCount;
    final cellHeight = cellWidth / GridLayoutConstants.posterAspectRatio;
    final rowHeight = cellHeight + GridLayoutConstants.mainAxisSpacing;
    final row = index ~/ columnCount;
    return (row * rowHeight).clamp(0.0, double.infinity);
  }

  /// Focus the grid item at [index] (for restoring focus after closing inline view).
  void focusItemAt(int index) {
    if (index < 0 || index >= items.length) {
      focusFirstItem();
      return;
    }
    void request({int retryCount = 0}) {
      if (!mounted) return;
      final node = index == 0 ? firstItemFocusNode : getGridItemFocusNode(index, prefix: focusNodeDebugLabel.replaceAll('_first_item', '_grid_item'));
      final ctx = node.context;
      if (ctx == null && retryCount < 3 && _gridScrollController.hasClients) {
        // Item not built yet (off-screen); scroll to bring it into view, then retry
        final targetOffset = _estimateScrollOffsetForIndex(index);
        final maxExtent = _gridScrollController.position.maxScrollExtent;
        final clamped = targetOffset.clamp(0.0, maxExtent);
        _gridScrollController.jumpTo(clamped);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) request(retryCount: retryCount + 1);
        });
        return;
      }
      if (!node.hasFocus) node.requestFocus();
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, alignment: 0.5);
      } else {
        focusFirstItem();
      }
    }
    request();
    WidgetsBinding.instance.addPostFrameCallback((_) => request(retryCount: 1));
  }

  void focusGridItemByIndex(int index, String prefix) {
    if (index < 0 || index >= items.length) return;
    if (index == 0) {
      firstItemFocusNode.requestFocus();
    } else {
      getGridItemFocusNode(index, prefix: prefix).requestFocus();
    }
  }

  /// True if any grid item (including first) currently has focus.
  /// Used to avoid stealing focus when user has already navigated.
  bool get _hasAnyGridItemFocus {
    if (firstItemFocusNode.hasFocus) return true;
    for (final node in gridItemFocusNodes.values) {
      if (node.hasFocus) return true;
    }
    return false;
  }

  @override
  void focusFirstItem() {
    if (itemCount == 0) return;
    // Don't steal focus if user has already moved to another item
    if (_hasAnyGridItemFocus) return;
    if (shouldRestoreGridFocus && lastFocusedGridIndex! < items.length) {
      focusItemAt(lastFocusedGridIndex!);
    } else {
      super.focusFirstItem();
    }
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
      scrollController: _gridScrollController,
    );
  }
}
