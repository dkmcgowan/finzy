/// Mixin for screens that need to react to tab visibility changes.
///
/// Used by MainScreen to pause expensive work (e.g. animation tickers)
/// when the screen's tab is no longer visible, and resume it when shown again.
mixin TabVisibilityAware {
  /// Called when the tab becomes visible.
  /// [scrollToTop] - when false (e.g. returning from a child route), skip scrolling to top.
  void onTabShown({bool scrollToTop = true});
  void onTabHidden();
}
