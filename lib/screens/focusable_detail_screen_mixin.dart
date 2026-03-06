import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import '../focus/dpad_navigator.dart';
import '../focus/input_mode_tracker.dart';
import '../focus/key_event_utils.dart';
import '../mixins/grid_focus_node_mixin.dart';
import '../providers/settings_provider.dart';
import '../utils/grid_size_calculator.dart';
import '../widgets/app_icon.dart';
import '../widgets/focusable_media_card.dart';
import '../widgets/media_grid_delegate.dart';

/// Configuration for app bar buttons
class AppBarButtonConfig {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  const AppBarButtonConfig({required this.icon, required this.tooltip, required this.onPressed, this.color});
}

/// Mixin that provides common focus navigation functionality for detail screens.
/// Handles app bar focus, back navigation, scroll-to-top, and grid item focus management.
///
/// Classes using this mixin must also use [GridFocusNodeMixin].
mixin FocusableDetailScreenMixin<T extends StatefulWidget> on State<T>, GridFocusNodeMixin<T> {
  // Scroll controller for scrolling to top when app bar is focused
  final ScrollController scrollController = ScrollController();

  // App bar focus nodes
  final FocusNode backButtonFocusNode = FocusNode(debugLabel: 'detail_back');
  final FocusNode playButtonFocusNode = FocusNode(debugLabel: 'detail_play');
  final FocusNode shuffleButtonFocusNode = FocusNode(debugLabel: 'detail_shuffle');
  final FocusNode deleteButtonFocusNode = FocusNode(debugLabel: 'detail_delete');

  // Grid item focus
  final FocusNode firstItemFocusNode = FocusNode(debugLabel: 'detail_first_item');

  // App bar focus state
  bool isAppBarFocused = false;
  // -1=back, 0=play, 1=shuffle, 2=delete (when appBarButtonCount>0); 0=back only when appBarButtonCount==0)
  int appBarFocusedButton = 0;

  

  /// Number of app bar buttons (override if different from 3)
  int get appBarButtonCount => 3;

  /// Called when items are available and we want to check if focus should be set
  bool get hasItems;

  /// Called to get the list of app bar button configurations
  List<AppBarButtonConfig> getAppBarButtons();

  /// Dispose focus-related resources. Call this from your dispose() method.
  void disposeFocusResources() {
    scrollController.dispose();
    backButtonFocusNode.dispose();
    playButtonFocusNode.dispose();
    shuffleButtonFocusNode.dispose();
    deleteButtonFocusNode.dispose();
    firstItemFocusNode.dispose();
    disposeGridFocusNodes();
  }

  /// Navigate from content to app bar
  void navigateToAppBar() {
    setState(() {
      isAppBarFocused = true;
      // Start with back button when we have action buttons; otherwise back is the only button (index 0)
      appBarFocusedButton = appBarButtonCount > 0 ? -1 : 0;
    });
    _focusAppBarButton(appBarButtonCount > 0 ? -1 : 0);
    if (context.read<SettingsProvider>().disableAnimations) {
      scrollController.jumpTo(0);
    } else {
      scrollController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  /// Handle BACK key from content - pop the screen directly
  void handleBackFromContent() {
    Navigator.pop(context);
  }

  /// Navigate focus from app bar down to the grid
  void navigateToGrid() {
    if (!hasItems) return;

    final targetIndex = shouldRestoreGridFocus ? lastFocusedGridIndex! : 0;

    setState(() {
      isAppBarFocused = false;
    });

    if (targetIndex == 0) {
      firstItemFocusNode.requestFocus();
    } else {
      getGridItemFocusNode(targetIndex, prefix: 'detail_grid_item').requestFocus();
    }
  }

  /// Handle back navigation for PopScope. Returns true if should pop.
  bool handleBackNavigation() {
    return true;
  }

  /// Focus a specific app bar button by index (-1=back, 0=play, 1=shuffle, 2=delete)
  void _focusAppBarButton(int index) {
    switch (index) {
      case -1:
        backButtonFocusNode.requestFocus();
        break;
      case 0:
        playButtonFocusNode.requestFocus();
        break;
      case 1:
        shuffleButtonFocusNode.requestFocus();
        break;
      case 2:
        deleteButtonFocusNode.requestFocus();
        break;
    }
  }

  /// Handle key events when app bar is focused
  KeyEventResult handleAppBarKeyEvent(FocusNode _, KeyEvent event) {
    final key = event.logicalKey;
    final maxButton = appBarButtonCount - 1;

    // When only back button (no action buttons), Select = pop
    if (appBarButtonCount == 0 && event is KeyDownEvent && key.isSelectKey) {
      Navigator.pop(context);
      return KeyEventResult.handled;
    }

    // Back key or Left from back button: pop
    final backResult = handleBackOrLeftKeyAction(event, () => Navigator.pop(context));
    if (backResult != KeyEventResult.ignored) {
      return backResult;
    }

    // Left from other buttons = move to previous (play->back, shuffle->play, delete->shuffle)
    if (key.isLeftKey) {
      if (appBarFocusedButton > -1) {
        if (event is KeyDownEvent) {
          setState(() => appBarFocusedButton--);
          _focusAppBarButton(appBarFocusedButton);
        }
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled; // Consume Left on back button
    }

    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    // Right from back/play/shuffle = move to next
    if (key.isRightKey && appBarFocusedButton < maxButton) {
      setState(() => appBarFocusedButton++);
      _focusAppBarButton(appBarFocusedButton);
      return KeyEventResult.handled;
    }
    if (key.isDownKey) {
      // Return focus to grid
      navigateToGrid();
      return KeyEventResult.handled;
    }
    if (key.isSelectKey) {
      if (appBarFocusedButton == -1) {
        Navigator.pop(context);
        return KeyEventResult.handled;
      }
      final buttons = getAppBarButtons();
      if (appBarFocusedButton >= 0 && appBarFocusedButton < buttons.length) {
        buttons[appBarFocusedButton].onPressed();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Builds a focusable back button for the app bar leading.
  /// When [appBarButtonCount] is 0, uses playButtonFocusNode (back is the only button).
  /// When [appBarButtonCount] > 0, uses backButtonFocusNode (back is first, then play/shuffle/delete).
  Widget? buildFocusableLeading(BuildContext context) {
    final parentRoute = ModalRoute.of(context);
    final canPop = parentRoute?.canPop ?? false;
    if (!canPop) return null;
    final colorScheme = Theme.of(context).colorScheme;
    final isKeyboardMode = InputModeTracker.isKeyboardMode(context);
    final backIndex = appBarButtonCount > 0 ? -1 : 0;
    final isFocused = isKeyboardMode && isAppBarFocused && appBarFocusedButton == backIndex;
    final focusNode = appBarButtonCount > 0 ? backButtonFocusNode : playButtonFocusNode;

    return Focus(
      focusNode: focusNode,
      onKeyEvent: handleAppBarKeyEvent,
      child: Container(
        decoration: isFocused
            ? BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              )
            : null,
        child: Semantics(
          label: MaterialLocalizations.of(context).backButtonTooltip,
          button: true,
          excludeSemantics: true,
          child: IconButton(
            icon: const AppIcon(Symbols.arrow_back_rounded, fill: 1),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: null,
          ),
        ),
      ),
    );
  }

  /// Build focusable app bar action widgets
  List<Widget> buildFocusableAppBarActions() {
    final colorScheme = Theme.of(context).colorScheme;
    final isKeyboardMode = InputModeTracker.isKeyboardMode(context);
    final buttons = getAppBarButtons();

    return buttons.asMap().entries.map((entry) {
      final index = entry.key;
      final config = entry.value;
      final isFocused = isKeyboardMode && isAppBarFocused && appBarFocusedButton == index;

      FocusNode focusNode;
      switch (index) {
        case 0:
          focusNode = playButtonFocusNode;
          break;
        case 1:
          focusNode = shuffleButtonFocusNode;
          break;
        case 2:
          focusNode = deleteButtonFocusNode;
          break;
        default:
          focusNode = FocusNode();
      }

      return Focus(
        focusNode: focusNode,
        onKeyEvent: handleAppBarKeyEvent,
        child: Container(
          decoration: isFocused
              ? BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.all(Radius.circular(20)),
                )
              : null,
          child: IconButton(
            icon: AppIcon(config.icon, fill: 1),
            tooltip: config.tooltip,
            onPressed: config.onPressed,
            color: config.color,
          ),
        ),
      );
    }).toList();
  }

  /// Auto-focus first item after load if in keyboard mode.
  /// Call this from loadItems() after items are loaded.
  void autoFocusFirstItemAfterLoad() {
    if (mounted && hasItems) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (InputModeTracker.isKeyboardMode(context)) {
          setState(() {
            isAppBarFocused = false;
          });
          firstItemFocusNode.requestFocus();
        }
      });
    }
  }

  void _focusDetailGridItem(int index) {
    if (index == 0) {
      firstItemFocusNode.requestFocus();
    } else {
      getGridItemFocusNode(index, prefix: 'detail_grid_item').requestFocus();
    }
  }

  /// Build a standard focusable grid sliver for media items.
  /// Used by collection and smart playlist detail screens.
  Widget buildFocusableGrid({
    required List<dynamic> items,
    required void Function(String itemId) onRefresh,
    String? collectionId,
    VoidCallback? onListRefresh,
  }) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        final maxExtent = GridSizeCalculator.getMaxCrossAxisExtent(context, settingsProvider.libraryDensity);
        return SliverPadding(
          padding: const EdgeInsets.all(8),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final columnCount = GridSizeCalculator.getColumnCount(constraints.crossAxisExtent, maxExtent);
              return SliverGrid.builder(
                gridDelegate: MediaGridDelegate.createDelegate(
                  context: context,
                  density: settingsProvider.libraryDensity,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final inFirstRow = GridSizeCalculator.isFirstRow(index, columnCount);
                  final focusNode = index == 0
                      ? firstItemFocusNode
                      : getGridItemFocusNode(index, prefix: 'detail_grid_item');

                  final aboveIndex = index - columnCount;
                  final belowIndex = index + columnCount;
                  final isLastRow = belowIndex >= items.length;
                  final isFirstColumn = index % columnCount == 0;
                  final isLastColumn = index % columnCount == columnCount - 1;

                  return FocusableMediaCard(
                    key: Key(item.itemId),
                    item: item,
                    focusNode: focusNode,
                    onRefresh: onRefresh,
                    collectionId: collectionId,
                    onListRefresh: onListRefresh,
                    onNavigateUp: inFirstRow ? navigateToAppBar : () => _focusDetailGridItem(aboveIndex),
                    onNavigateDown: isLastRow ? null : () => _focusDetailGridItem(belowIndex),
                    onNavigateLeft: isFirstColumn ? null : () => _focusDetailGridItem(index - 1),
                    onNavigateRight: isLastColumn ? null : () => _focusDetailGridItem(index + 1),
                    onBack: handleBackFromContent,
                    onFocusChange: (hasFocus) => trackGridItemFocus(index, hasFocus),
                    scrollTopOffset: inFirstRow ? kToolbarHeight + 16 : null,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
