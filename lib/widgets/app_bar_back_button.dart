import 'package:flutter/material.dart';
import 'package:finzy/utils/desktop_window_padding.dart';
import 'package:finzy/widgets/app_icon.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Defines the visual style of the back button
enum BackButtonStyle {
  /// Back button with circular semi-transparent background (used in detail screens)
  circular,

  /// Plain back button without background (used in sheets and simple contexts)
  plain,

  /// Back button styled for video player overlay
  video,
}

/// A reusable back button widget that provides consistent styling across the app.
///
/// This widget supports different visual styles through [BackButtonStyle] enum:
/// - [BackButtonStyle.circular]: Semi-transparent circular background for detail screens
/// - [BackButtonStyle.plain]: Simple IconButton for sheets and simple contexts
/// - [BackButtonStyle.video]: Styled for video player overlay
///
/// Example usage:
/// ```dart
/// AppBarBackButton(style: BackButtonStyle.circular)
/// ```
class AppBarBackButton extends StatefulWidget {
  /// Creates a back button with the specified style.
  ///
  /// [style] determines the visual appearance of the back button.
  /// [onPressed] is called when the button is tapped. If null, defaults to Navigator.pop.
  /// [color] overrides the default icon color. If null, uses white for circular/video, theme default for plain.
  /// [semanticLabel] provides accessibility label for screen readers.
  /// [isFocused] when true, uses gray background (surfaceContainerHighest) like action buttons.
  /// [isDarkBase] when true (person/cast screen), unfocused uses black circle + white icon.
  const AppBarBackButton({
    super.key,
    this.style = BackButtonStyle.circular,
    this.onPressed,
    this.color,
    this.semanticLabel,
    this.isFocused = false,
    this.isDarkBase = false,
  });

  /// The visual style of the back button
  final BackButtonStyle style;

  /// When true, uses gray background (surfaceContainerHighest) like action buttons.
  final bool isFocused;

  /// When true, unfocused uses black circle + white icon (for person/cast screen).
  final bool isDarkBase;

  /// Callback when the button is pressed. Defaults to Navigator.of(context).pop()
  final VoidCallback? onPressed;

  /// The color of the back arrow icon. If null, uses style-appropriate default.
  final Color? color;

  /// Semantic label for screen readers
  final String? semanticLabel;

  @override
  State<AppBarBackButton> createState() => _AppBarBackButtonState();
}

class _AppBarBackButtonState extends State<AppBarBackButton> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _backgroundAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(duration: const Duration(milliseconds: 150), vsync: this);
    _backgroundAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onHoverChange(bool isHovered) {
    if (isHovered) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  void _handlePressed() {
    if (widget.onPressed != null) {
      widget.onPressed!();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkTheme = theme.brightness == Brightness.dark;
    final isCircular = widget.style == BackButtonStyle.circular;

    if (isCircular) {
      // Circular style: unified base/highlight for both hover and keyboard focus
      final highlightBg = theme.colorScheme.surfaceContainerHighest;
      final highlightIcon = theme.colorScheme.onSurface;

      final Color baseBg;
      final Color baseIcon;
      if (widget.isDarkBase) {
        baseBg = theme.scaffoldBackgroundColor;
        baseIcon = theme.colorScheme.onSurfaceVariant;
      } else {
        baseBg = Colors.black.withValues(alpha: 0.3);
        baseIcon = Colors.white;
      }

      final buttonWidget = MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _onHoverChange(true),
        onExit: (_) => _onHoverChange(false),
        child: GestureDetector(
          onTap: _handlePressed,
          child: AnimatedBuilder(
            animation: _backgroundAnimation,
            builder: (context, child) {
              final t = widget.isFocused ? 1.0 : _backgroundAnimation.value;
              final bg = Color.lerp(baseBg, highlightBg, t)!;
              final ic = Color.lerp(baseIcon, highlightIcon, t)!;
              return Container(
                margin: const EdgeInsets.all(8),
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: AppIcon(Symbols.arrow_back_rounded, fill: 1, color: ic, size: 20),
              );
            },
          ),
        ),
      );

      final button = widget.semanticLabel != null
          ? Semantics(label: widget.semanticLabel, button: true, excludeSemantics: true, child: buttonWidget)
          : buttonWidget;

      return SafeArea(child: button);
    }

    // Non-circular styles (plain, video)
    final Color effectiveColor;
    final Color baseColor;
    final Color hoverColor;
    switch (widget.style) {
      case BackButtonStyle.plain:
        effectiveColor = widget.color ?? (isDarkTheme ? Colors.white : Colors.black);
        baseColor = Colors.transparent;
        hoverColor = (isDarkTheme ? Colors.white : Colors.black).withValues(alpha: 0.2);
        break;
      case BackButtonStyle.video:
        effectiveColor = widget.color ?? Colors.white;
        baseColor = Colors.transparent;
        hoverColor = Colors.black.withValues(alpha: 0.3);
        break;
      default:
        effectiveColor = widget.color ?? Colors.white;
        baseColor = Colors.transparent;
        hoverColor = Colors.transparent;
    }

    final buttonWidget = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _onHoverChange(true),
      onExit: (_) => _onHoverChange(false),
      child: GestureDetector(
        onTap: _handlePressed,
        child: AnimatedBuilder(
          animation: _backgroundAnimation,
          builder: (context, child) {
            final displayBg = Color.lerp(baseColor, hoverColor, _backgroundAnimation.value)!;
            return Container(
              margin: const EdgeInsets.all(8),
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: displayBg, shape: BoxShape.circle),
              child: AppIcon(Symbols.arrow_back_rounded, fill: 1, color: effectiveColor, size: 20),
            );
          },
        ),
      ),
    );

    final button = widget.semanticLabel != null
        ? Semantics(label: widget.semanticLabel, button: true, excludeSemantics: true, child: buttonWidget)
        : buttonWidget;

    return button;
  }
}

/// A focusable back button for detail screens with consistent focus styling.
///
/// [useDarkBase]: When true (person/cast screen), black circle + white icon unfocused,
/// grey when focused. When false (movie/show hero), light circle unfocused, dark when focused.
class FocusableAppBarBackButton extends StatelessWidget {
  const FocusableAppBarBackButton({
    super.key,
    required this.focusNode,
    required this.onKeyEvent,
    required this.onPressed,
    this.useAdjustedLeading = false,
    this.useDarkBase = false,
  });

  final FocusNode focusNode;
  final KeyEventResult Function(FocusNode node, KeyEvent event) onKeyEvent;
  final VoidCallback onPressed;

  /// When true, wraps in [DesktopAppBarHelper.buildAdjustedLeading] for macOS
  /// window controls padding. Use for MediaDetailScreen overlay.
  final bool useAdjustedLeading;

  /// When true (person/cast screen), black circle + white icon. Grey when focused.
  final bool useDarkBase;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      onKeyEvent: onKeyEvent,
      child: ListenableBuilder(
        listenable: focusNode,
        builder: (context, _) {
          final focused = focusNode.hasFocus;

          final button = AppBarBackButton(
            style: BackButtonStyle.circular,
            onPressed: onPressed,
            isFocused: focused,
            isDarkBase: useDarkBase,
          );

          return useAdjustedLeading
              ? DesktopAppBarHelper.buildAdjustedLeading(button, context: context)!
              : button;
        },
      ),
    );
  }
}
