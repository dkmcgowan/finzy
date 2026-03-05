import 'package:flutter/material.dart';
import 'package:finzy/widgets/app_icon.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import '../../focus/dpad_navigator.dart';
import '../../models/library_sort.dart';
import '../../providers/settings_provider.dart';
import '../../utils/scroll_utils.dart';
import '../../widgets/focus_builders.dart';
import '../../widgets/focusable_list_tile.dart';
import '../../widgets/overlay_sheet.dart';
import '../../i18n/strings.g.dart';

/// Focus zones: header (Clear/Close) or list (sort options).
enum _FocusZone { header, list }

class SortBottomSheet extends StatefulWidget {
  final List<LibrarySort> sortOptions;
  final LibrarySort? selectedSort;
  final bool isSortDescending;
  final Function(LibrarySort, bool) onSortChanged;
  final VoidCallback? onClear;
  final FocusNode? clearFocusNode;

  const SortBottomSheet({
    super.key,
    required this.sortOptions,
    required this.selectedSort,
    required this.isSortDescending,
    required this.onSortChanged,
    this.onClear,
    this.clearFocusNode,
  });

  @override
  State<SortBottomSheet> createState() => _SortBottomSheetState();
}

class _SortBottomSheetState extends State<SortBottomSheet> {
  late LibrarySort? _currentSort;
  late bool _currentDescending;
  late final FocusNode _sheetFocusNode;
  bool _ownsSheetFocusNode = false;
  final ScrollController _listScrollController = ScrollController();
  _FocusZone _focusZone = _FocusZone.header;
  int _headerIndex = 0; // 0=Clear, 1=Close when both exist
  int _focusedIndex = 0;
  static const double _itemExtent = 56.0;

  bool get _hasClear => widget.onClear != null;

  void _scrollToIndex(int index) {
    scrollListToIndex(
      _listScrollController,
      index,
      itemExtent: _itemExtent,
      leadingPadding: 8.0,
      animate: true,
      disableAnimations: context.read<SettingsProvider>().disableAnimations,
    );
  }

  KeyEventResult _handleSheetKeyEvent(FocusNode node, KeyEvent event) {
    if (!event.isActionable) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key.isBackKey) {
      OverlaySheetController.of(context).close();
      return KeyEventResult.handled;
    }

    if (key.isSelectKey) {
      if (_focusZone == _FocusZone.header) {
        if (_headerIndex == 0 && _hasClear) {
          _handleClear();
        } else {
          OverlaySheetController.of(context).close();
        }
        return KeyEventResult.handled;
      }
      final sort = _focusedIndex < widget.sortOptions.length ? widget.sortOptions[_focusedIndex] : null;
      if (sort != null) {
        _handleSortSelect(sort);
      }
      return KeyEventResult.handled;
    }

    if (key.isUpKey) {
      if (_focusZone == _FocusZone.list) {
        if (_focusedIndex == 0) {
          setState(() {
            _focusZone = _FocusZone.header;
            _headerIndex = 0;
          });
        } else {
          setState(() {
            _focusedIndex--;
            _scrollToIndex(_focusedIndex);
          });
        }
        return KeyEventResult.handled;
      }
      if (_focusZone == _FocusZone.header && _hasClear && _headerIndex == 1) {
        setState(() => _headerIndex = 0);
      }
      return KeyEventResult.handled;
    }

    if (key.isDownKey) {
      if (_focusZone == _FocusZone.header) {
        setState(() {
          _focusZone = _FocusZone.list;
          _scrollToIndex(_focusedIndex);
        });
        return KeyEventResult.handled;
      }
      if (_focusedIndex < widget.sortOptions.length - 1) {
        setState(() {
          _focusedIndex++;
          _scrollToIndex(_focusedIndex);
        });
      }
      return KeyEventResult.handled;
    }

    if (key.isLeftKey || key.isRightKey) {
      if (_focusZone == _FocusZone.header && _hasClear) {
        setState(() => _headerIndex = key.isRightKey ? 1 : 0);
        return KeyEventResult.handled;
      }
      if (_focusZone == _FocusZone.list) {
        final sort = _focusedIndex < widget.sortOptions.length ? widget.sortOptions[_focusedIndex] : null;
        if (sort != null && _currentSort?.key == sort.key) {
          _handleDirectionChange(sort, key.isRightKey);
          return KeyEventResult.handled;
        }
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  void initState() {
    super.initState();
    _syncFromWidget();
    _sheetFocusNode = widget.clearFocusNode ?? FocusNode(debugLabel: 'SortBottomSheet');
    _ownsSheetFocusNode = widget.clearFocusNode == null;
    final selectedIdx = widget.sortOptions.indexWhere((s) => s.key == widget.selectedSort?.key);
    _focusedIndex = selectedIdx >= 0 ? selectedIdx : 0;
    _focusZone = _FocusZone.header;
    _headerIndex = 0; // Clear when present, else Close
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _sheetFocusNode.requestFocus();
      _scrollToIndex(_focusedIndex);
    });
  }

  @override
  void didUpdateWidget(covariant SortBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSort != widget.selectedSort || oldWidget.isSortDescending != widget.isSortDescending) {
      _syncFromWidget();
    }
  }

  void _syncFromWidget() {
    _currentSort = widget.selectedSort;
    _currentDescending = widget.isSortDescending;
  }

  @override
  void dispose() {
    _listScrollController.dispose();
    if (_ownsSheetFocusNode) _sheetFocusNode.dispose();
    super.dispose();
  }

  void _handleSortSelect(LibrarySort sort) {
    final descending = (_currentSort?.key == sort.key) ? _currentDescending : sort.isDefaultDescending;
    setState(() {
      _currentSort = sort;
      _currentDescending = descending;
    });
    widget.onSortChanged(sort, descending);
  }

  void _handleDirectionChange(LibrarySort sort, bool descending) {
    setState(() => _currentDescending = descending);
    widget.onSortChanged(sort, descending);
  }

  void _handleClear() {
    setState(() {
      _currentSort = null;
      _currentDescending = false;
    });
    widget.onClear?.call();
    OverlaySheetController.of(context).close();
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(t.libraries.sortBy, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
          if (_hasClear)
            _HeaderButton(
              label: t.common.clear,
              isFocused: _focusZone == _FocusZone.header && _headerIndex == 0,
              onPressed: _handleClear,
            ),
          if (_hasClear) const SizedBox(width: 8),
          _HeaderButton(
            isFocused: _focusZone == _FocusZone.header && _headerIndex == (_hasClear ? 1 : 0),
            onPressed: () => OverlaySheetController.of(context).close(),
            isClose: true,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _sheetFocusNode,
      autofocus: true,
      onKeyEvent: _handleSheetKeyEvent,
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: ListView.builder(
              primary: false,
              controller: _listScrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: widget.sortOptions.length,
              itemBuilder: (context, index) {
                final sort = widget.sortOptions[index];
                final isSelected = _currentSort?.key == sort.key;
                final isFocused = _focusZone == _FocusZone.list && index == _focusedIndex;

                return FocusBuilders.buildLockedFocusWrapper(
                  context: context,
                  isFocused: isFocused,
                  scaleOnFocus: false,
                  useListTileStyle: true,
                  onTap: () => _handleSortSelect(sort),
                  child: ExcludeFocusTraversal(
                    child: FocusableRadioListTile<LibrarySort>(
                      focusNode: null,
                      title: Text(sort.title),
                      value: sort,
                      groupValue: _currentSort,
                      onChanged: (value) {
                        if (value != null) _handleSortSelect(value);
                      },
                      secondary: isSelected
                          ? ExcludeFocusTraversal(
                              child: SegmentedButton<bool>(
                                showSelectedIcon: false,
                                segments: const [
                                  ButtonSegment(value: false, icon: AppIcon(Symbols.arrow_upward_rounded, fill: 1, size: 16)),
                                  ButtonSegment(value: true, icon: AppIcon(Symbols.arrow_downward_rounded, fill: 1, size: 16)),
                                ],
                                selected: {_currentDescending},
                                onSelectionChanged: (Set<bool> newSelection) {
                                  _handleDirectionChange(sort, newSelection.first);
                                },
                              ),
                            )
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Header button that shows focus state but does not participate in focus traversal.
class _HeaderButton extends StatelessWidget {
  final String? label;
  final bool isFocused;
  final VoidCallback onPressed;
  final bool isClose;

  const _HeaderButton({
    this.label,
    required this.isFocused,
    required this.onPressed,
    this.isClose = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isClose) {
      return FocusBuilders.buildLockedFocusWrapper(
        context: context,
        isFocused: isFocused,
        useListTileStyle: true,
        circular: true,
        alwaysShowFocus: true,
        onTap: onPressed,
        child: IconButton(
          icon: AppIcon(Symbols.close_rounded, fill: 1),
          onPressed: onPressed,
        ),
      );
    }
    // Pill background always visible so Clear looks identical in library vs hub
    return FocusBuilders.buildLockedFocusWrapper(
      context: context,
      isFocused: isFocused,
      useListTileStyle: true,
      circular: true,
      alwaysShowFocus: true,
      onTap: onPressed,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label ?? '',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xE6FFFFFF),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
