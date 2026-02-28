import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../providers/settings_provider.dart';
import '../../../utils/library_refresh_notifier.dart';
import '../../../../services/jellyfin_client.dart';
import '../../../i18n/strings.g.dart';
import '../../../mixins/item_updatable.dart';
import '../../../models/hub.dart';
import '../../../models/media_metadata.dart';
import '../../../widgets/hub_section.dart';
import '../../main_screen.dart';
import 'base_library_tab.dart';

/// Recommended tab for library screen
/// Shows library-specific hubs and recommendations, including dedicated Continue Watching
class LibraryRecommendedTab extends BaseLibraryTab<Hub> {
  const LibraryRecommendedTab({
    super.key,
    required super.library,
    super.onDataLoaded,
    super.isActive,
    super.suppressAutoFocus,
    super.onBack,
  });

  @override
  State<LibraryRecommendedTab> createState() => _LibraryRecommendedTabState();
}

class _LibraryRecommendedTabState extends BaseLibraryTabState<Hub, LibraryRecommendedTab> with ItemUpdatable {
  /// GlobalKeys for each hub section to enable vertical navigation
  final List<GlobalKey<HubSectionState>> _hubKeys = [];

  @override
  JellyfinClient get client => getClientForLibrary();

  @override
  void updateItemInLists(String itemId, MediaMetadata updatedMetadata) {
    // Update the item in any hub that contains it
    for (final hub in items) {
      final itemIndex = hub.items.indexWhere((item) => item.itemId == itemId);
      if (itemIndex != -1) {
        hub.items[itemIndex] = updatedMetadata;
      }
    }
  }

  @override
  IconData get emptyIcon => Symbols.recommend_rounded;

  @override
  String get emptyMessage => t.libraries.noRecommendations;

  @override
  String get errorContext => t.libraries.tabs.suggestions;

  @override
  Stream<void>? getRefreshStream() => LibraryRefreshNotifier().recommendationsStream;

  @override
  Future<List<Hub>> loadData() async {
    // Clear hub keys before loading new hubs to prevent stale references
    _hubKeys.clear();

    // Use server-specific client for this library
    final client = getClientForLibrary();

    // Load both continue watching items and regular hubs in parallel
    final results = await Future.wait([
      client.getContinueWatchingForLibrary(widget.library.key),
      client.getLibraryHubs(widget.library.key, limit: 12),
    ]);

    final continueWatchingItems = results.first as List<MediaMetadata>;
    final hubs = results[1] as List<Hub>;

    // Filter out any existing Continue Watching hubs since we're adding our own
    final filteredHubs = hubs.where((hub) {
      final title = hub.title.toLowerCase();
      final hubId = hub.hubIdentifier?.toLowerCase() ?? '';
      return !title.contains('continue watching') &&
          !hubId.contains('continue');
    }).toList();

    final finalHubs = <Hub>[];

    // Add Continue Watching as the first hub if there are items
    if (continueWatchingItems.isNotEmpty) {
      final continueWatchingHub = Hub(
        hubKey: 'library_continue_watching_${widget.library.key}',
        title: t.discover.continueWatching,
        type: 'mixed',
        hubIdentifier: '_library_continue_watching_',
        size: continueWatchingItems.length,
        more: false,
        items: continueWatchingItems,
        serverId: widget.library.serverId,
        serverName: widget.library.serverName,
      );
      finalHubs.add(continueWatchingHub);
    }

    // Add the filtered regular hubs with library-specific titles (e.g. "Recently Added in Movies")
    final libraryTitle = widget.library.title;
    for (final hub in filteredHubs) {
      final isRecentlyAdded = (hub.hubIdentifier?.toLowerCase().contains('recently_added') ?? false) ||
          hub.title.toLowerCase().contains('recently added');
      final title = isRecentlyAdded ? 'Recently Added in $libraryTitle' : hub.title;
      finalHubs.add(Hub(
        hubKey: hub.hubKey,
        title: title,
        type: hub.type,
        hubIdentifier: hub.hubIdentifier,
        size: hub.size,
        more: hub.more,
        items: hub.items,
        serverId: hub.serverId,
        serverName: hub.serverName,
      ));
    }

    // Append "Because you watched/liked X" when setting is on (movies only)
    if (!mounted) return finalHubs;
    final settingsProvider = context.read<SettingsProvider>();
    if (widget.library.type.toLowerCase() == 'movie' &&
        settingsProvider.showJellyfinRecommendations) {
      final recHubs = await client.getMovieRecommendations(
        widget.library.key,
        categoryLimit: 10,
        itemLimit: 12,
      );
      for (final hub in recHubs) {
        finalHubs.add(hub);
      }
    }

    return finalHubs;
  }

  /// Ensure we have enough GlobalKeys for all hubs
  void _ensureHubKeys(int count) {
    while (_hubKeys.length < count) {
      _hubKeys.add(GlobalKey<HubSectionState>());
    }
  }

  /// Handle vertical navigation between hubs
  bool _handleVerticalNavigation(int hubIndex, bool isUp) {
    final targetIndex = isUp ? hubIndex - 1 : hubIndex + 1;

    // Check if target is valid
    if (targetIndex < 0) {
      // At top boundary - return false to allow onNavigateUp to handle it
      return false;
    }

    if (targetIndex >= _hubKeys.length) {
      // At bottom boundary, block navigation
      return true;
    }

    // Navigate to target hub with column memory
    final targetState = _hubKeys[targetIndex].currentState;
    if (targetState != null) {
      targetState.requestFocusFromMemory();
      return true;
    }

    return false;
  }

  /// Focus the first item in the first hub (for tab activation)
  @override
  void focusFirstItem() {
    if (_hubKeys.isNotEmpty && items.isNotEmpty) {
      _hubKeys.first.currentState?.requestFocusAt(0);
    }
  }

  /// Navigate focus to the sidebar
  void _navigateToSidebar() {
    MainScreenFocusScope.of(context)?.focusSidebar();
  }

  // Extra top padding for focus decoration (scale + border extends beyond item bounds)
  static const double _focusDecorationPadding = 8.0;

  @override
  Widget buildContent(List<Hub> items) {
    _ensureHubKeys(items.length);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 8 + _focusDecorationPadding, 0, 8),
      // Allow focus decoration to render outside scroll bounds
      clipBehavior: Clip.none,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final hub = items[index];
        final isContinueWatching = hub.hubIdentifier == '_library_continue_watching_';

        return HubSection(
          key: index < _hubKeys.length ? _hubKeys[index] : null,
          hub: hub,
          icon: _getHubIcon(hub),
          isInContinueWatching: isContinueWatching,
          onRefresh: updateItem,
          onVerticalNavigation: (isUp) => _handleVerticalNavigation(index, isUp),
          onBack: widget.onBack,
          onNavigateUp: index == 0 ? widget.onBack : null,
          onNavigateToSidebar: _navigateToSidebar,
        );
      },
    );
  }

  IconData _getHubIcon(Hub hub) {
    final title = hub.title.toLowerCase();
    if (title.contains('continue watching')) {
      return Symbols.play_circle_rounded;
    } else if (title.contains('recently') || title.contains('new')) {
      return Symbols.fiber_new_rounded;
    } else if (title.contains('popular') || title.contains('trending')) {
      return Symbols.trending_up_rounded;
    } else if (title.contains('top') || title.contains('rated')) {
      return Symbols.star_rounded;
    } else if (title.contains('recommended') || title.contains('because you watched') || title.contains('because you liked')) {
      return Symbols.thumb_up_rounded;
    } else if (title.contains('from director')) {
      return Symbols.movie_creation_rounded;
    } else if (title.contains('with actor')) {
      return Symbols.person_rounded;
    } else if (title.contains('unwatched')) {
      return Symbols.visibility_off_rounded;
    } else if (title.contains('genre')) {
      return Symbols.category_rounded;
    }
    return Symbols.movie_rounded;
  }
}
