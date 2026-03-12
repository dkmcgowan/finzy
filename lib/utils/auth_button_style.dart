import 'package:flutter/material.dart';

/// Pill-shaped button style for auth screens. Lighter grey background so focus
/// highlight is visible on TV (Amazon tester could not see Connect button).
/// Similar to media card overlay buttons but pill-shaped instead of circle.
ButtonStyle authPillButtonStyle(BuildContext context, {bool primary = true}) {
  final theme = Theme.of(context);
  final bg = theme.colorScheme.surfaceContainer;
  final fg = theme.colorScheme.onSurface;
  final overlay = theme.colorScheme.primary.withValues(alpha: 0.12);

  return ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return bg.withValues(alpha: 0.5);
      }
      return bg;
    }),
    foregroundColor: WidgetStateProperty.all(fg),
    overlayColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.focused) || states.contains(WidgetState.hovered)) {
        return overlay;
      }
      return null;
    }),
    shape: WidgetStateProperty.all(const StadiumBorder()),
    padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 24, vertical: 18)),
    elevation: WidgetStateProperty.all(0),
  );
}
