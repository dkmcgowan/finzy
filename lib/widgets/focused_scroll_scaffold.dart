import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../focus/dpad_navigator.dart';
import '../focus/key_event_utils.dart';
import 'desktop_app_bar.dart';

/// A scaffold widget that wraps Focus + Scaffold + CustomScrollView
/// with consistent keyboard navigation handling and app bar styling.
///
/// This widget reduces boilerplate for screens that need:
/// - Keyboard navigation (back key handling)
/// - Custom scrollable content with slivers
/// - Consistent app bar with title and optional actions
class FocusedScrollScaffold extends StatefulWidget {
  /// The title to display in the app bar.
  /// Can be a Text widget or a more complex widget like Column.
  final Widget title;

  /// The list of slivers to display in the scroll view.
  /// Should not include the app bar (it's added automatically).
  final List<Widget> slivers;

  /// Optional actions to display in the app bar (e.g., IconButton widgets).
  final List<Widget>? actions;

  /// Whether the app bar should remain visible when scrolling.
  /// Defaults to true.
  final bool pinned;

  /// Whether to automatically add a back button.
  /// Defaults to true.
  final bool automaticallyImplyLeading;

  const FocusedScrollScaffold({
    super.key,
    required this.title,
    required this.slivers,
    this.actions,
    this.pinned = true,
    this.automaticallyImplyLeading = true,
  });

  @override
  State<FocusedScrollScaffold> createState() => _FocusedScrollScaffoldState();
}

class _FocusedScrollScaffoldState extends State<FocusedScrollScaffold> {
  bool _sawBackKeyDown = false;

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (!event.logicalKey.isBackKey) return KeyEventResult.ignored;

    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return KeyEventResult.ignored;

    if (BackKeyUpSuppressor.consumeIfSuppressed(event)) {
      return KeyEventResult.handled;
    }

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      _sawBackKeyDown = true;
      return KeyEventResult.handled;
    }

    if (event is KeyUpEvent) {
      if (!_sawBackKeyDown) {
        return KeyEventResult.handled;
      }
      _sawBackKeyDown = false;
      BackKeyCoordinator.markHandled();
      BackKeyUpSuppressor.markClosedViaBackKey();
      Navigator.pop(context);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      onKeyEvent: (_, event) => _handleKeyEvent(event),
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            CustomAppBar(
              title: widget.title,
              pinned: widget.pinned,
              actions: widget.actions,
              automaticallyImplyLeading: widget.automaticallyImplyLeading,
            ),
            ...widget.slivers,
          ],
        ),
      ),
    );
  }
}
