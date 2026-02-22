import 'package:flutter/material.dart';
import 'package:plezy/widgets/app_icon.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/plex_filter.dart';
import '../../widgets/app_bar_back_button.dart';
import '../../widgets/bottom_sheet_header.dart';
import '../../widgets/focusable_list_tile.dart';
import '../../widgets/overlay_sheet.dart';
import '../../utils/provider_extensions.dart';
import '../../i18n/strings.g.dart';

class FiltersBottomSheet extends StatefulWidget {
  final List<PlexFilter> filters;
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
  PlexFilter? _currentFilter;
  List<PlexFilterValue> _filterValues = [];
  bool _isLoadingValues = false;
  final Map<String, String> _tempSelectedFilters = {};
  static final Map<String, String> _filterDisplayNames = {}; // Cache for display names
  static const int _maxCachedDisplayNames = 1000;
  /// Groups in order. When all filters have group != null (Jellyfin), main view shows only these category rows.
  late List<({String group, List<PlexFilter> filters})> _groupedFilters;
  /// When set, we're in "group detail" view (e.g. Filters toggles, Features toggles).
  ({String group, List<PlexFilter> filters})? _currentGroup;
  late final FocusNode _initialFocusNode;
  /// True when filters use groups (Jellyfin). Main view then shows only category names; no toggles.
  late bool _useGroupedMainView;

  String _cacheKey(String filter, String value) => '${widget.serverId}:${widget.libraryKey}:$filter:$value';

  @override
  void initState() {
    super.initState();
    _tempSelectedFilters.addAll(widget.selectedFilters);
    _sortFilters();
    _initialFocusNode = FocusNode(debugLabel: 'FiltersBottomSheetInitialFocus');
  }

  @override
  void dispose() {
    _initialFocusNode.dispose();
    super.dispose();
  }

  void _sortFilters() {
    final groups = <String?, List<PlexFilter>>{};
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

  bool _isBooleanFilter(PlexFilter filter) {
    return filter.filterType == 'boolean';
  }

  Future<void> _loadFilterValues(PlexFilter filter) async {
    setState(() {
      _currentFilter = filter;
      _isLoadingValues = true;
    });

    try {
      final client = context.getClientForServer(widget.serverId);

      final values = await client.getFilterValues(filter.key);
      if (!mounted) return;
      setState(() {
        _filterValues = values;
        _isLoadingValues = false;
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

  void _openGroup(({String group, List<PlexFilter> filters}) entry) {
    if (entry.filters.length == 1 && entry.filters.single.filterType != 'boolean') {
      // Single picker filter: go straight to value list
      _loadFilterValues(entry.filters.single);
      return;
    }
    setState(() {
      _currentGroup = entry;
    });
  }

  void _applyFilters() {
    widget.onFiltersChanged(_tempSelectedFilters);
    OverlaySheetController.of(context).close();
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
    if (_currentFilter != null) {
      // Show filter options view
      return Column(
        children: [
          // Header with back button
          BottomSheetHeader(
            title: _currentFilter!.title,
            leading: AppBarBackButton(style: BackButtonStyle.plain, onPressed: _goBack),
          ),

          // Filter options list (no "All" row; clear filter via main view Clear all)
          if (_isLoadingValues)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _filterValues.length,
                itemBuilder: (context, index) {
                  final value = _filterValues[index];
                  final filterValue = _extractFilterValue(value.key, _currentFilter!.filter);
                  final isSelected = _tempSelectedFilters[_currentFilter!.filter] == filterValue;

                  return FocusableListTile(
                    focusNode: index == 0 ? _initialFocusNode : null,
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
                  );
                },
              ),
            ),
        ],
      );
    }

    // Group detail view (toggles for Filters / Features)
    if (_currentGroup != null) {
      final entry = _currentGroup!;
      return Column(
        children: [
          BottomSheetHeader(
            title: entry.group,
            leading: AppBarBackButton(style: BackButtonStyle.plain, onPressed: _goBackFromGroup),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: entry.filters.length,
              itemBuilder: (context, index) {
                final filter = entry.filters[index];
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
              },
            ),
          ),
        ],
      );
    }

    // Main view: either category rows only (Jellyfin) or flat list (Plex)
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

  /// Main view for Plex: flat list of toggles then pickers (no categories).
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
