import 'package:flutter/material.dart';
import 'package:finzy/widgets/app_icon.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:rate_limiter/rate_limiter.dart';

import '../focus/dpad_navigator.dart';
import '../i18n/strings.g.dart';
import '../mixins/refreshable.dart';
import '../models/hub.dart';
import '../providers/multi_server_provider.dart';
import '../utils/app_logger.dart';
import '../utils/focus_utils.dart';
import '../utils/platform_detector.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/hub_section.dart';
import 'libraries/state_messages.dart';
import 'main_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with Refreshable, FullRefreshable, SearchInputFocusable {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode(debugLabel: 'SearchInput');
  List<Hub> _searchHubs = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  late final Debounce _searchDebounce;
  String _lastSearchedQuery = '';

  final List<GlobalKey<HubSectionState>> _hubKeys = [];
  int? _lastFocusedHubIndex;

  static const int _previewLimit = 20;

  /// Ordered category definitions: Jellyfin IncludeItemTypes → (title, icon)
  static List<_SearchCategory> _getCategories(BuildContext context) {
    final t = Translations.of(context);
    return [
      _SearchCategory('Movie', t.search.categories.movies, Symbols.movie_rounded),
      _SearchCategory('Series', t.search.categories.shows, Symbols.tv_rounded),
      _SearchCategory('Episode', t.search.categories.episodes, Symbols.ondemand_video_rounded),
      _SearchCategory('Person', t.search.categories.people, Symbols.person_rounded),
      _SearchCategory('BoxSet', t.search.categories.collections, Symbols.video_library_rounded),
      _SearchCategory('LiveTvProgram', t.search.categories.programs, Symbols.live_tv_rounded),
      _SearchCategory('LiveTvChannel', t.search.categories.channels, Symbols.settings_input_antenna_rounded),
    ];
  }

  @override
  void initState() {
    super.initState();
    _searchDebounce = debounce(_performSearch, const Duration(milliseconds: 500));
    _searchController.addListener(_onSearchChanged);
    FocusUtils.requestFocusAfterBuild(this, _searchFocusNode);
  }

  @override
  void dispose() {
    _searchDebounce.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;

    if (query.trim().isEmpty) {
      _searchDebounce.cancel();
      setState(() {
        _searchHubs = [];
        _hasSearched = false;
        _isSearching = false;
        _lastSearchedQuery = '';
        _lastFocusedHubIndex = null;
      });
      return;
    }

    if (query.trim() == _lastSearchedQuery.trim()) {
      return;
    }

    _searchDebounce([query]);
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchHubs = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _lastFocusedHubIndex = null;
    });

    try {
      final multiServerProvider = Provider.of<MultiServerProvider>(context, listen: false);

      if (!multiServerProvider.hasConnectedServers) {
        throw Exception('No servers available');
      }

      final hasLiveTv = multiServerProvider.hasLiveTv;
      final categorizedResults = await multiServerProvider.aggregationService
          .searchCategorizedAcrossServers(
        query,
        limitPerType: _previewLimit,
        includeLiveTv: hasLiveTv,
      );

      if (!mounted) return;

      final categories = _getCategories(context);
      final hubs = <Hub>[];

      for (final category in categories) {
        final items = categorizedResults[category.itemType];
        if (items == null || items.isEmpty) continue;

        hubs.add(Hub(
          hubKey: 'search_${category.itemType}_${Uri.encodeComponent(query.trim())}',
          title: category.title,
          type: category.itemType.toLowerCase(),
          size: items.length,
          more: true,
          items: items,
          serverId: items.first.serverId,
        ));
      }

      setState(() {
        _searchHubs = hubs;
        _isSearching = false;
        _lastSearchedQuery = query.trim();
      });
    } catch (e) {
      appLogger.e('Search failed', error: e);
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        showErrorSnackBar(context, t.errors.searchFailed(error: e));
      }
    }
  }

  @override
  void refresh() {
    if (_searchController.text.isNotEmpty) {
      _performSearch(_searchController.text);
    }
  }

  @override
  void focusSearchInput() {
    FocusUtils.requestFocusAfterBuild(this, _searchFocusNode);
  }

  @override
  void setSearchQuery(String query) {
    _searchController.text = query;
  }

  @override
  void fullRefresh() {
    appLogger.d('SearchScreen.fullRefresh() called - clearing search and reloading');
    _searchController.clear();
    setState(() {
      _searchHubs.clear();
      _isSearching = false;
      _hasSearched = false;
      _lastSearchedQuery = '';
      _lastFocusedHubIndex = null;
    });
  }

  void _navigateToSidebar() {
    MainScreenFocusScope.of(context)?.focusSidebar();
  }

  KeyEventResult _handleSearchInputKeyEvent(FocusNode _, KeyEvent event) {
    if (!event.isActionable) return KeyEventResult.ignored;

    final key = event.logicalKey;

    if (key.isDownKey && _searchHubs.isNotEmpty && !_isSearching) {
      final index = _lastFocusedHubIndex != null && _lastFocusedHubIndex! < _searchHubs.length
          ? _lastFocusedHubIndex!
          : 0;
      _focusHub(index);
      return KeyEventResult.handled;
    }

    if (key.isLeftKey && _searchController.selection.baseOffset == 0) {
      _navigateToSidebar();
      return KeyEventResult.handled;
    }

    if (key.isBackKey) {
      if (_searchController.text.isNotEmpty) {
        _searchController.clear();
      } else {
        _navigateToSidebar();
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _ensureHubKeys(int count) {
    while (_hubKeys.length < count) {
      _hubKeys.add(GlobalKey<HubSectionState>());
    }
  }

  void _focusHub(int index) {
    if (index < 0 || index >= _hubKeys.length) return;
    _hubKeys[index].currentState?.requestFocusFromMemory();
  }

  bool _handleVerticalNavigation(int hubIndex, bool isUp) {
    final targetIndex = isUp ? hubIndex - 1 : hubIndex + 1;
    if (targetIndex < 0) return false;
    if (targetIndex >= _searchHubs.length) return true;
    final targetState = _hubKeys[targetIndex].currentState;
    if (targetState != null) {
      targetState.requestFocusFromMemory();
      return true;
    }
    return true;
  }

  IconData _iconForItemType(String itemType) {
    return switch (itemType) {
      'Movie' => Symbols.movie_rounded,
      'Series' => Symbols.tv_rounded,
      'Episode' => Symbols.ondemand_video_rounded,
      'Person' => Symbols.person_rounded,
      'BoxSet' => Symbols.video_library_rounded,
      'LiveTvProgram' => Symbols.live_tv_rounded,
      'LiveTvChannel' => Symbols.settings_input_antenna_rounded,
      _ => Symbols.search_rounded,
    };
  }

  Widget _buildSearchHeader() {
    final isPhone = PlatformDetector.isPhone(context);
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, bottom: isPhone ? 8 : 16),
      child: Focus(
        onKeyEvent: _handleSearchInputKeyEvent,
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          decoration: InputDecoration(
            hintText: t.search.hint,
            prefixIcon: const AppIcon(Symbols.search_rounded, fill: 1),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const AppIcon(Symbols.clear_rounded, fill: 1),
                    onPressed: () {
                      _searchController.clear();
                    },
                  )
                : null,
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(100)),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(100)),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(100)),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = PlatformDetector.isPhone(context);
    final isTv = PlatformDetector.isTV();

    // On mobile and TV: search box scrolls with results to avoid overlap/z-order issues
    if (isPhone || isTv) {
      return Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                bottom: 8,
              ),
              sliver: SliverToBoxAdapter(
                child: Text(
                  t.common.search,
                  style: Theme.of(context).appBarTheme.titleTextStyle ?? Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            SliverToBoxAdapter(child: _buildSearchHeader()),
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 8),
              sliver: _buildResultsSliver(),
            ),
          ],
        ),
      );
    }

    // TV/Desktop: search box fixed at top
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              bottom: 8,
            ),
            child: Text(
              t.common.search,
              style: Theme.of(context).appBarTheme.titleTextStyle ?? Theme.of(context).textTheme.titleLarge,
            ),
          ),
          _buildSearchHeader(),
          Expanded(child: _buildResultsArea()),
        ],
      ),
    );
  }

  Widget _buildResultsSliver() {
    if (_isSearching) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (!_hasSearched) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: StateMessageWidget(
          message: t.search.searchYourMedia,
          subtitle: t.search.enterTitleActorOrKeyword,
          icon: Symbols.search_rounded,
          iconSize: 80,
        ),
      );
    }
    if (_searchHubs.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: StateMessageWidget(
          message: t.messages.noResultsFound,
          subtitle: t.search.tryDifferentTerm,
          icon: Symbols.search_off_rounded,
          iconSize: 80,
        ),
      );
    }
    _ensureHubKeys(_searchHubs.length);
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
        (context, index) {
          final hub = _searchHubs[index];
          return HubSection(
            key: index < _hubKeys.length ? _hubKeys[index] : null,
            hub: hub,
            icon: _iconForItemType(hub.hubKey.split('_')[1]),
            onRefresh: null,
            onVerticalNavigation: (isUp) => _handleVerticalNavigation(index, isUp),
            onBack: () {
              _lastFocusedHubIndex = index;
              _searchFocusNode.requestFocus();
            },
            onNavigateUp: index == 0
                ? () {
                    _lastFocusedHubIndex = 0;
                    _searchFocusNode.requestFocus();
                  }
                : null,
            onNavigateToSidebar: _navigateToSidebar,
          );
        },
        childCount: _searchHubs.length,
        ),
      ),
    );
  }

  Widget _buildResultsArea() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasSearched) {
      return StateMessageWidget(
        message: t.search.searchYourMedia,
        subtitle: t.search.enterTitleActorOrKeyword,
        icon: Symbols.search_rounded,
        iconSize: 80,
      );
    }

    if (_searchHubs.isEmpty) {
      return StateMessageWidget(
        message: t.messages.noResultsFound,
        subtitle: t.search.tryDifferentTerm,
        icon: Symbols.search_off_rounded,
        iconSize: 80,
      );
    }

    _ensureHubKeys(_searchHubs.length);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      clipBehavior: Clip.none,
      itemCount: _searchHubs.length,
      itemBuilder: (context, index) {
        final hub = _searchHubs[index];
        return HubSection(
          key: index < _hubKeys.length ? _hubKeys[index] : null,
          hub: hub,
          icon: _iconForItemType(hub.hubKey.split('_')[1]),
          onRefresh: null,
          onVerticalNavigation: (isUp) => _handleVerticalNavigation(index, isUp),
          onBack: () {
            _lastFocusedHubIndex = index;
            _searchFocusNode.requestFocus();
          },
          onNavigateUp: index == 0
              ? () {
                  _lastFocusedHubIndex = 0;
                  _searchFocusNode.requestFocus();
                }
              : null,
          onNavigateToSidebar: _navigateToSidebar,
        );
      },
    );
  }
}

class _SearchCategory {
  final String itemType;
  final String title;
  final IconData icon;

  const _SearchCategory(this.itemType, this.title, this.icon);
}
