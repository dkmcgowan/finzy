import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:finzy/widgets/app_icon.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import '../../focus/dpad_navigator.dart';
import '../../models/library_filter.dart';
import '../../providers/settings_provider.dart';
import '../../utils/scroll_utils.dart';
import '../../widgets/app_bar_back_button.dart';
import '../../widgets/bottom_sheet_header.dart';
import '../../widgets/focus_builders.dart';
import '../../widgets/focusable_list_tile.dart';
import '../../widgets/overlay_sheet.dart';
import '../../utils/provider_extensions.dart';
import '../../i18n/strings.g.dart';

class FiltersBottomSheet extends StatefulWidget {
  final List<LibraryFilter> filters;
  final Map<String, String> selectedFilters;
  final Function(Map<String, String>) onFiltersChanged;
  final String serverId;
  final String libraryKey;

  const FiltersBottomSheet({
    super.key,
    required this.filters,
    required this.selectedFilters,
    required this.onFiltersChanged,
    required this.serverId,
    required this.libraryKey,
  });

  @override
  State<FiltersBottomSheet> createState() => _FiltersBottomSheetState();
}

class _FiltersBottomSheetState extends State<FiltersBottomSheet> {
  LibraryFilter? _currentFilter;
  List<LibraryFilterValue> _filterValues = [];
  bool _isLoadingValues = false;
  final Map<String, String> _tempSelectedFilters = {};
  static final Map<String, String> _filterDisplayNames = {}; // Cache for display names
  static const int _maxCachedDisplayNames = 1000;
  /// Groups in order. When all filters have group != null (Jellyfin), main view shows only these category rows.
  late List<({String group, List<LibraryFilter> filters})> _groupedFilters;
  /// When set, we're in "group detail" view (e.g. Filters toggles, Features toggles).
  ({String group, List<LibraryFilter> filters})? _currentGroup;
  late final FocusNode _initialFocusNode;
  /// True when filters use groups (Jellyfin). Main view then shows only category names; no toggles.
  late bool _useGroupedMainView;

  /// For filter/group detail view: single Focus, manual zone tracking.
  late final FocusNode _detailFocusNode;
  bool _detailFocusZoneHeader = true; // true = header (back/close), false = list
  int _detailHeaderIndex = 0; // 0 = back, 1 = close
  /// -1 = in list but no item highlighted yet (Down will highlight first). 0+ = list index.
  int _detailFocusedIndex = -1;
  final ScrollController _detailListScrollController = ScrollController();
  static const double _detailItemExtent = 56.0;

  String _cacheKey(String filter, String value) => '${widget.serverId}:${widget.libraryKey}:$filter:$value';

  @override
  void initState() {
    super.initState();
    _tempSelectedFilters.addAll(widget.selectedFilters);
    _sortFilters();
    _initialFocusNode = FocusNode(debugLabel: 'FiltersBottomSheetInitialFocus');
    _detailFocusNode = FocusNode(debugLabel: 'FiltersBottomSheetDetail');
  }

  @override
  void dispose() {
    _initialFocusNode.dispose();
    _detailFocusNode.dispose();
    _detailListScrollController.dispose();
    super.dispose();
  }

  void _scrollDetailToIndex(int index) {
    scrollListToIndex(
      _detailListScrollController,
      index,
      itemExtent: _detailItemExtent,
      leadingPadding: 8.0,
      animate: true,
      disableAnimations: context.read<SettingsProvider>().disableAnimations,
    );
  }

  KeyEventResult _handleDetailKeyEvent(FocusNode node, KeyEvent event) {
    if (!event.isActionable) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final itemCount = _currentFilter != null ? _filterValues.length : _currentGroup!.filters.length;

    if (key.isBackKey) {
      _dismiss();
      return KeyEventResult.handled;
    }

    if (key.isSelectKey) {
      if (_detailFocusZoneHeader) {
        if (_detailHeaderIndex == 0) {
          if (_currentFilter != null) {
            _goBack();
          } else {
            _goBackFromGroup();
          }
        } else {
          _applyFilters();
        }
        return KeyEventResult.handled;
      }
      if (_currentFilter != null && _detailFocusedIndex >= 0 && _detailFocusedIndex < _filterValues.length) {
        final value = _filterValues[_detailFocusedIndex];
        final filterValue = _extractFilterValue(value.key, _currentFilter!.filter);
        setState(() {
          _tempSelectedFilters[_currentFilter!.filter] = filterValue;
          if (_filterDisplayNames.length > _maxCachedDisplayNames) _filterDisplayNames.clear();
          _filterDisplayNames[_cacheKey(_currentFilter!.filter, filterValue)] = value.title;
        });
        _applyFilters();
      } else if (_currentGroup != null && _detailFocusedIndex >= 0 && _detailFocusedIndex < _currentGroup!.filters.length) {
        final filter = _currentGroup!.filters[_detailFocusedIndex];
        final isActive = _tempSelectedFilters.containsKey(filter.filter) && _tempSelectedFilters[filter.filter] == '1';
        setState(() {
          if (isActive) {
            _tempSelectedFilters.remove(filter.filter);
          } else {
            _tempSelectedFilters[filter.filter] = '1';
          }
        });
        _applyFilters();
      }
      return KeyEventResult.handled;
    }

    if (key.isUpKey) {
      if (!_detailFocusZoneHeader) {
        if (_detailFocusedIndex <= 0) {
          setState(() {
            _detailFocusZoneHeader = true;
            _detailHeaderIndex = 0;
          });
        } else {
          setState(() {
            _detailFocusedIndex--;
            _scrollDetailToIndex(_detailFocusedIndex);
          });
        }
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    if (key.isDownKey) {
      if (_detailFocusZoneHeader) {
        setState(() {
          _detailFocusZoneHeader = false;
          _detailFocusedIndex = 0;
          _scrollDetailToIndex(0);
        });
        return KeyEventResult.handled;
      }
      if (_detailFocusedIndex < 0) {
        setState(() {
          _detailFocusedIndex = 0;
          _scrollDetailToIndex(0);
        });
        return KeyEventResult.handled;
      }
      if (_detailFocusedIndex < itemCount - 1) {
        setState(() {
          _detailFocusedIndex++;
          _scrollDetailToIndex(_detailFocusedIndex);
        });
      }
      return KeyEventResult.handled;
    }

    if (key.isLeftKey || key.isRightKey) {
      if (_detailFocusZoneHeader) {
        setState(() => _detailHeaderIndex = key.isRightKey ? 1 : 0);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _sortFilters() {
    final groups = <String?, List<LibraryFilter>>{};
    for (final f in widget.filters) {
      groups.putIfAbsent(f.group, () => []).add(f);
    }
    final order = <String?>[];
    final seen = <String?>{};
    for (final f in widget.filters) {
      if (seen.add(f.group)) order.add(f.group);
    }
    // Only use grouped main view when every filter has a non-null group (Jellyfin).
    _useGroupedMainView = widget.filters.isNotEmpty && widget.filters.every((f) => f.group != null && f.group!.isNotEmpty);
    _groupedFilters = [
      for (final g in order)
        if (g != null && g.isNotEmpty)
          (group: g, filters: groups[g]!),
    ];
  }

  bool _isBooleanFilter(LibraryFilter filter) {
    return filter.filterType == 'boolean';
  }

  Future<void> _loadFilterValues(LibraryFilter filter) async {
    setState(() {
      _currentFilter = filter;
      _isLoadingValues = true;
      _detailFocusZoneHeader = false;
      _detailHeaderIndex = 0;
      _detailFocusedIndex = -1;
    });

    try {
      final client = context.getClientForServer(widget.serverId);

      final values = await client.getFilterValues(filter.key);
      if (!mounted) return;
      setState(() {
        _filterValues = values;
        _isLoadingValues = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _detailFocusNode.requestFocus();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _filterValues = [];
        _isLoadingValues = false;
      });
    }
  }

  void _goBack() {
    setState(() {
      _currentFilter = null;
      _filterValues = [];
    });
  }

  void _goBackFromGroup() {
    setState(() {
      _currentGroup = null;
    });
  }

  void _openGroup(({String group, List<LibraryFilter> filters}) entry) {
    if (entry.filters.length == 1 && entry.filters.single.filterType != 'boolean') {
      // Single picker filter: go straight to value list
      _loadFilterValues(entry.filters.single);
      return;
    }
    setState(() {
      _currentGroup = entry;
      _detailFocusZoneHeader = false;
      _detailHeaderIndex = 0;
      _detailFocusedIndex = -1;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _detailFocusNode.requestFocus();
    });
  }

  void _applyFilters() {
    widget.onFiltersChanged(_tempSelectedFilters);
    OverlaySheetController.of(context).close();
  }

  /// Close without applying (Back/ESC = cancel).
  void _dismiss() {
    OverlaySheetController.of(context).close();
  }

  Widget _buildDetailHeader(String title, {required VoidCallback onBack}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          FocusBuilders.buildLockedFocusWrapper(
            context: context,
            isFocused: _detailFocusZoneHeader && _detailHeaderIndex == 0,
            useListTileStyle: true,
            circular: true,
            onTap: onBack,
            child: AppBarBackButton(style: BackButtonStyle.plain, onPressed: onBack),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
          FocusBuilders.buildLockedFocusWrapper(
            context: context,
            isFocused: _detailFocusZoneHeader && _detailHeaderIndex == 1,
            useListTileStyle: true,
            circular: true,
            onTap: _dismiss,
            child: IconButton(
              icon: AppIcon(Symbols.close_rounded, fill: 1),
              onPressed: _dismiss,
            ),
          ),
        ],
      ),
    );
  }

  String _extractFilterValue(String key, String filterName) {
    if (key.contains('?')) {
      final queryStart = key.indexOf('?');
      final queryString = key.substring(queryStart + 1);
      final params = Uri.splitQueryString(queryString);
      return params[filterName] ?? key;
    } else if (key.startsWith('/')) {
      return key.split('/').last;
    }
    return key;
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _dismiss,
        const SingleActivator(LogicalKeyboardKey.goBack): _dismiss,
      },
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_currentFilter != null) {
      // Show filter options view - single Focus, Up from first row goes to back
      return Focus(
        focusNode: _detailFocusNode,
        autofocus: true,
        onKeyEvent: _handleDetailKeyEvent,
        child: Column(
          children: [
            _buildDetailHeader(_currentFilter!.title, onBack: _goBack),
            if (_isLoadingValues)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: ListView.builder(
                  controller: _detailListScrollController,
                  primary: false,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _filterValues.length,
                  itemBuilder: (context, index) {
                    final value = _filterValues[index];
                    final filterValue = _extractFilterValue(value.key, _currentFilter!.filter);
                    final isSelected = _tempSelectedFilters[_currentFilter!.filter] == filterValue;
                    final isFocused = !_detailFocusZoneHeader && _detailFocusedIndex >= 0 && index == _detailFocusedIndex;

                    return FocusBuilders.buildLockedFocusWrapper(
                      context: context,
                      isFocused: isFocused,
                      scaleOnFocus: false,
                      useListTileStyle: true,
                      onTap: () {
                        setState(() {
                          _tempSelectedFilters[_currentFilter!.filter] = filterValue;
                          if (_filterDisplayNames.length > _maxCachedDisplayNames) {
                            _filterDisplayNames.clear();
                          }
                          _filterDisplayNames[_cacheKey(_currentFilter!.filter, filterValue)] = value.title;
                        });
                        _applyFilters();
                      },
                      child: ExcludeFocusTraversal(
                        child: FocusableListTile(
                          focusNode: null,
                          title: Text(value.title),
                          selected: isSelected,
                          onTap: () {
                            setState(() {
                              _tempSelectedFilters[_currentFilter!.filter] = filterValue;
                              if (_filterDisplayNames.length > _maxCachedDisplayNames) {
                                _filterDisplayNames.clear();
                              }
                              _filterDisplayNames[_cacheKey(_currentFilter!.filter, filterValue)] = value.title;
                            });
                            _applyFilters();
                          },
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

    // Group detail view (toggles for Filters / Features) - single Focus, Up from first row goes to back
    if (_currentGroup != null) {
      final entry = _currentGroup!;
      return Focus(
        focusNode: _detailFocusNode,
        autofocus: true,
        onKeyEvent: _handleDetailKeyEvent,
        child: Column(
          children: [
            _buildDetailHeader(entry.group, onBack: _goBackFromGroup),
            Expanded(
              child: ListView.builder(
                controller: _detailListScrollController,
                primary: false,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: entry.filters.length,
                itemBuilder: (context, index) {
                  final filter = entry.filters[index];
                  final isActive =
                      _tempSelectedFilters.containsKey(filter.filter) && _tempSelectedFilters[filter.filter] == '1';
                  final isFocused = !_detailFocusZoneHeader && _detailFocusedIndex >= 0 && index == _detailFocusedIndex;

                  return FocusBuilders.buildLockedFocusWrapper(
                    context: context,
                    isFocused: isFocused,
                    scaleOnFocus: false,
                    useListTileStyle: true,
                    onTap: () {
                      setState(() {
                        if (isActive) {
                          _tempSelectedFilters.remove(filter.filter);
                        } else {
                          _tempSelectedFilters[filter.filter] = '1';
                        }
                      });
                      _applyFilters();
                    },
                    child: ExcludeFocusTraversal(
                      child: FocusableSwitchListTile(
                        focusNode: null,
                        value: isActive,
                        onChanged: (value) {
                          setState(() {
                            if (value) {
                              _tempSelectedFilters[filter.filter] = '1';
                            } else {
                              _tempSelectedFilters.remove(filter.filter);
                            }
                          });
                          _applyFilters();
                        },
                        title: Text(filter.title),
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

    // Main view: either category rows only (Jellyfin) or flat list (legacy)
    return Column(
      children: [
        BottomSheetHeader(
          title: t.libraries.filters,
          leading: const AppIcon(Symbols.filter_alt_rounded, fill: 1),
          action: _tempSelectedFilters.isNotEmpty
              ? TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _tempSelectedFilters.clear();
                    });
                    _applyFilters();
                  },
                  icon: const AppIcon(Symbols.clear_all_rounded, fill: 1),
                  label: Text(t.libraries.clearAll),
                )
              : null,
        ),
        Expanded(
          child: _useGroupedMainView ? _buildCategoryList() : _buildFlatFilterList(),
        ),
      ],
    );
  }

  /// Main view for Jellyfin: only category rows (Filters, Features, Genres, ...), each with arrow.
  Widget _buildCategoryList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _groupedFilters.length,
      itemBuilder: (context, index) {
        final entry = _groupedFilters[index];
        return FocusableListTile(
          focusNode: index == 0 ? _initialFocusNode : null,
          title: Text(entry.group),
          trailing: const AppIcon(Symbols.chevron_right_rounded, fill: 1),
          onTap: () => _openGroup(entry),
        );
      },
    );
  }

  /// Main view: flat list of toggles then pickers (no categories).
  Widget _buildFlatFilterList() {
    final booleanFilters = widget.filters.where((f) => f.filterType == 'boolean').toList();
    final regularFilters = widget.filters.where((f) => f.filterType != 'boolean').toList();
    final flat = [...booleanFilters, ...regularFilters];
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: flat.length,
      itemBuilder: (context, index) {
        final filter = flat[index];
        if (_isBooleanFilter(filter)) {
          final isActive =
              _tempSelectedFilters.containsKey(filter.filter) && _tempSelectedFilters[filter.filter] == '1';
          return FocusableSwitchListTile(
            focusNode: index == 0 ? _initialFocusNode : null,
            value: isActive,
            onChanged: (value) {
              setState(() {
                if (value) {
                  _tempSelectedFilters[filter.filter] = '1';
                } else {
                  _tempSelectedFilters.remove(filter.filter);
                }
              });
              _applyFilters();
            },
            title: Text(filter.title),
          );
        }
        final selectedValue = _tempSelectedFilters[filter.filter];
        final displayValue = selectedValue != null
            ? (_filterDisplayNames[_cacheKey(filter.filter, selectedValue)] ?? selectedValue)
            : null;
        return FocusableListTile(
          focusNode: index == 0 ? _initialFocusNode : null,
          title: Text(filter.title),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (displayValue != null)
                Flexible(
                  child: Text(
                    displayValue,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (displayValue != null) const SizedBox(width: 8),
              const AppIcon(Symbols.chevron_right_rounded, fill: 1),
            ],
          ),
          onTap: () => _loadFilterValues(filter),
        );
      },
    );
  }
}
