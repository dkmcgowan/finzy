import 'package:flutter/material.dart';

/// ListView that scrolls to show [initialIndex] when first built.
/// Uses [itemExtent] so the scroll extent is known from the start, enabling
/// scroll-to-index for items lower in the list.
class ScrollToIndexListView extends StatefulWidget {
  final int itemCount;
  final int initialIndex;
  final IndexedWidgetBuilder itemBuilder;
  /// Height of each item. Defaults to 56. Use 72 for items with subtitles.
  final double itemExtent;

  const ScrollToIndexListView({
    super.key,
    required this.itemCount,
    required this.initialIndex,
    required this.itemBuilder,
    this.itemExtent = 56.0,
  });

  @override
  State<ScrollToIndexListView> createState() => _ScrollToIndexListViewState();
}

class _ScrollToIndexListViewState extends State<ScrollToIndexListView> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _scheduleScrollToIndex();
  }

  @override
  void didUpdateWidget(covariant ScrollToIndexListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex ||
        oldWidget.itemExtent != widget.itemExtent) {
      _scheduleScrollToIndex();
    }
  }

  void _scheduleScrollToIndex({int retryCount = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_controller.hasClients && retryCount < 5) {
        _scheduleScrollToIndex(retryCount: retryCount + 1);
        return;
      }
      if (!_controller.hasClients) return;
      final itemHeight = widget.itemExtent;
      final targetOffset = (widget.initialIndex * itemHeight) - 100;
      _controller.animateTo(
        targetOffset.clamp(0.0, _controller.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _controller,
      itemCount: widget.itemCount,
      itemExtent: widget.itemExtent,
      itemBuilder: widget.itemBuilder,
    );
  }
}
