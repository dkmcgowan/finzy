import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/app_logger.dart';
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

/// Library filter sheet. TV-style **Back** and **Escape** are the same everywhere
/// ([LogicalKeyboardKey.isBackKey]): on a sub-screen they pop one level; on the main
/// category list they close the sheet — so Windows keyboard matches TV remote for testing.
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
  /// Receives the same "back" keys as TV from descendants on the main list (cannot take focus).
  late final FocusNode _mainSurfaceFocusNode;
  /// True when filters use groups (Jellyfin). Main view then shows only category names; no toggles.
  late bool _useGroupedMainView;

  /// For filter/group detail view: single Focus, manual zone tracking.
  late final FocusNode _detailFocusNode;
  /// While popping a sub-route, ignore spurious [SwitchListTile.onChanged] during dispose.
  bool _suppressFilterCallbacks = false;
  /// After returning to the main list, ignore one Escape burst (repeat / duplicate KeyDown) so it does not close the sheet.
  DateTime? _suppressEscapeDismissOnMainUntil;
  bool _detailFocusZoneHeader = true; // true = header (back/close), false = list
  int _detailHeaderIndex = 0; // 0 = back, 1 = close
  /// -1 = in list but no item highlighted yet (Down will highlight first). 0+ = list index.
  int _detailFocusedIndex = -1;
  final ScrollController _detailListScrollController = ScrollController();
  static const double _detailItemExtent = 56.0;

  String _cacheKey(String filter, String value) => '${widget.serverId}:${widget.libraryKey}:$filter:$value';

  static const Set<String> _multiValueFilterKeys = {
    'genre',
    'OfficialRating',
    'tags',
    'VideoTypes',
    'year',
  };

  bool _isMultiValueStringFilter(LibraryFilter f) {
    return f.filterType != 'boolean' && _multiValueFilterKeys.contains(f.filter);
  }

  Set<String> _parseFilterTokens(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    return raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();
  }

  String _serializeFilterTokens(Set<String> tokens) {
    final list = tokens.toList()..sort();
    return list.join(',');
  }

  String? _groupSelectionSummary(({String group, List<LibraryFilter> filters}) entry) {
    if (entry.filters.isEmpty) return null;

    final allBoolean = entry.filters.every((f) => f.filterType == 'boolean');
    if (allBoolean) {
      final activeTitles = entry.filters
          .where((f) => _tempSelectedFilters[f.filter] == '1')
          .map((f) => f.title)
          .toList()
        ..sort();
      if (activeTitles.isEmpty) return null;
      return activeTitles.join(', ');
    }

    if (entry.filters.length != 1) return null;
    final f = entry.filters.single;
    if (_isMultiValueStringFilter(f)) {
      final raw = _tempSelectedFilters[f.filter];
      if (raw == null || raw.isEmpty) return null;
      final tokens = _parseFilterTokens(raw);
      if (tokens.isEmpty) return null;
      final parts = tokens.map((t) => _filterDisplayNames[_cacheKey(f.filter, t)] ?? t).toList()..sort();
      return parts.join(', ');
    }
    if (f.filter == 'SeriesStatus') {
      final v = _tempSelectedFilters[f.filter];
      if (v == null || v.isEmpty) return null;
      return _filterDisplayNames[_cacheKey(f.filter, v)] ?? v;
    }
    return null;
  }

  void _setMultiValueToken(String filterKey, String token, String displayTitle, bool selected) {
    if (_suppressFilterCallbacks) return;
    setState(() {
      final set = _parseFilterTokens(_tempSelectedFilters[filterKey]);
      if (selected) {
        set.add(token);
      } else {
        set.remove(token);
      }
      if (_filterDisplayNames.length > _maxCachedDisplayNames) {
        _filterDisplayNames.clear();
      }
      _filterDisplayNames[_cacheKey(filterKey, token)] = displayTitle;
      if (set.isEmpty) {
        _tempSelectedFilters.remove(filterKey);
      } else {
        _tempSelectedFilters[filterKey] = _serializeFilterTokens(set);
      }
    });
    _notifyFiltersChanged();
  }

  @override
  void initState() {
    super.initState();
    _tempSelectedFilters.addAll(widget.selectedFilters);
    _sortFilters();
    _initialFocusNode = FocusNode(debugLabel: 'FiltersBottomSheetInitialFocus');
    // Must be able to take focus so traversal can land on this scope when returning from detail;
    // ListTile children still own primary focus for d-pad; this node receives bubbled keys.
    _mainSurfaceFocusNode = FocusNode(debugLabel: 'FiltersBottomSheetMainSurface');
    _detailFocusNode = FocusNode(debugLabel: 'FiltersBottomSheetDetail');
  }

  @override
  void dispose() {
    _initialFocusNode.dispose();
    _mainSurfaceFocusNode.dispose();
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

    // isBackKey == TV Back + Escape + browserBack + gameButtonB (dpad_navigator). Same on Windows & TV.
    if (key.isBackKey) {
      // Stale key delivery on the detail Focus node after we've already popped to main.
      if (_currentFilter == null && _currentGroup == null) {
        return KeyEventResult.handled;
      }
      appLogger.d(
        '[FiltersNav] detail back/esc key=$key ev=${event.runtimeType} filter=${_currentFilter?.filter} group=${_currentGroup?.group} → pop',
      );
      if (_currentFilter != null) {
        _goBack();
      } else {
        _goBackFromGroup();
      }
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
        } else if (_detailHeaderIndex == _detailClearIndex && _hasDetailClear) {
          _handleClear();
        } else {
          _dismiss();
        }
        return KeyEventResult.handled;
      }
      if (_currentFilter != null && _detailFocusedIndex >= 0 && _detailFocusedIndex < _filterValues.length) {
        final value = _filterValues[_detailFocusedIndex];
        final filterValue = _extractFilterValue(value.key, _currentFilter!.filter);
        if (_isMultiValueStringFilter(_currentFilter!)) {
          final isOn = _parseFilterTokens(_tempSelectedFilters[_currentFilter!.filter]).contains(filterValue);
          _setMultiValueToken(_currentFilter!.filter, filterValue, value.title, !isOn);
        } else {
          setState(() {
            _tempSelectedFilters[_currentFilter!.filter] = filterValue;
            if (_filterDisplayNames.length > _maxCachedDisplayNames) _filterDisplayNames.clear();
            _filterDisplayNames[_cacheKey(_currentFilter!.filter, filterValue)] = value.title;
          });
          _notifyFiltersChanged();
        }
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
        _notifyFiltersChanged();
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
        setState(() {
          final next = key.isRightKey ? _detailHeaderIndex + 1 : _detailHeaderIndex - 1;
          _detailHeaderIndex = next.clamp(0, _detailCloseIndex);
        });
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
    _suppressEscapeDismissOnMainUntil = null;
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
    if (_currentFilter == null) return;
    OverlaySheetController.maybeOf(context)?.retainSheetFocus();
    _suppressFilterCallbacks = true;
    appLogger.d('[FiltersNav] _goBack() leaving value list was=${_currentFilter?.filter}');
    setState(() {
      _currentFilter = null;
      _filterValues = [];
    });
    _scheduleRefocusMainList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _suppressFilterCallbacks = false;
      });
    });
  }

  void _goBackFromGroup() {
    if (_currentGroup == null) return;
    OverlaySheetController.maybeOf(context)?.retainSheetFocus();
    _suppressFilterCallbacks = true;
    appLogger.d('[FiltersNav] _goBackFromGroup() leaving was=${_currentGroup?.group}');
    setState(() {
      _currentGroup = null;
    });
    _scheduleRefocusMainList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _suppressFilterCallbacks = false;
      });
    });
  }

  /// After returning to the category list, keep focus inside the sheet on the first row.
  void _scheduleRefocusMainList() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_currentFilter == null && _currentGroup == null) {
        // Duplicate Escape (or repeat) right after pop would otherwise dismiss the sheet on Windows.
        _suppressEscapeDismissOnMainUntil = DateTime.now().add(const Duration(milliseconds: 200));
        // Prefer first category row — avoids overlay refocus picking header Close / losing scope to sidebar.
        OverlaySheetController.maybeOf(context)?.refocus(prefer: _initialFocusNode);
      }
    });
  }

  KeyEventResult _handleMainSurfaceKeyEvent(FocusNode node, KeyEvent event) {
    if (!event.isActionable) return KeyEventResult.ignored;
    if (event.logicalKey.isBackKey) {
      // Only eat Escape *repeats* right after leaving detail — avoids double-dismiss while
      // still allowing a deliberate second Escape KeyDown to close the sheet quickly.
      if (event.logicalKey == LogicalKeyboardKey.escape &&
          event is KeyRepeatEvent &&
          _suppressEscapeDismissOnMainUntil != null &&
          DateTime.now().isBefore(_suppressEscapeDismissOnMainUntil!)) {
        appLogger.d('[FiltersNav] main Escape repeat ignored (post-pop debounce)');
        return KeyEventResult.handled;
      }
      appLogger.d('[FiltersNav] main surface back/esc key=${event.logicalKey} ev=${event.runtimeType} → dismiss');
      _dismiss();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _openGroup(({String group, List<LibraryFilter> filters}) entry) {
    _suppressEscapeDismissOnMainUntil = null;
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

  void _notifyFiltersChanged() {
    if (_suppressFilterCallbacks) {
      appLogger.d('FiltersBottomSheet: _notifyFiltersChanged skipped (sub-route pop)');
      return;
    }
    widget.onFiltersChanged(_tempSelectedFilters);
    _refocusAfterChange();
  }

  void _refocusAfterChange() {
    appLogger.d('FiltersBottomSheet: _refocusAfterChange');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctrl = OverlaySheetController.maybeOf(context);
      appLogger.d('FiltersBottomSheet: maybeOf=${ctrl != null}');
      if (_currentFilter == null && _currentGroup == null) {
        ctrl?.refocus(prefer: _initialFocusNode);
      } else {
        ctrl?.refocus();
      }
    });
  }

  /// Close without applying (Back/ESC = cancel).
  void _dismiss() {
    _suppressEscapeDismissOnMainUntil = null;
    appLogger.d(
      '[FiltersNav] _dismiss() closing overlay filter=${_currentFilter?.filter} group=${_currentGroup?.group}',
    );
    OverlaySheetController.of(context).close();
  }

  void _handleClear() {
    setState(() {
      _tempSelectedFilters.clear();
    });
    _notifyFiltersChanged();
    _dismiss();
  }

  /// Pill-styled Clear button matching sort dialog.
  Widget _buildClearPillButton({required bool isFocused}) {
    return FocusBuilders.buildLockedFocusWrapper(
      context: context,
      isFocused: isFocused,
      useListTileStyle: true,
      circular: true,
      alwaysShowFocus: true,
      onTap: _handleClear,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleClear,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              t.common.clear,
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

  bool get _hasDetailClear => _tempSelectedFilters.isNotEmpty;

  /// Header indices: 0=Back, 1=Clear (if _hasDetailClear), 2=Close (or 1=Close when no Clear)
  int get _detailCloseIndex => _hasDetailClear ? 2 : 1;
  int get _detailClearIndex => 1;

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
          if (_hasDetailClear) ...[
            _buildClearPillButton(isFocused: _detailFocusZoneHeader && _detailHeaderIndex == _detailClearIndex),
            const SizedBox(width: 8),
          ],
          FocusBuilders.buildLockedFocusWrapper(
            context: context,
            isFocused: _detailFocusZoneHeader && _detailHeaderIndex == _detailCloseIndex,
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
    // Back == Esc via isBackKey; Focus on main vs detail only (no CallbackShortcuts — avoids double-close).
    return _buildContent(context);
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
                    final isFocused = !_detailFocusZoneHeader && _detailFocusedIndex >= 0 && index == _detailFocusedIndex;
                    final multi = _isMultiValueStringFilter(_currentFilter!);
                    final isOn = multi
                        ? _parseFilterTokens(_tempSelectedFilters[_currentFilter!.filter]).contains(filterValue)
                        : _tempSelectedFilters[_currentFilter!.filter] == filterValue;

                    if (multi) {
                      return FocusBuilders.buildLockedFocusWrapper(
                        context: context,
                        isFocused: isFocused,
                        scaleOnFocus: false,
                        useListTileStyle: true,
                        onTap: () {
                          _setMultiValueToken(_currentFilter!.filter, filterValue, value.title, !isOn);
                        },
                        child: ExcludeFocusTraversal(
                          child: FocusableSwitchListTile(
                            focusNode: null,
                            value: isOn,
                            onChanged: (on) {
                              _setMultiValueToken(_currentFilter!.filter, filterValue, value.title, on);
                            },
                            title: Text(value.title),
                          ),
                        ),
                      );
                    }

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
                        _notifyFiltersChanged();
                      },
                      child: ExcludeFocusTraversal(
                        child: FocusableListTile(
                          focusNode: null,
                          title: Text(value.title),
                          selected: isOn,
                          onTap: () {
                            setState(() {
                              _tempSelectedFilters[_currentFilter!.filter] = filterValue;
                              if (_filterDisplayNames.length > _maxCachedDisplayNames) {
                                _filterDisplayNames.clear();
                              }
                              _filterDisplayNames[_cacheKey(_currentFilter!.filter, filterValue)] = value.title;
                            });
                            _notifyFiltersChanged();
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
                      _notifyFiltersChanged();
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
                          _notifyFiltersChanged();
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
    return Focus(
      focusNode: _mainSurfaceFocusNode,
      onKeyEvent: _handleMainSurfaceKeyEvent,
      child: Column(
        children: [
          BottomSheetHeader(
            title: t.libraries.filters,
            leading: const AppIcon(Symbols.filter_alt_rounded, fill: 1),
            action: _tempSelectedFilters.isNotEmpty ? _buildClearPillButton(isFocused: false) : null,
          ),
          Expanded(
            child: _useGroupedMainView ? _buildCategoryList() : _buildFlatFilterList(),
          ),
        ],
      ),
    );
  }

  /// Main view for Jellyfin: only category rows (Filters, Features, Genres, ...), each with arrow.
  Widget _buildCategoryList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _groupedFilters.length,
      itemBuilder: (context, index) {
        final entry = _groupedFilters[index];
        final summary = _groupSelectionSummary(entry);
        return FocusableListTile(
          focusNode: index == 0 ? _initialFocusNode : null,
          title: Text(entry.group),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (summary != null)
                Flexible(
                  child: Text(
                    summary,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (summary != null) const SizedBox(width: 8),
              const AppIcon(Symbols.chevron_right_rounded, fill: 1),
            ],
          ),
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
              _notifyFiltersChanged();
            },
            title: Text(filter.title),
          );
        }
        final selectedValue = _tempSelectedFilters[filter.filter];
        String? displayValue;
        if (selectedValue != null) {
          if (_isMultiValueStringFilter(filter)) {
            final tokens = _parseFilterTokens(selectedValue);
            if (tokens.isNotEmpty) {
              displayValue = tokens
                  .map((t) => _filterDisplayNames[_cacheKey(filter.filter, t)] ?? t)
                  .join(', ');
            }
          } else {
            displayValue = _filterDisplayNames[_cacheKey(filter.filter, selectedValue)] ?? selectedValue;
          }
        }
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
