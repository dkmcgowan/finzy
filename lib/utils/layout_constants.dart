import 'package:flutter/material.dart';

import 'platform_detector.dart';

/// Layout and sizing constants used throughout the application
/// Screen width breakpoints for responsive design
class ScreenBreakpoints {
  /// Breakpoint for mobile devices (< 600px)
  static const double mobile = 600;

  /// Breakpoint for wide tablets / small desktops (900px)
  /// Used for intermediate responsive layouts
  static const double wideTablet = 900;

  /// Breakpoint for desktop devices (1200px)
  static const double desktop = 1200;

  /// Breakpoint for large desktop devices (1600px)
  static const double largeDesktop = 1600;

  // Legacy alias for backward compatibility
  static const double tablet = mobile;

  /// Whether width is mobile-sized (< 600px)
  static bool isMobile(double width) => width < mobile;

  /// Whether width is tablet-sized (600px - 1199px)
  static bool isTablet(double width) => width >= mobile && width < desktop;

  /// Whether width is wide tablet (900px - 1199px)
  /// Useful for layouts that need more columns than phone but less than desktop
  static bool isWideTablet(double width) => width >= wideTablet && width < desktop;

  /// Whether width is desktop-sized (1200px - 1599px)
  static bool isDesktop(double width) => width >= desktop && width < largeDesktop;

  /// Whether width is large desktop-sized (>= 1600px)
  static bool isLargeDesktop(double width) => width >= largeDesktop;

  /// Whether width is desktop or larger (>= 1200px)
  static bool isDesktopOrLarger(double width) => width >= desktop;

  /// Whether width is wide tablet or larger (>= 900px)
  static bool isWideTabletOrLarger(double width) => width >= wideTablet;
}

/// Grid layout constants
class GridLayoutConstants {
  /// Maximum cross-axis extent for grid items in comfortable density mode
  static const double comfortableDesktop = 250;
  static const double comfortableTablet = 210;
  static const double comfortableMobile = 180;

  /// Maximum cross-axis extent for grid items in compact density mode
  static const double compactDesktop = 160;
  static const double compactTablet = 140;
  static const double compactMobile = 120;

  /// Maximum cross-axis extent for grid items in normal density mode
  static const double normalDesktop = 220;
  static const double normalTablet = 185;
  static const double normalMobile = 155;

  /// Maximum cross-axis extent for grid items on TV (10ft viewing distance)
  static const double comfortableTV = 200;
  static const double normalTV = 170;
  static const double compactTV = 140;

  /// Default aspect ratio for media card grid cells (poster + text)
  static const double posterAspectRatio = 2 / 3.3;

  /// Aspect ratio for episode thumbnail image (16:9)
  static const double episodeThumbnailAspectRatio = 16 / 9;

  /// Aspect ratio for episode thumbnail grid cells (16:9 image + text area)
  /// This is wider than posterAspectRatio but accounts for ~60px text below
  static const double episodeGridCellAspectRatio = 1.4;

  /// Grid spacing (edge-to-edge cards)
  static const double crossAxisSpacing = 0;
  static const double mainAxisSpacing = 0;

  /// Standard grid padding
  static EdgeInsets get gridPadding => const EdgeInsets.only(left: 8, right: 8, bottom: 8);
}

/// App bar layout constants and helpers.
/// Centralizes toolbar height and padding for consistent mobile/desktop/TV layout.
class AppBarLayout {
  /// Compact toolbar (phone) - single-line header
  static const double contentHeightCompact = 44.0;
  static const double barPaddingCompact = 0.0;

  /// Standard toolbar (desktop header-only, e.g. Favorites, Collections, Playlists)
  static const double contentHeightStandard = 56.0;
  static const double barPaddingStandard = 4.0;

  /// Full toolbar (desktop with tabs)
  static const double contentHeightFull = 72.0;
  static const double barPaddingFull = 8.0;

  /// Returns toolbar content height and vertical padding for the app bar.
  ///
  /// [hasHeaderOnly] - true when the screen has a header but no tab row
  /// (e.g. Favorites, Collections, Playlists). Use false for screens with tabs.
  static ({double contentHeight, double barPadding}) getDimensions(
    BuildContext context, {
    bool hasHeaderOnly = false,
  }) {
    final isPhone = PlatformDetector.isPhone(context);
    final useSideNav = PlatformDetector.shouldUseSideNavigation(context);

    if (isPhone) {
      return (contentHeight: contentHeightCompact, barPadding: barPaddingCompact);
    }
    // Desktop/TV
    if (hasHeaderOnly && useSideNav) {
      return (contentHeight: contentHeightStandard, barPadding: barPaddingStandard);
    }
    return (contentHeight: contentHeightFull, barPadding: barPaddingFull);
  }
}
