import 'package:flutter/foundation.dart';

import '../constants/library_constants.dart';
import '../models/media_library.dart';
import '../services/data_aggregation_service.dart';
import '../services/storage_service.dart';
import '../utils/app_logger.dart';
import '../utils/content_utils.dart';
import '../utils/error_message_utils.dart';

/// Load state for the libraries provider
enum LibrariesLoadState { initial, loading, loaded, error }

/// Provider that serves as the single source of truth for library data.
/// Both SideNavigationRail and LibrariesScreen consume this provider
/// instead of independently fetching library data.
class LibrariesProvider extends ChangeNotifier {
  DataAggregationService? _aggregationService;
  List<MediaLibrary> _libraries = [];
  /// Full display order keys from storage (includes [kJellyfinFavoritesKey] when present).
  List<String> _savedOrderKeys = [];
  LibrariesLoadState _loadState = LibrariesLoadState.initial;
  String? _errorMessage;

  /// Unmodifiable list of all libraries (filtered for supported types, ordered)
  List<MediaLibrary> get libraries => List.unmodifiable(_libraries);

  /// Order of keys for sidebar/sheet display (includes Favorites key). Null if not yet loaded.
  List<String>? get displayOrderKeys =>
      _savedOrderKeys.isEmpty ? null : List.unmodifiable(_savedOrderKeys);

  /// Whether libraries are currently being loaded
  bool get isLoading => _loadState == LibrariesLoadState.loading;

  /// Whether libraries have been loaded at least once
  bool get hasLoaded => _loadState == LibrariesLoadState.loaded;

  /// Current load state
  LibrariesLoadState get loadState => _loadState;

  /// Error message if loading failed
  String? get errorMessage => _errorMessage;

  /// Whether libraries are available
  bool get hasLibraries => _libraries.isNotEmpty;

  /// Initialize the provider with the aggregation service.
  /// This should be called after server connection is established.
  void initialize(DataAggregationService service) {
    _aggregationService = service;
  }

  /// Load libraries from all connected servers.
  /// Filters out music libraries and applies saved ordering.
  Future<void> loadLibraries() async {
    if (_aggregationService == null) {
      appLogger.w('LibrariesProvider: Cannot load libraries - not initialized');
      return;
    }

    _loadState = LibrariesLoadState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // Fetch libraries from all servers
      final allLibraries = await _aggregationService!.getLibrariesFromAllServers();

      // Filter out music libraries (not supported)
      final filteredLibraries = allLibraries.where((lib) => !ContentTypeHelper.isMusicLibrary(lib)).toList();

      // Apply saved library order (or default: Movies/Shows alpha, then Collections/Playlists alpha)
      final storage = await StorageService.getInstance();
      final savedOrder = storage.getLibraryOrder();
      _savedOrderKeys = savedOrder ?? [];
      final orderedLibraries = _applyLibraryOrder(filteredLibraries, savedOrder);

      _libraries = orderedLibraries;
      _loadState = LibrariesLoadState.loaded;
      _errorMessage = null;

      appLogger.i('LibrariesProvider: Loaded ${_libraries.length} libraries');
      notifyListeners();
    } catch (e, stackTrace) {
      logErrorWithStackTrace('LibrariesProvider: Failed to load libraries', e, stackTrace);
      _loadState = LibrariesLoadState.error;
      _errorMessage = safeUserMessage(e);
      notifyListeners();
    }
  }

  /// Refresh libraries by clearing cache and reloading.
  Future<void> refresh() async {
    if (_aggregationService == null) {
      appLogger.w('LibrariesProvider: Cannot refresh - not initialized');
      return;
    }

    // Clear aggregation service cache
    _aggregationService!.clearCache();

    // Reload libraries
    await loadLibraries();
  }

  /// Update the library order and persist it.
  /// [orderedLibraries] may include a synthetic Favorites item (globalKey == [kJellyfinFavoritesKey]);
  /// only real libraries are stored in [_libraries]; full key list (including Favorites) is persisted.
  Future<void> updateLibraryOrder(List<MediaLibrary> orderedLibraries) async {
    final realLibraries = orderedLibraries
        .where((lib) => lib.globalKey != kJellyfinFavoritesKey)
        .toList();
    final allKeys = orderedLibraries.map((lib) => lib.globalKey).toList();

    _libraries = List.from(realLibraries);
    _savedOrderKeys = List.from(allKeys);
    notifyListeners();

    final storage = await StorageService.getInstance();
    await storage.saveLibraryOrder(allKeys);

    appLogger.d('LibrariesProvider: Updated library order');
  }

  /// Clear all library data (for profile switch or logout).
  void clear() {
    _libraries = [];
    _savedOrderKeys = [];
    _loadState = LibrariesLoadState.initial;
    _errorMessage = null;
    notifyListeners();
    appLogger.d('LibrariesProvider: Cleared library data');
  }

  /// Default order: Movies and Shows first (alpha by title), then Collections/Playlists (alpha by title).
  List<MediaLibrary> _applyDefaultOrder(List<MediaLibrary> libraries) {
    final primary = <MediaLibrary>[];
    final secondary = <MediaLibrary>[];
    for (final lib in libraries) {
      final t = lib.type.toLowerCase();
      if (t == 'movie' || t == 'show') {
        primary.add(lib);
      } else {
        secondary.add(lib);
      }
    }
    primary.sort((a, b) => a.title.compareTo(b.title));
    secondary.sort((a, b) => a.title.compareTo(b.title));
    return [...primary, ...secondary];
  }

  /// Apply saved library order to a list of libraries. Skips keys that are not libraries (e.g. [kJellyfinFavoritesKey]).
  List<MediaLibrary> _applyLibraryOrder(List<MediaLibrary> libraries, List<String>? savedOrder) {
    if (savedOrder == null || savedOrder.isEmpty) {
      return _applyDefaultOrder(libraries);
    }

    final libraryMap = {for (var lib in libraries) lib.globalKey: lib};

    final orderedLibraries = <MediaLibrary>[];
    for (final key in savedOrder) {
      if (key == kJellyfinFavoritesKey) continue;
      final lib = libraryMap.remove(key);
      if (lib != null) {
        orderedLibraries.add(lib);
      }
    }

    orderedLibraries.addAll(libraryMap.values);
    return orderedLibraries;
  }
}
