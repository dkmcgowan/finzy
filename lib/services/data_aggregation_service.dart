import 'dart:async';

import '../models/registered_server.dart';
import '../models/hub.dart';
import '../models/media_library.dart';
import '../models/media_metadata.dart';
import '../utils/app_logger.dart';
import 'jellyfin_client.dart';
import 'multi_server_manager.dart';

/// Service for aggregating data from multiple Jellyfin servers
class DataAggregationService {
  final MultiServerManager _serverManager;

  DataAggregationService(this._serverManager);

  /// Clear any cached data (for compatibility with existing callers)
  // ignore: no-empty-block - stub, no cache to clear in current implementation
  void clearCache() {}

  /// Fetch libraries from all online servers
  /// Libraries are automatically tagged with server info by client
  Future<List<MediaLibrary>> getLibrariesFromAllServers() async {
    return _perServer<MediaLibrary>(
      operationName: 'fetching libraries',
      operation: (serverId, client, server) async {
        return await client.getLibraries();
      },
    );
  }

  /// Fetch Continue Watching items from all servers and merge by recency.
  /// Items are automatically tagged with server info by client.
  Future<List<MediaMetadata>> getContinueWatchingFromAllServers({int? limit, Set<String>? hiddenLibraryKeys}) async {
    final allContinueWatching = await _perServer<MediaMetadata>(
      operationName: 'fetching continue watching',
      operation: (serverId, client, server) async {
        return await client.getContinueWatching();
      },
    );

    // Filter out items from hidden libraries
    List<MediaMetadata> filteredItems = allContinueWatching;
    if (hiddenLibraryKeys != null && hiddenLibraryKeys.isNotEmpty) {
      filteredItems = allContinueWatching.where((item) {
        final librarySectionId = item.libraryId;
        if (librarySectionId == null) return true; // Keep if no section ID
        final globalKey = '${item.serverId}:$librarySectionId';
        return !hiddenLibraryKeys.contains(globalKey);
      }).toList();
    }

    // Sort by most recently viewed
    // Use lastPlayedAt (when item was last viewed), falling back to updatedAt/addedAt if not available
    filteredItems.sort((a, b) {
      final aTime = a.lastPlayedAt ?? a.updatedAt ?? a.addedAt ?? 0;
      final bTime = b.lastPlayedAt ?? b.updatedAt ?? b.addedAt ?? 0;
      return bTime.compareTo(aTime); // Descending (most recent first)
    });

    // Apply limit if specified
    final result = limit != null && limit < filteredItems.length ? filteredItems.sublist(0, limit) : filteredItems;

    appLogger.i('Fetched ${result.length} continue watching items from all servers');

    return result;
  }

  /// Fetch recommendation hubs from all servers
  /// When useGlobalHubs is true (default), uses global home hubs: Next Up, Recently Added Movies, Recently Added Shows.
  /// When false, uses per-library hubs on home: Next Up + "Recently Added in [Library Name]" per library.
  Future<List<Hub>> getHubsFromAllServers({
    int? limit,
    Set<String>? hiddenLibraryKeys,
    Map<String, List<MediaLibrary>>? librariesByServer,
    bool useGlobalHubs = true,
  }) async {
    final clients = _serverManager.onlineClients;

    if (clients.isEmpty) {
      appLogger.w('No online servers available for fetching hubs');
      return [];
    }

    appLogger.i('Home hubs: useGlobalHubs=$useGlobalHubs, servers=${clients.length}');
    if (useGlobalHubs) {
      return _fetchGlobalHubs(clients, limit: limit, hiddenLibraryKeys: hiddenLibraryKeys);
    }
    // Per-library hubs + always include Next Up (next episodes for series)
    final libraryHubs = await _fetchLibraryHubs(
      clients,
      limit: limit,
      hiddenLibraryKeys: hiddenLibraryKeys,
      librariesByServer: librariesByServer,
    );
    final globalHubs = await _fetchGlobalHubs(clients, limit: limit, hiddenLibraryKeys: hiddenLibraryKeys);
    final nextUp = globalHubs.where((h) {
      final id = h.hubIdentifier?.toLowerCase() ?? '';
      final title = h.title.toLowerCase();
      return id.contains('nextup') || id.contains('next_up') || title.contains('next up');
    }).toList();
    if (nextUp.isNotEmpty) {
      appLogger.i('Home hubs: prepending ${nextUp.length} Next Up hub(s) to library hubs');
    }
    return [...nextUp, ...libraryHubs];
  }

  /// Fetch global home hubs (Next Up, Recently Added Movies/Shows)
  Future<List<Hub>> _fetchGlobalHubs(
    Map<String, JellyfinClient> clients, {
    int? limit,
    Set<String>? hiddenLibraryKeys,
  }) async {
    appLogger.i('Fetching global hubs from ${clients.length} servers');

    // Fetch global hubs from all servers in parallel
    final hubFutures = clients.entries.map((entry) async {
      final serverId = entry.key;
      final client = entry.value;

      try {
        final hubs = await client.getGlobalHubs(limit: limit ?? 10);
        appLogger.i('Home hubs: getGlobalHubs(server $serverId) -> ${hubs.length} hub(s)${hubs.isNotEmpty ? ": ${hubs.map((h) => h.title).join(", ")}" : ""}');

        // Filter out items from hidden libraries if specified
        if (hiddenLibraryKeys != null && hiddenLibraryKeys.isNotEmpty) {
          return hubs
              .map((hub) {
                final filteredItems = hub.items.where((item) {
                  // Build the global key for the item's library section
                  final librarySectionId = item.libraryId;
                  if (librarySectionId == null) return true; // Keep if no section ID
                  final globalKey = '$serverId:$librarySectionId';
                  return !hiddenLibraryKeys.contains(globalKey);
                }).toList();

                if (filteredItems.isEmpty) return null;

                return Hub(
                  hubKey: hub.hubKey,
                  title: hub.title,
                  type: hub.type,
                  hubIdentifier: hub.hubIdentifier,
                  size: filteredItems.length,
                  more: hub.more,
                  items: filteredItems,
                  serverId: hub.serverId,
                  serverName: hub.serverName,
                );
              })
              .whereType<Hub>()
              .toList();
        }

        return hubs;
      } catch (e, stackTrace) {
        appLogger.e('Failed to fetch hubs from server $serverId', error: e, stackTrace: stackTrace);
        _serverManager.updateServerStatus(serverId, false);
        return <Hub>[];
      }
    });

    final results = await Future.wait(hubFutures);
    final result = _collectAndLimitResults(results, limit);

    appLogger.i('Fetched ${result.length} global hubs from all servers');

    return result;
  }

  /// Fetch per-library hubs (Recently Added per library)
  Future<List<Hub>> _fetchLibraryHubs(
    Map<String, JellyfinClient> clients, {
    int? limit,
    Set<String>? hiddenLibraryKeys,
    Map<String, List<MediaLibrary>>? librariesByServer,
  }) async {
    // Use pre-fetched libraries or fetch and group them
    final libraries = librariesByServer ?? groupLibrariesByServer(await getLibrariesFromAllServers());

    appLogger.d('Fetching per-library hubs from ${clients.length} servers');

    // Fetch from all servers in parallel using cached libraries
    final hubFutures = clients.entries.map((entry) async {
      final serverId = entry.key;
      final client = entry.value;

      try {
        // Use pre-fetched libraries for this server
        final serverLibraries = libraries[serverId] ?? <MediaLibrary>[];
        if (serverLibraries.isEmpty) {
          appLogger.i('Home hubs: server $serverId has no libraries');
          return <Hub>[];
        }

        // Filter to only visible movie/show libraries
        final visibleLibraries = serverLibraries.where((library) {
          if (library.type != 'movie' && library.type != 'show') {
            return false;
          }
          if (library.hidden != null && library.hidden != 0) {
            return false;
          }
          // Check app-level hidden libraries
          if (hiddenLibraryKeys != null && hiddenLibraryKeys.contains(library.globalKey)) {
            return false;
          }
          return true;
        }).toList();

        appLogger.i('Home hubs: server $serverId has ${serverLibraries.length} lib(s), ${visibleLibraries.length} visible (movie/show); keys=${visibleLibraries.map((l) => l.key).join(",")}');

        // Fetch hubs from all libraries in parallel
        final libraryHubFutures = visibleLibraries.map((library) async {
          try {
            final hubs = await client.getLibraryHubs(library.key);
            appLogger.i('Home hubs: getLibraryHubs(${library.title}, key=${library.key}) -> ${hubs.length} hub(s)${hubs.isNotEmpty ? ", ${hubs.first.items.length} items" : ""}');
            // Only rename "Recently Added" hubs so server keeps its varied hub titles (Top in Action, etc.)
            return hubs.map((h) {
              final isRecentlyAdded = (h.hubIdentifier?.toLowerCase().contains('recently_added') ?? false) ||
                  h.title.toLowerCase().contains('recently added');
              final title = isRecentlyAdded ? 'Recently Added in ${library.title}' : h.title;
              return Hub(
                hubKey: h.hubKey,
                title: title,
                type: h.type,
                hubIdentifier: h.hubIdentifier,
                size: h.size,
                more: h.more,
                items: h.items,
                serverId: h.serverId,
                serverName: h.serverName,
              );
            }).toList();
          } catch (e) {
            appLogger.w('Home hubs: getLibraryHubs(${library.title}, key=${library.key}) failed: $e');
            return <Hub>[];
          }
        });

        final libraryHubResults = await Future.wait(libraryHubFutures);

        final serverHubs = <Hub>[];
        for (final hubs in libraryHubResults) {
          serverHubs.addAll(hubs);
        }

        return serverHubs;
      } catch (e, stackTrace) {
        appLogger.e('Failed to fetch hubs from server $serverId', error: e, stackTrace: stackTrace);
        _serverManager.updateServerStatus(serverId, false);
        return <Hub>[];
      }
    });

    final results = await Future.wait(hubFutures);
    final result = _collectAndLimitResults(results, limit);

    appLogger.i('Fetched ${result.length} library hubs from all servers');

    return result;
  }

  /// Search across all online servers
  /// Results are automatically tagged with server info by client
  Future<List<MediaMetadata>> searchAcrossServers(String query, {int? limit}) async {
    if (query.trim().isEmpty) {
      return [];
    }

    final allResults = await _perServer<MediaMetadata>(
      operationName: 'searching for "$query"',
      operation: (serverId, client, server) async {
        return await client.search(query);
      },
    );

    // Apply limit if specified
    final result = limit != null && limit < allResults.length ? allResults.sublist(0, limit) : allResults;

    appLogger.i('Found ${result.length} search results across all servers');

    return result;
  }

  /// Get libraries for a specific server
  Future<List<MediaLibrary>> getLibrariesForServer(String serverId) async {
    final client = _serverManager.getClient(serverId);

    if (client == null) {
      appLogger.w('No client found for server $serverId');
      return [];
    }

    try {
      // Libraries are automatically tagged with server info by client
      return await client.getLibraries();
    } catch (e, stackTrace) {
      appLogger.e('Failed to fetch libraries for server $serverId', error: e, stackTrace: stackTrace);
      _serverManager.updateServerStatus(serverId, false);
      return [];
    }
  }

  /// Group libraries by server
  Map<String, List<MediaLibrary>> groupLibrariesByServer(List<MediaLibrary> libraries) {
    final grouped = <String, List<MediaLibrary>>{};

    for (final library in libraries) {
      final serverId = library.serverId;
      if (serverId != null) {
        grouped.putIfAbsent(serverId, () => []).add(library);
      }
    }

    return grouped;
  }

  // Private helper methods

  /// Collect results from multiple lists and optionally limit the total count.
  List<T> _collectAndLimitResults<T>(List<List<T>> results, int? limit) {
    final all = <T>[];
    for (final items in results) {
      all.addAll(items);
    }
    return limit != null && limit < all.length ? all.sublist(0, limit) : all;
  }

  /// Base helper for per-server fan-out operations
  ///
  /// Returns raw results as (serverId, result) tuples.
  /// Used by [_perServer] and [_perServerGrouped] for different aggregation strategies.
  Future<List<(String serverId, List<T> result)>> _perServerRaw<T>({
    required String operationName,
    required Future<List<T>> Function(String serverId, JellyfinClient client, RegisteredServer? server) operation,
  }) async {
    final clients = _serverManager.onlineClients;

    if (clients.isEmpty) {
      appLogger.w('No online servers available for $operationName');
      return [];
    }

    appLogger.d('$operationName from ${clients.length} servers');

    final futures = clients.entries.map((entry) async {
      final serverId = entry.key;
      final client = entry.value;
      final server = _serverManager.getServer(serverId);
      final sw = Stopwatch()..start();

      try {
        final result = await operation(serverId, client, server);
        appLogger.d(
          '$operationName for server $serverId completed in ${sw.elapsedMilliseconds}ms with ${result.length} items',
        );
        return (serverId, result);
      } catch (e, stackTrace) {
        appLogger.e('Failed $operationName from server $serverId', error: e, stackTrace: stackTrace);
        _serverManager.updateServerStatus(serverId, false);
        appLogger.d('$operationName for server $serverId failed after ${sw.elapsedMilliseconds}ms');
        return (serverId, <T>[]);
      }
    });

    return await Future.wait(futures);
  }

  /// Higher-order helper for per-server fan-out operations
  ///
  /// Iterates over all online clients, executes the operation for each server,
  /// handles errors, updates server status, and flattens results into a single list.
  Future<List<T>> _perServer<T>({
    required String operationName,
    required Future<List<T>> Function(String serverId, JellyfinClient client, RegisteredServer? server) operation,
  }) async {
    final results = await _perServerRaw(operationName: operationName, operation: operation);
    return [for (final (_, items) in results) ...items];
  }
}
