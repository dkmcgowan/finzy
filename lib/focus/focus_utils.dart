import 'package:flutter/material.dart';
import 'input_mode_tracker.dart';

/// Utilities for finding and focusing widgets in the focus tree.
class FocusUtils {
  FocusUtils._();

  /// Requests focus on the first focusable widget within [contentContext]'s subtree.
  /// Only runs when [InputModeTracker.isKeyboardMode] is true.
  /// Use when the default traversal would focus the app bar back button first.
  static void focusFirstInSubtree(BuildContext contentContext) {
    if (!InputModeTracker.isKeyboardMode(contentContext)) return;
    final scope = FocusScope.of(contentContext);
    for (final node in scope.traversalDescendants) {
      if (node.context == null || !node.canRequestFocus) continue;
      var isInContent = false;
      node.context!.visitAncestorElements((e) {
        if (e == contentContext) {
          isInContent = true;
          return false;
        }
        return true;
      });
      if (isInContent) {
        node.requestFocus();
        return;
      }
    }
  }
}
