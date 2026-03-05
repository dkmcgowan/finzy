import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dpad_navigator.dart';

/// Use [handleBackKeyAction] or [handleBackOrLeftKeyAction] as onKeyEvent callbacks
/// for Focus widgets that need back navigation behavior.
class BackKeyCoordinator {
  static bool _handledThisFrame = false;
  static bool _clearScheduled = false;

  static void markHandled() {
    _handledThisFrame = true;
    if (_clearScheduled) return;
    _clearScheduled = true;
    // Clear on next frame to avoid blocking unrelated future back presses.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handledThisFrame = false;
      _clearScheduled = false;
    });
  }

  static bool consumeIfHandled() {
    if (_handledThisFrame) {
      _handledThisFrame = false;
      return true;
    }
    return false;
  }
}

/// Handle a BACK key press by running [onBack] on key up.
///
/// This consumes KeyDown/KeyRepeat to avoid duplicate actions from key repeat.
/// Optionally suppresses stray KeyUp events delivered to the next route after a pop.
KeyEventResult handleBackKeyAction(KeyEvent event, VoidCallback onBack) {
  if (!event.logicalKey.isBackKey) return KeyEventResult.ignored;

  // Check if this BACK event should be suppressed (e.g., after modal closed)
  if (BackKeyUpSuppressor.consumeIfSuppressed(event)) {
    return KeyEventResult.handled;
  }

  if (event is KeyUpEvent) {
    BackKeyCoordinator.markHandled();
    // Mark that we're closing via back key so suppressBackUntilKeyUp() knows to skip
    BackKeyUpSuppressor.markClosedViaBackKey();
    onBack();
    return KeyEventResult.handled;
  }
  if (event is KeyDownEvent || event is KeyRepeatEvent) {
    return KeyEventResult.handled;
  }
  return KeyEventResult.ignored;
}

/// Handle BACK key press by running [onBack] on key up.
/// (Left-as-back was reverted: it broke navigation on controls like play/watched/favorites.)
KeyEventResult handleBackOrLeftKeyAction(KeyEvent event, VoidCallback onBack) {
  if (!event.logicalKey.isBackKey) return KeyEventResult.ignored;

  // Check if this BACK event should be suppressed (e.g., after modal closed)
  if (BackKeyUpSuppressor.consumeIfSuppressed(event)) {
    return KeyEventResult.handled;
  }

  if (event is KeyUpEvent) {
    BackKeyCoordinator.markHandled();
    BackKeyUpSuppressor.markClosedViaBackKey();
    onBack();
    return KeyEventResult.handled;
  }
  if (event is KeyDownEvent || event is KeyRepeatEvent) {
    return KeyEventResult.handled;
  }
  return KeyEventResult.ignored;
}

KeyEventResult handleBackOrLeftKeyNavigation<T>(BuildContext context, KeyEvent event, {T? result}) {
  return handleBackOrLeftKeyAction(event, () => Navigator.pop(context, result));
}

/// Navigator observer that automatically suppresses stray back KeyUp events
/// after any route pop caused by a back key press.
///
/// This catches pops triggered by Flutter's built-in DismissAction (which fires
/// on KeyDown for dialogs) and Android TV system back gestures, preventing the
/// orphaned KeyUp from propagating to the underlying screen's back handler.
class BackKeySuppressorObserver extends NavigatorObserver {
  @override
  void didPop(Route route, Route? previousRoute) {
    if (BackKeyPressTracker.isBackKeyDown) {
      BackKeyUpSuppressor.suppressBackUntilKeyUp();
    }
  }
}
