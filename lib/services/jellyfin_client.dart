import 'package:dio/dio.dart';

import 'auth_failure_service.dart';
import '../models/jellyfin_config.dart';
import '../models/livetv_channel.dart';
import '../models/livetv_dvr.dart';
import '../models/livetv_hub_result.dart';
import '../models/livetv_program.dart';
import '../models/livetv_recording.dart';
import '../models/livetv_scheduled_recording.dart';
import '../models/livetv_subscription.dart';
import '../models/file_info.dart';
import '../models/library_filter.dart';
import '../models/first_character.dart';
import '../models/hub.dart';
import '../models/media_library.dart';
import '../models/media_info.dart';
import '../models/media_version.dart';
import '../models/media_metadata.dart';
import '../models/playlist.dart';
import '../models/cast_role.dart';
import '../models/library_sort.dart';
import '../models/video_playback_data.dart';
import '../utils/app_logger.dart';
import '../utils/watch_state_notifier.dart';

/// Jellyfin API client. Maps Jellyfin REST API to DTOs used by the UI.
class JellyfinClient {
  /// Minimal Fields for list/grid views (thumbnails, title, watch state, duration).
  /// ItemCounts ensures Series/Season get UnplayedItemCount and episode counts for unwatched badge.
  /// EndDate,Status for series year range (e.g. 2025 - 2026 or 2025 - Present).
  static const String _listFields = 'Genres,UserData,RunTimeTicks,ItemCounts,EndDate,Status';
  /// Like _listFields plus ImageTags; use for BoxSet/collection lists so we only request thumb when server has an image (avoids 404s).
  static const String _collectionListFields = 'Genres,UserData,RunTimeTicks,ItemCounts,EndDate,Status,ImageTags';

  final JellyfinConfig config;
  late final Dio _dio;
  bool _offlineMode = false;

  final String serverId;
  final String? serverName;

  /// Cached user policy permissions (fetched once via [loadUserPolicy]).
  bool _canDeleteContent = false;
  bool _isAdministrator = false;
  bool get canDeleteContent => _canDeleteContent || _isAdministrator;
  bool get isAdministrator => _isAdministrator;

  JellyfinClient(this.config, {required this.serverId, this.serverName}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: config.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Authorization': config.authorizationHeader},
        contentType: 'application/json',
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onResponse: (response, handler) {
          if (response.statusCode == 401) {
            AuthFailureService.instance.notifyAuthFailure(serverId);
          }
          handler.next(response);
        },
        onError: (error, handler) {
          final statusCode = error.response?.statusCode;
          if (statusCode == 401) {
            AuthFailureService.instance.notifyAuthFailure(serverId);
          }
          handler.next(error);
        },
      ),
    );
  }

  String get baseUrl => config.baseUrl;

  String? get token => config.token;

  Map<String, String> get requestHeaders => {'Authorization': config.authorizationHeader};

  bool get isOfflineMode => _offlineMode;

  void setOfflineMode(bool offline) {
    _offlineMode = offline;
  }

  /// Fetch and cache the current user's policy permissions.
  /// Call once after login / server connection.
  Future<void> loadUserPolicy() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/Users/${config.userId}');
      final policy = response.data?['Policy'] as Map<String, dynamic>?;
      if (policy != null) {
        _isAdministrator = policy['IsAdministrator'] as bool? ?? false;
        _canDeleteContent = policy['EnableContentDeletion'] as bool? ?? false;
      }
    } catch (e) {
      appLogger.w('Failed to load user policy', error: e);
    }
  }

  /// Jellyfin uses PascalCase; normalize type to lowercase and Series -> show, BoxSet/Boxsets -> collection.
  static String _normalizeType(String? type) {
    if (type == null || type.isEmpty) return 'folder';
    final t = type.toLowerCase();
    if (t == 'series') return 'show';
    if (t == 'boxset' || t == 'boxsets') return 'collection';
    return t;
  }

  /// Convert Jellyfin RunTimeTicks (100ns) to milliseconds.
  static int? _ticksToMs(int? ticks) {
    if (ticks == null) return null;
    return (ticks / 10000).round();
  }

  /// Convert Jellyfin UserData.PlaybackPositionTicks to milliseconds.
  static int? _positionTicksToMs(int? ticks) => _ticksToMs(ticks);

  /// Safely parse dynamic (num or String) to int. Jellyfin API may return numbers as strings.
  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// Parse year from Jellyfin EndDate (e.g. "2026-05-15" or "2026") for series end year.
  static int? _yearFromDate(dynamic v) {
    if (v == null) return null;
    final s = v is String ? v.trim() : v.toString().trim();
    if (s.isEmpty) return null;
    if (s.length >= 4) return int.tryParse(s.substring(0, 4));
    return int.tryParse(s);
  }

  /// Safely parse dynamic (num or String) to double.
  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  /// Map Jellyfin BaseItemDto to MediaMetadata (with serverId/serverName).
  MediaMetadata _itemToMetadata(Map<String, dynamic> item) {
    final id = item['Id']?.toString() ?? '';
    final name = item['Name'] as String? ?? 'Unknown';
    final type = _normalizeType(item['Type'] as String?);
    final userData = item['UserData'] as Map<String, dynamic>? ?? {};
    // Always use item id for thumb/art: Jellyfin serves at /Items/{Id}/Images/Primary (and Backdrop).
    // List responses often omit ImageTags; using id ensures thumbnails load everywhere.
    // For collections (BoxSet): only set thumb when the API reports a Primary image, so we don't request and get 404.
    final bool hasPrimaryImage = (item['ImageTags'] as Map<String, dynamic>?)?['Primary'] != null;
    final bool isCollection = type == 'collection';
    final thumbForItem = id.isEmpty
        ? null
        : (isCollection ? (hasPrimaryImage ? id : null) : id);
    final hasBackdrop = (item['BackdropImageTags'] as List?)?.isNotEmpty == true;
    final hasParentBackdrop = (item['ParentBackdropImageTags'] as List?)?.isNotEmpty == true;

    final leafCount = _leafCountForItem(item, type);
    final watchedEpisodeCount = _watchedEpisodeCountForItem(item, type, userData);
    // Unwatched badge: use unplayed count directly when API provides it (no need to fake leafCount).
    final unwatchedCount = (type == 'show' || type == 'season') ? _toInt(userData['UnplayedItemCount']) : null;

    return MediaMetadata(
      itemId: id,
      key: id,
      guid: item['Id']?.toString(),
      studio: _studioName(item['Studios']),
      type: type,
      title: name,
      titleSort: item['SortName'] as String?,
      contentRating: item['OfficialRating'] as String?,
      summary: item['Overview'] as String?,
      rating: _jellyfinRating(item),
      audienceRating: _jellyfinAudienceRating(item),
      ratingImage: _jellyfinRatingImage(item),
      audienceRatingImage: _jellyfinAudienceRatingImage(item),
      userRating: _toDouble(userData['UserRating']),
      year: _toInt(item['ProductionYear']),
      endYear: _yearFromDate(item['EndDate']),
      seriesStatus: item['Status'] as String?,
      originallyAvailableAt: item['PremiereDate'] as String?,
      thumb: thumbForItem,
      art: hasBackdrop ? id : null,
      duration: _ticksToMs(_toInt(item['RunTimeTicks'])),
      addedAt: item['DateCreated'] != null ? _parseDateToEpochSeconds(item['DateCreated']) : null,
      updatedAt: item['DateLastMediaAdded'] != null ? _parseDateToEpochSeconds(item['DateLastMediaAdded']) : null,
      lastPlayedAt: userData['LastPlayedDate'] != null ? _parseDateToEpochSeconds(userData['LastPlayedDate']) : null,
      seriesTitle: item['SeriesName'] as String?,
      seriesImageId: item['SeriesId']?.toString(),
      seriesArt: (type == 'episode' && hasParentBackdrop && item['SeriesId'] != null)
          ? item['SeriesId'].toString()
          : null,
      seriesId: item['SeriesId']?.toString(),
      seasonTitle: item['SeasonName'] as String?,
      seasonId: item['SeasonId']?.toString(),
      parentIndex: _toInt(item['ParentIndexNumber']),
      index: _toInt(item['IndexNumber']),
      resumePositionMs: _positionTicksToMs(_toInt(userData['PlaybackPositionTicks'])),
      playCount: _toInt(userData['PlayCount']),
      leafCount: leafCount,
      watchedEpisodeCount: watchedEpisodeCount,
      unwatchedCount: unwatchedCount,
      childCount: _toInt(item['ChildCount']),
      role: _peopleToRoles(item['People']),
      libraryId: _toInt(item['ParentId']),
      serverId: serverId,
      serverName: serverName,
      isFavorite: (userData['IsFavorite'] as bool?) == true ? true : null,
    );
  }

  /// Normalize to 0–10 scale. Jellyfin/plugins may send CommunityRating or CriticRating as 0–100 (e.g. 94 for IMDB).
  static double _normalizeRating(double value) {
    if (value > 10) return value / 10;
    return value;
  }

  /// Jellyfin rating (first chip): CriticRating (Rotten Tomatoes, show as %) else CommunityRating (TMDB, show as X.X).
  /// Values > 10 normalized to 0–10 (e.g. 83 → 8.3 for RT 83%, 94 → 9.4 for TMDB).
  static double? _jellyfinRating(Map<String, dynamic> item) {
    final critic = _toDouble(item['CriticRating']);
    if (critic != null) return _normalizeRating(critic);
    final community = _toDouble(item['CommunityRating']);
    if (community != null) return _normalizeRating(community);
    final custom = _parseCustomRating(item['CustomRating']);
    return custom != null ? _normalizeRating(custom) : null;
  }

  /// Jellyfin audience rating (second chip): CommunityRating from TMDB when we also have CriticRating.
  /// Normalized to 0–10 (e.g. 6.1 stays 6.1, 94 → 9.4).
  static double? _jellyfinAudienceRating(Map<String, dynamic> item) {
    final critic = _toDouble(item['CriticRating']);
    final community = _toDouble(item['CommunityRating']);
    if (critic != null && community != null) return _normalizeRating(community);
    return null;
  }

  /// First chip source: Rotten Tomatoes when CriticRating present, else TMDB for CommunityRating.
  static String? _jellyfinRatingImage(Map<String, dynamic> item) {
    if (_toDouble(item['CriticRating']) != null) return 'rottentomatoes://image.rating.ripe';
    if (_toDouble(item['CommunityRating']) != null) return 'themoviedb://';
    return _parseCustomRating(item['CustomRating']) != null ? 'themoviedb://' : null;
  }

  /// Second chip source: TMDB (community) when both critic and community present.
  static String? _jellyfinAudienceRatingImage(Map<String, dynamic> item) {
    final critic = _toDouble(item['CriticRating']);
    final community = _toDouble(item['CommunityRating']);
    return (critic != null && community != null) ? 'themoviedb://' : null;
  }

  static double? _parseCustomRating(dynamic custom) {
    if (custom == null) return null;
    final s = custom is String ? custom.trim() : custom.toString().trim();
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  /// Jellyfin Studios is array of {Name, Id}; return comma-separated names (movies/shows).
  static String? _studioName(dynamic studios) {
    final list = studios as List?;
    if (list == null || list.isEmpty) return null;
    final names = <String>[];
    for (final s in list) {
      if (s is Map) {
        final name = s['Name'];
        if (name != null) {
          final str = name is String ? name : name.toString();
          if (str.isNotEmpty) names.add(str);
        }
      } else if (s != null) {
        names.add(s.toString());
      }
    }
    return names.isEmpty ? null : names.join(', ');
  }

  /// Map Jellyfin People array to CastRole list for cast. People: [{Name, Id, Role, Type}, ...].
  static List<CastRole>? _peopleToRoles(dynamic people) {
    final list = people as List?;
    if (list == null || list.isEmpty) return null;
    final roles = <CastRole>[];
    for (final p in list) {
      if (p is! Map) continue;
      final name = p['Name'] as String?;
      if (name == null || name.isEmpty) continue;
      final characterRole = p['Role'] as String?;
      final id = p['Id']?.toString();
      roles.add(CastRole(
        tag: name,
        role: characterRole,
        thumb: id,
        tagKey: id,
      ));
    }
    return roles.isEmpty ? null : roles;
  }

  /// Total episode count: for Series use EpisodeCount/RecursiveItemCount; for Season use ChildCount.
  int? _leafCountForItem(Map<String, dynamic> item, String type) {
    if (type == 'show') {
      return _toInt(item['EpisodeCount']) ?? _toInt(item['RecursiveItemCount']) ?? _toInt(item['ChildCount']);
    }
    return _toInt(item['ChildCount']);
  }

  /// Watched episode count for shows/seasons when we have total (leafCount). Unwatched = leafCount - watchedEpisodeCount.
  /// When API omits ChildCount/EpisodeCount, we only set unwatchedCount from UnplayedItemCount; watchedEpisodeCount stays null.
  int? _watchedEpisodeCountForItem(Map<String, dynamic> item, String type, Map<String, dynamic> userData) {
    if (type != 'show' && type != 'season') return null;
    final leafCount = _leafCountForItem(item, type);
    final unplayed = _toInt(userData['UnplayedItemCount']);
    if (leafCount != null && unplayed != null && leafCount >= unplayed) {
      return leafCount - unplayed;
    }
    return null;
  }

  static int? _parseDateToEpochSeconds(dynamic v) {
    if (v == null) return null;
    if (v is int) return v > 10000000000 ? v ~/ 1000 : v;
    if (v is String) {
      final d = DateTime.tryParse(v);
      if (d == null) return null;
      return d.millisecondsSinceEpoch ~/ 1000;
    }
    return null;
  }

  /// Map Jellyfin view to MediaLibrary.
  /// Jellyfin CollectionType is "movies" / "tvshows"; app uses "movie" / "show" for hub filtering.
  MediaLibrary _viewToLibrary(Map<String, dynamic> view) {
    final id = view['Id']?.toString() ?? '';
    final name = view['Name'] as String? ?? 'Unknown';
    final colType = view['CollectionType'] as String? ?? view['Type'] as String? ?? 'mixed';
    var type = _normalizeType(colType);
    if (type == 'movies') type = 'movie';
    if (type == 'tvshows') type = 'show';

    return MediaLibrary(
      key: id,
      title: name,
      type: type,
      serverId: serverId,
      serverName: serverName,
    );
  }

  Future<Map<String, dynamic>> getServerIdentity() async {
    final response = await _dio.get<Map<String, dynamic>>('/System/Info');
    return response.data ?? {};
  }

  /// Synthetic library keys for top-level Collections and Playlists (Jellyfin treats these as libraries).
  static const String syntheticCollectionsKey = 'jellyfin_collections';
  static const String syntheticPlaylistsKey = 'jellyfin_playlists';

  Future<List<MediaLibrary>> getLibraries() async {
    if (_offlineMode) return [];
    final response = await _dio.get<Map<String, dynamic>>('/Users/${config.userId}/Views');
    final list = response.data?['Items'] as List?;
    if (list == null) return [];
    final all = list
        .map((e) => _viewToLibrary(e as Map<String, dynamic>))
        .toList();

    // Split: content libraries (Movies, Shows, etc.) vs Collections/Playlists (always at bottom).
    bool isCollectionOrPlaylist(MediaLibrary l) {
      final t = l.type.toLowerCase();
      return t == 'collection' || t == 'boxset' || t == 'boxsets' ||
          t == 'playlist' || t == 'playlists' ||
          l.title == 'Collections' || l.title == 'Playlists';
    }

    final contentLibraries = all.where((l) => !isCollectionOrPlaylist(l)).toList();
    final collectionPlaylistFromViews = all.where(isCollectionOrPlaylist).toList();

    // Sort only content libraries alphabetically by title.
    contentLibraries.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    // Build final list: sorted content, then Collections, then Playlists (from Views or synthetic).
    final hasCollectionLib = collectionPlaylistFromViews.any((l) {
      final t = l.type.toLowerCase();
      return t == 'collection' || t == 'boxset' || t == 'boxsets' || l.title == 'Collections';
    });
    final hasPlaylistLib = collectionPlaylistFromViews.any((l) {
      final t = l.type.toLowerCase();
      return t == 'playlist' || t == 'playlists' || l.title == 'Playlists';
    });

    final result = <MediaLibrary>[...contentLibraries];

    if (hasCollectionLib) {
      result.add(collectionPlaylistFromViews.firstWhere((l) {
        final t = l.type.toLowerCase();
        return t == 'collection' || t == 'boxset' || t == 'boxsets' || l.title == 'Collections';
      }));
    } else {
      final collections = await getGlobalCollections();
      if (collections.isNotEmpty) {
        result.add(MediaLibrary(
          key: syntheticCollectionsKey,
          title: 'Collections',
          type: 'collection',
          serverId: serverId,
          serverName: serverName,
        ));
      }
    }

    if (hasPlaylistLib) {
      result.add(collectionPlaylistFromViews.firstWhere((l) {
        final t = l.type.toLowerCase();
        return t == 'playlist' || t == 'playlists' || l.title == 'Playlists';
      }));
    } else {
      final playlists = await getPlaylists(playlistType: 'video');
      if (playlists.isNotEmpty) {
        result.add(MediaLibrary(
          key: syntheticPlaylistsKey,
          title: 'Playlists',
          type: 'playlist',
          serverId: serverId,
          serverName: serverName,
        ));
      }
    }

    return result;
  }

  Future<List<MediaMetadata>> getLibraryContent(
    String sectionId, {
    int? start,
    int? size,
    Map<String, String>? filters,
    dynamic cancelToken,
  }) async {
    if (_offlineMode) return [];
    final query = <String, dynamic>{
      'ParentId': sectionId,
      'Recursive': true,
      'Fields': _listFields,
    };
    if (start != null) query['StartIndex'] = start;
    if (size != null) query['Limit'] = size;

    // Parse app-level sort/type/filters into Jellyfin API params (do not pass raw type keys)
    final itemFilters = <String>[];
    String? sortBy;
    String? sortOrder;
    String? includeItemTypes;
    final genres = <String>[];
    final years = <int>[];
    final officialRatings = <String>[];
    final tagsList = <String>[];
    final videoTypesList = <String>[];
    String? seriesStatusValue;

    for (final e in (filters ?? {}).entries) {
      final k = e.key;
      final v = e.value;
      switch (k) {
        case 'sort':
          if (v.contains(':')) {
            final parts = v.split(':');
            sortBy = parts[0];
            sortOrder = (parts.length > 1 && parts[1].toLowerCase() == 'desc')
                ? 'Descending'
                : 'Ascending';
          } else {
            sortBy = v;
            sortOrder = 'Ascending';
          }
          break;
        case 'type':
          includeItemTypes = _typeIdToJellyfin(v);
          break;
        case 'genre':
        case 'Genre':
          if (v.isNotEmpty) genres.add(v);
          break;
        case 'year':
        case 'Year':
          final y = int.tryParse(v);
          if (y != null) years.add(y);
          break;
        case 'IsPlayed':
        case 'IsUnplayed':
        case 'IsResumable':
        case 'IsFavorite':
          if (v == '1') itemFilters.add(k);
          break;
        case 'HasSubtitles':
        case 'HasTrailer':
        case 'HasSpecialFeature':
        case 'HasThemeSong':
        case 'HasThemeVideo':
          if (v == '1') query[k] = true;
          break;
        case 'SeriesStatus':
          if (v.isNotEmpty) seriesStatusValue = v;
          break;
        case 'OfficialRating':
          if (v.isNotEmpty) officialRatings.add(v);
          break;
        case 'tags':
          if (v.isNotEmpty) tagsList.add(v);
          break;
        case 'VideoTypes':
          if (v.isNotEmpty) videoTypesList.add(v);
          break;
        default:
          // Ignore unknown keys from UI/serialization
          break;
      }
    }

    if (itemFilters.isNotEmpty) query['Filters'] = itemFilters.join(',');
    if (sortBy != null) query['SortBy'] = sortBy;
    if (sortOrder != null) query['SortOrder'] = sortOrder;
    if (includeItemTypes != null) query['IncludeItemTypes'] = includeItemTypes;
    if (genres.isNotEmpty) query['Genres'] = genres.join(',');
    if (years.isNotEmpty) query['Years'] = years.join(',');
    if (officialRatings.isNotEmpty) query['OfficialRatings'] = officialRatings.join(',');
    if (tagsList.isNotEmpty) query['Tags'] = tagsList.join(',');
    if (videoTypesList.isNotEmpty) query['VideoTypes'] = videoTypesList.join(',');
    if (seriesStatusValue != null && seriesStatusValue.isNotEmpty) {
      query['SeriesStatus'] = seriesStatusValue;
    }

    appLogger.d('Jellyfin getLibraryContent: ParentId=$sectionId Fields=${query['Fields']} IncludeItemTypes=$includeItemTypes StartIndex=${query['StartIndex']} Limit=${query['Limit']}');

    final response = await _dio.get<Map<String, dynamic>>(
      '/Users/${config.userId}/Items',
      queryParameters: query,
      cancelToken: cancelToken,
    );
    final list = response.data?['Items'] as List? ?? [];
    return list.map((e) => _itemToMetadata(e as Map<String, dynamic>)).toList();
  }

  /// Map type id (1=movie, 2=show, 3=season, 4=episode) to Jellyfin IncludeItemTypes.
  static String? _typeIdToJellyfin(String typeId) {
    switch (typeId) {
      case '1':
        return 'Movie';
      case '2':
        return 'Series';
      case '3':
        return 'Season';
      case '4':
        return 'Episode';
      default:
        return null;
    }
  }

  Future<MediaMetadata?> getMetadataWithImages(String itemId) async {
    if (_offlineMode) return null;
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/Users/${config.userId}/Items/$itemId',
        queryParameters: {'Fields': 'Overview,Genres,UserData,RunTimeTicks,Chapters,People,ItemCounts,CustomRating'},
      );
      final item = response.data;
      if (item == null) return null;
      return _itemToMetadata(item);
    } catch (e) {
      appLogger.e('Jellyfin getMetadataWithImages failed', error: e);
      return null;
    }
  }

  Future<Map<String, dynamic>> getMetadataWithNextEpisode(String itemId) async {
    final metadata = await getMetadataWithImages(itemId);
    MediaMetadata? nextEpisode;
    final type = metadata?.type.toLowerCase() ?? '';
    if (metadata != null && type == 'show' && !_offlineMode) {
      // Try NextUp API (omit Limit to work around Jellyfin 10.9 bug; take first result for this series)
      try {
        final query = {
          'UserId': config.userId,
          'SeriesId': itemId,
          'Fields': 'Overview,Genres,UserData,RunTimeTicks,Chapters,People,ItemCounts',
        };
        final response = await _dio.get<Map<String, dynamic>>(
          '/Shows/NextUp',
          queryParameters: query,
        );
        final data = response.data;
        var items = data?['Items'] as List?;
        if (items != null && items.isNotEmpty) {
          final first = items[0] as Map<String, dynamic>;
          nextEpisode = _itemToMetadata(first);
        }
      } catch (e) {
        appLogger.d('NextUp lookup failed for $itemId', error: e);
      }
      // Fallback: if NextUp returned nothing, compute first unwatched episode from seasons
      if (nextEpisode == null) {
        try {
          nextEpisode = await _getFirstUnwatchedEpisodeForShow(itemId);
        } catch (e) {
          appLogger.d('First-unwatched-episode fallback failed for $itemId', error: e);
        }
      }
    }
    return {'metadata': metadata, 'nextEpisode': nextEpisode};
  }

  /// Returns the first unwatched episode for a series (by season order, then episode index).
  Future<MediaMetadata?> _getFirstUnwatchedEpisodeForShow(String showItemId) async {
    final seasons = await getChildren(showItemId);
    if (seasons.isEmpty) return null;
    seasons.sort((a, b) => (a.parentIndex ?? 0).compareTo(b.parentIndex ?? 0));
    for (final season in seasons) {
      if (season.type.toLowerCase() != 'season') continue;
      final episodes = await getChildren(season.itemId);
      episodes.sort((a, b) => (a.index ?? 0).compareTo(b.index ?? 0));
      for (final ep in episodes) {
        if (ep.type.toLowerCase() != 'episode') continue;
        if (ep.playCount == null || ep.playCount! == 0) return ep;
      }
    }
    return null;
  }

  Future<List<MediaMetadata>> getChildren(String itemId) async {
    if (_offlineMode) return [];
    final response = await _dio.get<Map<String, dynamic>>(
      '/Users/${config.userId}/Items',
      queryParameters: {'ParentId': itemId, 'Fields': _listFields},
    );
    final list = response.data?['Items'] as List?;
    if (list == null) return [];
    return list.map((e) => _itemToMetadata(e as Map<String, dynamic>)).toList();
  }

  Future<List<MediaMetadata>> getExtras(String itemId) async {
    if (_offlineMode) return [];
    // Prefer local trailers (streamable in-app); fall back to remote (URLs open in browser).
    try {
      final localResponse = await _dio.get<dynamic>(
        '/Users/${config.userId}/Items/$itemId/LocalTrailers',
      );
      final localData = localResponse.data;
      final localList = localData is List ? localData : (localData is Map ? (localData['Items'] as List?) ?? [] : null);
      if (localList != null && localList.isNotEmpty) {
        final list = <MediaMetadata>[];
        for (final t in localList) {
          if (t is! Map<String, dynamic>) continue;
          final meta = _itemToMetadata(t);
          list.add(meta.copyWith(subtype: 'trailer'));
        }
        return list;
      }
    } catch (e) {
      appLogger.d('LocalTrailers lookup failed for $itemId', error: e);
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/Users/${config.userId}/Items/$itemId',
        queryParameters: {'Fields': 'RemoteTrailers'},
      );
      final item = response.data;
      final trailers = item?['RemoteTrailers'] as List?;
      if (trailers == null || trailers.isEmpty) return [];
      final list = <MediaMetadata>[];
      for (final t in trailers) {
        if (t is! Map) continue;
        final url = t['Url'] as String?;
        if (url == null || url.isEmpty) continue;
        final name = t['Name'] as String? ?? 'Trailer';
        list.add(MediaMetadata(
          itemId: url,
          key: url,
          type: 'clip',
          title: name,
          subtype: 'trailer',
          serverId: serverId,
          serverName: serverName,
        ));
      }
      return list;
    } catch (e) {
      appLogger.e('Jellyfin getExtras failed', error: e);
      return [];
    }
  }

  Future<List<MediaMetadata>> getAllUnwatchedEpisodes(String showItemId) async {
    final seasons = await getChildren(showItemId);
    final all = <MediaMetadata>[];
    for (final s in seasons) {
      if (s.type.toLowerCase() == 'season') {
        final episodes = await getChildren(s.itemId);
        all.addAll(episodes.where((e) => e.type.toLowerCase() == 'episode' && (e.playCount ?? 0) == 0));
      }
    }
    return all;
  }

  Future<List<MediaMetadata>> getUnwatchedEpisodesInSeason(String seasonId) async {
    final episodes = await getChildren(seasonId);
    return episodes.where((e) => e.type.toLowerCase() == 'episode' && (e.playCount ?? 0) == 0).toList();
  }

  String getThumbnailUrl(String? thumbPath) {
    if (thumbPath == null || thumbPath.isEmpty) return '';
    final base = config.baseUrl.endsWith('/') ? config.baseUrl : '${config.baseUrl}/';
    final token = config.token;
    return token.isEmpty
        ? '${base}Items/$thumbPath/Images/Primary'
        : '${base}Items/$thumbPath/Images/Primary?ApiKey=${Uri.encodeComponent(token)}';
  }

  /// Build a trickplay (timeline scrub) thumbnail URL for the given position.
  /// Uses Jellyfin 10.9+ native trickplay. Returns null if token unavailable.
  /// [itemId] is the video item id (itemId). [positionMs] is position in milliseconds.
  /// Default interval is 10s per tile; width 320 is a common resolution.
  String? getTrickplayTileUrl(String itemId, int positionMs, {int width = 320, int intervalMs = 10000}) {
    final token = config.token;
    if (token.isEmpty) return null;
    final base = config.baseUrl.endsWith('/') ? config.baseUrl : '${config.baseUrl}/';
    final index = (positionMs / intervalMs).floor();
    return '${base}Videos/$itemId/Trickplay/$width/$index.jpg?ApiKey=${Uri.encodeComponent(token)}';
  }

  /// Probe whether trickplay data exists for [itemId] by requesting the first tile.
  /// Returns true if the server responds with 200; false on 404 or any error.
  Future<bool> checkTrickplayAvailable(String itemId, {int width = 320}) async {
    try {
      final response = await _dio.get<dynamic>(
        '/Videos/$itemId/Trickplay/$width/0.jpg',
        options: Options(responseType: ResponseType.bytes, receiveTimeout: const Duration(seconds: 5)),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Map<String, String>? get imageHttpHeaders => requestHeaders;

  Future<List<Chapter>> getChapters(String itemId, {bool includeImages = false}) async {
    try {
      final item = await _dio.get<Map<String, dynamic>>(
        '/Users/${config.userId}/Items/$itemId',
        queryParameters: {'Fields': 'Chapters'},
      );
      final chapters = item.data?['Chapters'] as List?;
      if (chapters == null) return [];
      final base = config.baseUrl.endsWith('/') ? config.baseUrl : '${config.baseUrl}/';
      final token = config.token;
      final list = <Chapter>[];
      for (var i = 0; i < chapters.length; i++) {
        final c = chapters[i] as Map<String, dynamic>;
        final start = _toInt(c['StartPositionTicks']);
        final end = _toInt(c['EndPositionTicks']);
        final imageTag = c['ImageTag'] as String?;
        String? thumb;
        if (includeImages && imageTag != null && imageTag.isNotEmpty) {
          thumb = '${base}Items/$itemId/Images/Chapter/$i?tag=$imageTag&ApiKey=${Uri.encodeComponent(token)}';
        }
        list.add(Chapter(
          id: i,
          index: i,
          startTimeOffset: _ticksToMs(start),
          endTimeOffset: _ticksToMs(end),
          title: c['Name'] as String?,
          thumb: thumb,
        ));
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<List<Marker>> getMarkers(String itemId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/MediaSegments/$itemId',
      );
      final items = response.data?['Items'] as List?;
      if (items == null || items.isEmpty) return [];
      final list = <Marker>[];
      var id = 0;
      for (final seg in items) {
        final s = seg as Map<String, dynamic>;
        final startTicks = _toInt(s['StartTicks']);
        final endTicks = _toInt(s['EndTicks']);
        final typeRaw = s['Type'] as String?;
        if (startTicks == null || endTicks == null) continue;
        final startMs = _ticksToMs(startTicks) ?? 0;
        final endMs = _ticksToMs(endTicks) ?? 0;
        final type = _normalizeSegmentType(typeRaw);
        if (type != null) {
          list.add(Marker(
            id: id++,
            type: type,
            startTimeOffset: startMs,
            endTimeOffset: endMs,
          ));
        }
      }
      return list;
    } catch (e) {
      appLogger.d('Jellyfin getMarkers failed for $itemId: $e');
      return [];
    }
  }

  /// Normalizes Jellyfin MediaSegmentType to lowercase app type.
  static String? _normalizeSegmentType(String? type) {
    if (type == null || type.isEmpty) return null;
    switch (type) {
      case 'Intro':
        return 'intro';
      case 'Outro':
        return 'outro';
      case 'Recap':
        return 'recap';
      case 'Preview':
        return 'preview';
      case 'Commercial':
        return 'commercial';
      default:
        return null;
    }
  }

  Future<List<MediaMetadata>> getSimilarItems(String itemId, {int limit = 12}) async {
    if (_offlineMode) return [];
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/Items/$itemId/Similar',
        queryParameters: {
          'UserId': config.userId,
          'Limit': limit,
          'Fields': _listFields,
        },
      );
      final list = response.data?['Items'] as List?;
      if (list == null) return [];
      return list.map((e) => _itemToMetadata(e as Map<String, dynamic>)).toList();
    } catch (e) {
      appLogger.d('Jellyfin getSimilarItems failed for $itemId: $e');
      return [];
    }
  }

  /// Get person/actor details via the standard item endpoint (returns full fields).
  Future<Map<String, dynamic>?> getPersonDetails(String personId) async {
    if (_offlineMode) return null;
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/Users/${config.userId}/Items/$personId',
      );
      if (response.statusCode != 200 || response.data == null) return null;
      final d = response.data!;
      return {
        'name': d['Name'] as String?,
        'id': d['Id'] as String?,
        'overview': d['Overview'] as String?,
        'imageTag': (d['ImageTags'] as Map?)?['Primary'] as String?,
        'birthDate': d['PremiereDate'] as String?,
        'deathDate': d['EndDate'] as String?,
        'birthPlace': d['ProductionLocations'] is List
            ? ((d['ProductionLocations'] as List).isNotEmpty ? (d['ProductionLocations'] as List).first as String? : null)
            : null,
      };
    } catch (e) {
      appLogger.d('Failed to get person details for $personId: $e');
      return null;
    }
  }

  /// Get movies and shows on this server featuring a person.
  Future<List<MediaMetadata>> getItemsByPerson(String personId, {int limit = 50}) async {
    if (_offlineMode) return [];
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/Items',
        queryParameters: {
          'PersonIds': personId,
          'Recursive': true,
          'IncludeItemTypes': 'Movie,Series',
          'UserId': config.userId,
          'Limit': limit,
          'Fields': _listFields,
          'SortBy': 'SortName',
          'SortOrder': 'Ascending',
        },
      );
      final list = response.data?['Items'] as List?;
      if (list == null) return [];
      return list.map((e) => _itemToMetadata(e as Map<String, dynamic>)).toList();
    } catch (e) {
      appLogger.d('Jellyfin getItemsByPerson failed for $personId: $e');
      return [];
    }
  }

  /// Build URL for a person's primary image.
  String getPersonImageUrl(String personId) {
    final base = config.baseUrl.endsWith('/') ? config.baseUrl : '${config.baseUrl}/';
    final token = config.token;
    return token.isEmpty
        ? '${base}Items/$personId/Images/Primary'
        : '${base}Items/$personId/Images/Primary?ApiKey=${Uri.encodeComponent(token)}';
  }

  Future<PlaybackExtras> getPlaybackExtras(String itemId, {bool includeChapterImages = false}) async {
    final chapters = await getChapters(itemId, includeImages: includeChapterImages);
    final markers = await getMarkers(itemId);
    return PlaybackExtras(chapters: chapters, markers: markers);
  }

  Future<VideoPlaybackData> getVideoPlaybackData(String itemId, {int mediaIndex = 0}) async {
    String? videoUrl;
    MediaInfo? mediaInfo;
    final versions = <MediaVersion>[];
    final markers = <Marker>[];

    if (!_offlineMode) {
      try {
        final itemResponse = await _dio.get<Map<String, dynamic>>(
          '/Users/${config.userId}/Items/$itemId',
          queryParameters: {'Fields': 'MediaSources,MediaStreams,Chapters'},
        );
        final item = itemResponse.data;
        if (item != null) {
          final mediaSources = item['MediaSources'] as List?;
          if (mediaSources != null && mediaSources.isNotEmpty) {
            final idx = mediaIndex.clamp(0, mediaSources.length - 1);
            final source = mediaSources[idx] as Map<String, dynamic>;
            final container = source['Container'] as String?;
            // Prefer a direct, Range-capable stream so MPV can seek. The server may return
            // TranscodingUrl (e.g. HLS) which is not seekable. Build stream.{container} with
            // static=true to request the original file / direct stream (HTTP Range support).
            if (container != null && container.isNotEmpty) {
              final base = config.baseUrl.endsWith('/') ? config.baseUrl : '${config.baseUrl}/';
              final q = <String>['static=true', 'allowVideoStreamCopy=true', 'allowAudioStreamCopy=true', 'api_key=${config.token}'];
              final mediaSourceId = source['Id'] as String?;
              if (mediaSourceId != null && mediaSourceId.isNotEmpty) {
                q.add('mediaSourceId=$mediaSourceId');
              }
              videoUrl = '${base}Videos/$itemId/stream.$container?${q.join('&')}';
            }
            if (videoUrl == null) {
              final directUrl = source['DirectStreamUrl'] as String?;
              final transcodeUrl = source['TranscodingUrl'] as String?;
              videoUrl = directUrl ?? transcodeUrl;
              if (videoUrl != null && !videoUrl.startsWith('http')) {
                videoUrl = '${config.baseUrl}$videoUrl';
                if (!videoUrl.contains('?')) {
                  videoUrl = '$videoUrl?api_key=${config.token}';
                } else {
                  videoUrl = '$videoUrl&api_key=${config.token}';
                }
              }
            }
            videoUrl ??= '${config.baseUrl}/Videos/$itemId/stream?api_key=${config.token}';
            final streams = item['MediaStreams'] as List? ?? [];
            final audioTracks = <MediaAudioTrack>[];
            final subtitleTracks = <MediaSubtitleTrack>[];
            var audioIdx = 0;
            var subIdx = 0;
            final mediaSourceId = source['Id'] as String? ?? '';
            for (final s in streams) {
              final m = s as Map<String, dynamic>;
              final type = m['Type'] as String?;
              if (type == 'Audio') {
                audioTracks.add(MediaAudioTrack(
                  id: audioIdx,
                  index: audioIdx,
                  codec: m['Codec'] as String?,
                  language: m['Language'] as String?,
                  languageCode: m['Language'] as String?,
                  title: m['Title'] as String?,
                  displayTitle: m['DisplayTitle'] as String?,
                  channels: _toInt(m['Channels']),
                  selected: m['IsDefault'] == true,
                ));
                audioIdx++;
              } else if (type == 'Subtitle') {
                final streamIndex = _toInt(m['Index']) ?? subIdx;
                // Build Jellyfin subtitle URL path so getSubtitleUrl can build full URL.
                // GET /Videos/{itemId}/{mediaSourceId}/Subtitles/{index}/Stream.{format}
                final subtitleKey = mediaSourceId.isNotEmpty
                    ? 'Videos/$itemId/$mediaSourceId/Subtitles/$streamIndex/Stream'
                    : null;
                subtitleTracks.add(MediaSubtitleTrack(
                  id: subIdx,
                  index: subIdx,
                  codec: m['Codec'] as String?,
                  language: m['Language'] as String?,
                  languageCode: m['Language'] as String?,
                  title: m['Title'] as String?,
                  displayTitle: m['DisplayTitle'] as String?,
                  selected: m['IsDefault'] == true,
                  forced: m['IsForced'] == true,
                  key: subtitleKey,
                ));
                subIdx++;
              }
            }
            final chapters = await getChapters(itemId);
            mediaInfo = MediaInfo(
              videoUrl: videoUrl,
              audioTracks: audioTracks,
              subtitleTracks: subtitleTracks,
              chapters: chapters,
              partId: null,
            );
            for (final ms in mediaSources) {
              final m = ms as Map<String, dynamic>;
              versions.add(MediaVersion(
                id: _toInt(m['Index']) ?? 0,
                videoResolution: m['VideoType'] as String?,
                videoCodec: m['VideoCodec'] as String?,
                bitrate: _toInt(m['Bitrate']),
                width: _toInt(m['Width']),
                height: _toInt(m['Height']),
                container: m['Container'] as String?,
                partKey: '',
              ));
            }
          }
        }
      } catch (e) {
        appLogger.e('Jellyfin getVideoPlaybackData failed', error: e);
        videoUrl = '${config.baseUrl}/Videos/$itemId/stream?api_key=${config.token}';
      }
    }

    return VideoPlaybackData(
      videoUrl: videoUrl,
      mediaInfo: mediaInfo,
      availableVersions: versions,
      markers: markers,
    );
  }

  Future<FileInfo?> getFileInfo(String itemId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/Users/${config.userId}/Items/$itemId',
        queryParameters: {'Fields': 'MediaSources,MediaStreams'},
      );
      final item = response.data;
      final sources = item?['MediaSources'] as List?;
      if (sources == null || sources.isEmpty) return null;
      final source = sources.first as Map<String, dynamic>;
      // Prefer stream data from the selected media source when available.
      final sourceStreams = source['MediaStreams'] as List?;
      final itemStreams = item?['MediaStreams'] as List?;
      final streams = (sourceStreams != null && sourceStreams.isNotEmpty) ? sourceStreams : (itemStreams ?? []);
      Map<String, dynamic>? videoStream;
      Map<String, dynamic>? audioStream;
      for (final s in streams) {
        final m = s as Map<String, dynamic>;
        if (m['Type'] == 'Video' && videoStream == null) videoStream = m;
        if (m['Type'] == 'Audio' && audioStream == null) audioStream = m;
      }

      double? parseAspectRatio(dynamic value) {
        if (value == null) return null;
        if (value is num) return value.toDouble();
        final ratio = value.toString().trim();
        if (ratio.isEmpty) return null;
        if (ratio.contains(':')) {
          final parts = ratio.split(':');
          if (parts.length == 2) {
            final w = double.tryParse(parts[0]);
            final h = double.tryParse(parts[1]);
            if (w != null && h != null && h > 0) return w / h;
          }
        }
        return double.tryParse(ratio);
      }

      return FileInfo(
        container: (source['Container'] as String?) ?? (item?['Container'] as String?),
        videoCodec: (videoStream?['Codec'] as String?) ?? (source['VideoCodec'] as String?),
        videoResolution: source['VideoType'] as String?,
        videoFrameRate: videoStream?['DisplayTitle'] as String?,
        videoProfile: (videoStream?['Profile'] as String?) ?? (source['VideoProfile'] as String?),
        width: _toInt(videoStream?['Width']) ?? _toInt(source['Width']),
        height: _toInt(videoStream?['Height']) ?? _toInt(source['Height']),
        aspectRatio: parseAspectRatio(videoStream?['AspectRatio']) ?? parseAspectRatio(source['AspectRatio']),
        bitrate: _toInt(videoStream?['BitRate']) ?? _toInt(source['Bitrate']),
        duration: _ticksToMs(_toInt(source['RunTimeTicks']) ?? _toInt(item?['RunTimeTicks'])),
        audioCodec: (audioStream?['Codec'] as String?) ?? (source['AudioCodec'] as String?),
        audioProfile: audioStream?['Profile'] as String?,
        audioChannels: _toInt(audioStream?['Channels']) ?? _toInt(source['AudioChannels']),
        optimizedForStreaming: source['SupportsDirectPlay'] == true || source['SupportsDirectStream'] == true,
        has64bitOffsets: source['Has64BitOffsets'] == true,
        filePath: source['Path'] as String?,
        fileSize: _toInt(source['Size']),
        colorSpace: videoStream?['ColorSpace'] as String?,
        colorRange: videoStream?['ColorRange'] as String?,
        colorPrimaries: videoStream?['ColorPrimaries'] as String?,
        colorTrc: videoStream?['ColorTransfer'] as String?,
        chromaSubsampling: videoStream?['ChromaSubsampling'] as String?,
        frameRate:
            _toDouble(videoStream?['RealFrameRate']) ??
            _toDouble(videoStream?['AverageFrameRate']) ??
            _toDouble(videoStream?['FrameRate']),
        bitDepth: _toInt(videoStream?['BitDepth']),
        audioChannelLayout: (audioStream?['ChannelLayout'] as String?) ?? (audioStream?['DisplayTitle'] as String?),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> markAsWatched(String itemId, {MediaMetadata? metadata}) async {
    if (_offlineMode) return;
    await _dio.post('/Users/${config.userId}/PlayedItems/$itemId');
    if (metadata != null) {
      WatchStateNotifier().notifyWatched(metadata: metadata, isNowWatched: true);
    }
  }

  Future<void> markAsUnwatched(String itemId, {MediaMetadata? metadata}) async {
    if (_offlineMode) return;
    await _dio.delete('/Users/${config.userId}/PlayedItems/$itemId');
    if (metadata != null) {
      WatchStateNotifier().notifyWatched(metadata: metadata, isNowWatched: false);
    }
  }

  Future<bool?> toggleFavorite(String itemId, {bool? isCurrentlyFavorite}) async {
    if (_offlineMode) return null;
    try {
      final isFavorite = isCurrentlyFavorite ?? false;
      if (isFavorite) {
        await _dio.delete('/Users/${config.userId}/FavoriteItems/$itemId');
        return false;
      } else {
        await _dio.post('/Users/${config.userId}/FavoriteItems/$itemId');
        return true;
      }
    } catch (e) {
      appLogger.e('Jellyfin toggleFavorite failed', error: e);
      return null;
    }
  }

  Future<void> updateProgress(
    String itemId, {
    required int time,
    required String state,
    int? duration,
  }) async {
    if (_offlineMode) return;
    await _dio.post(
      '/Sessions/Playing/Progress',
      data: {
        'ItemId': itemId,
        'PositionTicks': time * 10000,
        'IsPaused': state == 'paused',
        if (duration != null) 'PlaybackDurationTicks': duration * 10000,
      },
    );
  }

  /// Authorize a Quick Connect code from another device.
  /// The current authenticated user approves the code so the other device can sign in.
  Future<bool> authorizeQuickConnect(String code) async {
    try {
      final response = await _dio.post(
        '/QuickConnect/Authorize',
        queryParameters: {'code': code},
      );
      return response.statusCode == 200;
    } catch (e) {
      appLogger.e('QuickConnect Authorize failed: $e');
      return false;
    }
  }

  Future<bool> rateItem(String itemId, double rating) async {
    try {
      await _dio.post(
        '/Users/${config.userId}/Items/$itemId/Rating',
        data: {'Rating': rating < 0 ? 0 : rating},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteMediaItem(String itemId) async {
    try {
      await _dio.delete('/Items/$itemId');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<MediaMetadata>> search(String query, {int limit = 10}) async {
    if (_offlineMode) return [];
    final response = await _dio.get<Map<String, dynamic>>(
      '/Users/${config.userId}/Items',
      queryParameters: {
        'SearchTerm': query,
        'Limit': limit,
        'IncludeItemTypes': 'Movie,Series',
        'Recursive': true,
        'Fields': _listFields,
      },
    );
    final list = response.data?['Items'] as List?;
    if (list == null) return [];
    return list.map((e) => _itemToMetadata(e as Map<String, dynamic>)).toList();
  }

  Future<List<MediaMetadata>> getRecentlyAdded({int limit = 50}) async {
    if (_offlineMode) return [];
    final response = await _dio.get<Map<String, dynamic>>(
      '/Users/${config.userId}/Items',
      queryParameters: {
        'SortBy': 'DateCreated',
        'SortOrder': 'Descending',
        'IncludeItemTypes': 'Movie,Episode',
        'Recursive': true,
        'Limit': limit,
        'Fields': _listFields,
      },
    );
    final list = response.data?['Items'] as List?;
    if (list == null) return [];
    return list.map((e) => _itemToMetadata(e as Map<String, dynamic>)).toList();
  }

  Future<List<MediaMetadata>> getContinueWatching() async {
    if (_offlineMode) return [];
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/Users/${config.userId}/Items/Resume',
        queryParameters: {'Limit': 20, 'Fields': _listFields},
      );
      final list = response.data?['Items'] as List?;
      if (list == null) return [];
      return list.map((e) => _itemToMetadata(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<MediaMetadata>> getContinueWatchingForLibrary(String sectionId) async {
    if (_offlineMode) return [];
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/Users/${config.userId}/Items/Resume',
        queryParameters: {
          'ParentId': sectionId,
          'Limit': 20,
          'Fields': _listFields,
        },
      );
      final list = response.data?['Items'] as List?;
      if (list == null) return [];
      return list.map((e) => _itemToMetadata(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> getSessions() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/Sessions');
      final list = response.data?['Sessions'] as List?;
      return list ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<List<LibraryFilter>> getLibraryFilters(String sectionId, {String? libraryType}) async {
    if (_offlineMode) return [];
    final t = (libraryType ?? '').toLowerCase();
    final sectionPrefix = sectionId; // used in key for getFilterValues

    const filtersGroup = 'Filters';
    const featuresGroup = 'Features';
    const statusGroup = 'Status';
    const genresGroup = 'Genres';
    const parentalGroup = 'Parental Ratings';
    const tagsGroup = 'Tags';
    const videoTypesGroup = 'Video Types';
    const yearsGroup = 'Years';

    final filters = <LibraryFilter>[];

    // Top-level group: Filters → Played, Unplayed, Resumable, Favorites
    filters.addAll([
      LibraryFilter(filter: 'IsPlayed', filterType: 'boolean', key: 'IsPlayed', title: 'Played', type: 'filter', group: filtersGroup),
      LibraryFilter(filter: 'IsUnplayed', filterType: 'boolean', key: 'IsUnplayed', title: 'Unplayed', type: 'filter', group: filtersGroup),
      LibraryFilter(filter: 'IsResumable', filterType: 'boolean', key: 'IsResumable', title: 'Resumable', type: 'filter', group: filtersGroup),
      LibraryFilter(filter: 'IsFavorite', filterType: 'boolean', key: 'IsFavorite', title: 'Favorites', type: 'filter', group: filtersGroup),
    ]);

    // Top-level group: Status (Shows only, before Features)
    if (t == 'show') {
      filters.add(LibraryFilter(
        filter: 'SeriesStatus',
        filterType: 'string',
        key: 'seriesStatus:$sectionPrefix',
        title: 'Status',
        type: 'filter',
        group: statusGroup,
      ));
    }

    // Top-level group: Features → Subtitles, Trailer, Special Features, Theme Song, Theme Video
    filters.addAll([
      LibraryFilter(filter: 'HasSubtitles', filterType: 'boolean', key: 'HasSubtitles', title: 'Subtitles', type: 'filter', group: featuresGroup),
      LibraryFilter(filter: 'HasTrailer', filterType: 'boolean', key: 'HasTrailer', title: 'Trailer', type: 'filter', group: featuresGroup),
      LibraryFilter(filter: 'HasSpecialFeature', filterType: 'boolean', key: 'HasSpecialFeature', title: 'Special Features', type: 'filter', group: featuresGroup),
      LibraryFilter(filter: 'HasThemeSong', filterType: 'boolean', key: 'HasThemeSong', title: 'Theme Song', type: 'filter', group: featuresGroup),
      LibraryFilter(filter: 'HasThemeVideo', filterType: 'boolean', key: 'HasThemeVideo', title: 'Theme Video', type: 'filter', group: featuresGroup),
    ]);

    // Top-level groups: Genres, Parental Ratings, Tags, Video Types (Movies only), Years
    filters.addAll([
      LibraryFilter(
        filter: 'genre',
        filterType: 'string',
        key: 'genre:$sectionPrefix',
        title: 'Genres',
        type: 'filter',
        group: genresGroup,
      ),
      LibraryFilter(
        filter: 'OfficialRating',
        filterType: 'string',
        key: 'officialRating:$sectionPrefix',
        title: 'Parental Ratings',
        type: 'filter',
        group: parentalGroup,
      ),
      LibraryFilter(
        filter: 'tags',
        filterType: 'string',
        key: 'tags:$sectionPrefix',
        title: 'Tags',
        type: 'filter',
        group: tagsGroup,
      ),
    ]);

    if (t == 'movie') {
      filters.add(LibraryFilter(
        filter: 'VideoTypes',
        filterType: 'string',
        key: 'videoType:',
        title: 'Video Types',
        type: 'filter',
        group: videoTypesGroup,
      ));
    }

    filters.add(LibraryFilter(
      filter: 'year',
      filterType: 'string',
      key: 'year:$sectionPrefix',
      title: 'Years',
      type: 'filter',
      group: yearsGroup,
    ));

    return filters;
  }

  Future<List<FirstCharacter>> getFirstCharacters(
    String sectionId, {
    int? type,
    Map<String, String>? filters,
  }) async {
    if (_offlineMode) return [];
    try {
      final query = <String, dynamic>{
        'ParentId': sectionId,
        'Recursive': true,
        'Fields': 'SortName',
        'SortBy': 'SortName',
        'SortOrder': 'Ascending',
        'EnableImages': false,
        'EnableTotalRecordCount': false,
      };

      if (type != null) {
        final jellyfinType = _typeIdToJellyfin(type.toString());
        if (jellyfinType != null) {
          query['IncludeItemTypes'] = jellyfinType;
        }
      }

      if (filters != null) {
        final itemFilters = <String>[];
        final genres = <String>[];
        final years = <int>[];
        final officialRatings = <String>[];
        final tagsList = <String>[];
        for (final e in filters.entries) {
          switch (e.key) {
            case 'sort':
            case 'type':
              break;
            case 'genre':
            case 'Genre':
              if (e.value.isNotEmpty) genres.add(e.value);
              break;
            case 'year':
            case 'Year':
              final y = int.tryParse(e.value);
              if (y != null) years.add(y);
              break;
            case 'IsPlayed':
            case 'IsUnplayed':
            case 'IsResumable':
            case 'IsFavorite':
              if (e.value == '1') itemFilters.add(e.key);
              break;
            case 'HasSubtitles':
            case 'HasTrailer':
            case 'HasSpecialFeature':
            case 'HasThemeSong':
            case 'HasThemeVideo':
              if (e.value == '1') query[e.key] = true;
              break;
            case 'SeriesStatus':
              if (e.value.isNotEmpty) query['SeriesStatus'] = e.value;
              break;
            case 'OfficialRating':
              if (e.value.isNotEmpty) officialRatings.add(e.value);
              break;
            case 'tags':
              if (e.value.isNotEmpty) tagsList.add(e.value);
              break;
            case 'VideoTypes':
              if (e.value.isNotEmpty) query['VideoTypes'] = e.value;
              break;
          }
        }
        if (itemFilters.isNotEmpty) query['Filters'] = itemFilters.join(',');
        if (genres.isNotEmpty) query['Genres'] = genres.join(',');
        if (years.isNotEmpty) query['Years'] = years.join(',');
        if (officialRatings.isNotEmpty) query['OfficialRatings'] = officialRatings.join(',');
        if (tagsList.isNotEmpty) query['Tags'] = tagsList.join(',');
      }

      final response = await _dio.get<Map<String, dynamic>>(
        '/Users/${config.userId}/Items',
        queryParameters: query,
      );
      final items = response.data?['Items'] as List? ?? [];

      final charCounts = <String, int>{};
      for (final item in items) {
        final map = item as Map<String, dynamic>;
        final sortName = map['SortName'] as String? ?? map['Name'] as String? ?? '';
        if (sortName.isEmpty) continue;
        final firstChar = sortName[0].toUpperCase();
        final key = RegExp(r'[A-Z]').hasMatch(firstChar) ? firstChar : '#';
        charCounts[key] = (charCounts[key] ?? 0) + 1;
      }

      final sortedKeys = charCounts.keys.toList()
        ..sort((a, b) {
          if (a == '#') return -1;
          if (b == '#') return 1;
          return a.compareTo(b);
        });

      return sortedKeys
          .map((key) => FirstCharacter(key: key, title: key, size: charCounts[key]!))
          .toList();
    } catch (e) {
      appLogger.e('Failed to get first characters', error: e);
      return [];
    }
  }

  Future<List<LibraryFilterValue>> getFilterValues(String filterKey) async {
    if (_offlineMode) return [];
    if (!filterKey.contains(':')) return [];
    final colonIndex = filterKey.indexOf(':');
    final kind = filterKey.substring(0, colonIndex);
    final sectionId = filterKey.length > colonIndex + 1 ? filterKey.substring(colonIndex + 1) : '';
    // sectionId can be empty for videoType (key is "videoType:")

    if (kind == 'genre') {
      if (sectionId.isEmpty) return [];
      try {
        final response = await _dio.get<Map<String, dynamic>>(
          '/Genres',
          queryParameters: {
            'userId': config.userId,
            'parentId': sectionId,
            'sortBy': 'SortName',
            'sortOrder': 'Ascending',
          },
        );
        final list = response.data?['Items'] as List? ?? [];
        return list
            .map((e) {
              final name = e['Name'] as String? ?? '';
              return LibraryFilterValue(key: name, title: name, type: 'genre');
            })
            .toList();
      } catch (e) {
        appLogger.d('Jellyfin getFilterValues(genre) failed: $e');
        return [];
      }
    }

    if (kind == 'year') {
      if (sectionId.isEmpty) return [];
      try {
        final response = await _dio.get<Map<String, dynamic>>(
          '/Years',
          queryParameters: {
            'userId': config.userId,
            'parentId': sectionId,
            'sortOrder': 'Descending',
          },
        );
        final list = response.data?['Items'] as List? ?? [];
        return list
            .map((e) {
              final name = (e as Map<String, dynamic>)['Name']?.toString() ?? '';
              return LibraryFilterValue(key: name, title: name, type: 'year');
            })
            .toList();
      } catch (e) {
        appLogger.d('Jellyfin getFilterValues(year) failed: $e');
        return [];
      }
    }

    if (kind == 'officialRating') {
      if (sectionId.isEmpty) return [];
      try {
        final response = await _dio.get<Map<String, dynamic>>(
          '/Users/${config.userId}/Items',
          queryParameters: {
            'ParentId': sectionId,
            'Recursive': true,
            'Fields': 'OfficialRating',
            'IncludeItemTypes': 'Movie,Series',
            'Limit': 500,
          },
        );
        final list = response.data?['Items'] as List? ?? [];
        final seen = <String>{};
        final values = <LibraryFilterValue>[];
        for (final e in list) {
          final rating = (e as Map<String, dynamic>)['OfficialRating']?.toString().trim();
          if (rating != null && rating.isNotEmpty && seen.add(rating)) {
            values.add(LibraryFilterValue(key: rating, title: rating, type: 'rating'));
          }
        }
        values.sort((a, b) => a.title.compareTo(b.title));
        return values.isNotEmpty ? values : _defaultOfficialRatingValues();
      } catch (e) {
        appLogger.d('Jellyfin getFilterValues(officialRating) failed: $e');
        return _defaultOfficialRatingValues();
      }
    }

    if (kind == 'tags') {
      if (sectionId.isEmpty) return [];
      try {
        final response = await _dio.get<Map<String, dynamic>>(
          '/Users/${config.userId}/Items',
          queryParameters: {
            'ParentId': sectionId,
            'Recursive': true,
            'Fields': 'Tags',
            'IncludeItemTypes': 'Movie,Series',
            'Limit': 500,
          },
        );
        final list = response.data?['Items'] as List? ?? [];
        final seen = <String>{};
        for (final e in list) {
          final tags = e['Tags'] as List?;
          if (tags != null) {
            for (final t in tags) {
              final tag = t?.toString().trim();
              if (tag != null && tag.isNotEmpty) seen.add(tag);
            }
          }
        }
        return (seen.toList()..sort())
            .map((s) => LibraryFilterValue(key: s, title: s, type: 'tag'))
            .toList();
      } catch (e) {
        appLogger.d('Jellyfin getFilterValues(tags) failed: $e');
        return [];
      }
    }

    if (kind == 'videoType') {
      // Match Jellyfin web: BD, DVD, HD, 4K, SD, 3D (video quality/format)
      return [
        LibraryFilterValue(key: 'BluRay', title: 'BD', type: 'videoType'),
        LibraryFilterValue(key: 'Dvd', title: 'DVD', type: 'videoType'),
        LibraryFilterValue(key: 'Hd', title: 'HD', type: 'videoType'),
        LibraryFilterValue(key: '4K', title: '4K', type: 'videoType'),
        LibraryFilterValue(key: 'Sd', title: 'SD', type: 'videoType'),
        LibraryFilterValue(key: 'ThreeD', title: '3D', type: 'videoType'),
      ];
    }

    if (kind == 'seriesStatus') {
      return [
        LibraryFilterValue(key: 'Continuing', title: 'Continuing', type: 'seriesStatus'),
        LibraryFilterValue(key: 'Ended', title: 'Ended', type: 'seriesStatus'),
        LibraryFilterValue(key: 'NotYetReleased', title: 'Not yet released', type: 'seriesStatus'),
      ];
    }

    return [];
  }

  static List<LibraryFilterValue> _defaultOfficialRatingValues() {
    return [
      'G', 'PG', 'PG-13', 'R', 'NC-17',
      'TV-Y', 'TV-G', 'TV-PG', 'TV-14', 'TV-MA', 'NR', 'Unrated',
    ].map((s) => LibraryFilterValue(key: s, title: s, type: 'rating')).toList();
  }

  Future<List<LibrarySort>> getLibrarySorts(String sectionId, {String? libraryType}) async {
    final t = (libraryType ?? '').toLowerCase();
    // Movies: match Jellyfin web UI sort list and order.
    if (t == 'movie') {
      return [
        LibrarySort(key: 'SortName', title: 'Name', defaultDirection: 'asc'),
        LibrarySort(key: 'Random', title: 'Random', defaultDirection: 'asc'),
        LibrarySort(key: 'CommunityRating', descKey: 'CommunityRating:desc', title: 'Community Rating', defaultDirection: 'desc'),
        LibrarySort(key: 'CriticRating', descKey: 'CriticRating:desc', title: 'Critics Rating', defaultDirection: 'desc'),
        LibrarySort(key: 'DateCreated', descKey: 'DateCreated:desc', title: 'Date Added', defaultDirection: 'desc'),
        LibrarySort(key: 'DatePlayed', descKey: 'DatePlayed:desc', title: 'Date Played', defaultDirection: 'desc'),
        LibrarySort(key: 'OfficialRating', title: 'Parental Rating', defaultDirection: 'asc'),
        LibrarySort(key: 'PlayCount', descKey: 'PlayCount:desc', title: 'Play Count', defaultDirection: 'desc'),
        LibrarySort(key: 'PremiereDate', descKey: 'PremiereDate:desc', title: 'Release Date', defaultDirection: 'desc'),
        LibrarySort(key: 'Runtime', descKey: 'Runtime:desc', title: 'Runtime', defaultDirection: 'desc'),
      ];
    }
    // Shows: match Jellyfin web UI sort list and order.
    if (t == 'show') {
      return [
        LibrarySort(key: 'SortName', title: 'Name', defaultDirection: 'asc'),
        LibrarySort(key: 'Random', title: 'Random', defaultDirection: 'asc'),
        LibrarySort(key: 'CommunityRating', descKey: 'CommunityRating:desc', title: 'Community Rating', defaultDirection: 'desc'),
        LibrarySort(key: 'DateCreated', descKey: 'DateCreated:desc', title: 'Date Show Added', defaultDirection: 'desc'),
        LibrarySort(key: 'DateLastContentAdded', descKey: 'DateLastContentAdded:desc', title: 'Date Episode Added', defaultDirection: 'desc'),
        LibrarySort(key: 'DatePlayed', descKey: 'DatePlayed:desc', title: 'Date Played', defaultDirection: 'desc'),
        LibrarySort(key: 'OfficialRating', title: 'Parental Rating', defaultDirection: 'asc'),
        LibrarySort(key: 'PremiereDate', descKey: 'PremiereDate:desc', title: 'Release Date', defaultDirection: 'desc'),
      ];
    }
    // Other library types (e.g. collection): use movie list as fallback.
    return getLibrarySorts(sectionId, libraryType: 'movie');
  }

  /// Jellyfin GET /Movies/Recommendations returns categories (Because you watched X, Because you liked X, etc.).
  Future<List<Hub>> getMovieRecommendations(String sectionId, {int categoryLimit = 10, int itemLimit = 12}) async {
    if (_offlineMode) return [];
    try {
      final response = await _dio.get<List<dynamic>>(
        '/Movies/Recommendations',
        queryParameters: {
          'UserId': config.userId,
          'ParentId': sectionId,
          'CategoryLimit': categoryLimit,
          'ItemLimit': itemLimit,
          'Fields': _listFields,
        },
      );
      final list = response.data;
      if (list == null || list.isEmpty) return [];
      final hubs = <Hub>[];
      for (var i = 0; i < list.length; i++) {
        final cat = list[i] as Map<String, dynamic>?;
        if (cat == null) continue;
        final itemsJson = cat['Items'] as List?;
        if (itemsJson == null || itemsJson.isEmpty) continue;
        final type = cat['RecommendationType']?.toString() ?? '';
        final baseline = cat['BaselineItemName']?.toString() ?? '';
        final title = _recommendationCategoryTitle(type, baseline);
        final items = itemsJson
            .map((e) => _itemToMetadata(e as Map<String, dynamic>))
            .where((m) => ['movie', 'show', 'episode', 'collection'].contains(m.type))
            .toList();
        if (items.isEmpty) continue;
        hubs.add(Hub(
          hubKey: 'movie_rec_${sectionId}_${i}_${cat['CategoryId']}',
          title: title,
          type: 'movie',
          hubIdentifier: 'recommendation_$type',
          size: items.length,
          more: false,
          items: items,
          serverId: serverId,
          serverName: serverName,
        ));
      }
      return hubs;
    } catch (e) {
      appLogger.d('Jellyfin getMovieRecommendations(sectionId=$sectionId) failed: $e');
      return [];
    }
  }

  static String _recommendationCategoryTitle(String recommendationType, String baselineItemName) {
    final name = baselineItemName.trim();
    final lower = recommendationType.toLowerCase();
    // Jellyfin RecommendationType: string (e.g. "SimilarToRecentlyPlayed") or number (0-3)
    if (lower.contains('similartorecentlyplayed') || lower == '0') {
      return name.isEmpty ? 'Because you watched' : 'Because you watched $name';
    }
    if (lower.contains('similartoliked') || lower == '1') {
      return name.isEmpty ? 'Because you liked' : 'Because you liked $name';
    }
    if (lower.contains('hasdirector') || lower == '2') {
      return name.isEmpty ? 'From director' : 'From director $name';
    }
    if (lower.contains('hasactor') || lower == '3') {
      return name.isEmpty ? 'With actor' : 'With actor $name';
    }
    return name.isEmpty ? 'Recommended' : 'More like $name';
  }

  Future<List<Hub>> getLibraryHubs(String sectionId, {int limit = 10}) async {
    if (_offlineMode) return [];
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/Users/${config.userId}/Items',
        queryParameters: {
          'ParentId': sectionId,
          'Recursive': true,
          'SortBy': 'DateCreated',
          'SortOrder': 'Descending',
          'Limit': limit,
          'Fields': _listFields,
        },
      );
      final list = response.data?['Items'] as List? ?? [];
      final total = _toInt(response.data?['TotalRecordCount']);
      var items = list.map((e) => _itemToMetadata(e as Map<String, dynamic>)).toList();
      // Exclude folders/non-playable items (e.g. library root "movies" that goes nowhere)
      items = items.where((m) => ['movie', 'show', 'episode', 'collection'].contains(m.type)).toList();
      if (items.isEmpty) {
        appLogger.i('Jellyfin getLibraryHubs(sectionId=$sectionId): 0 items (TotalRecordCount=$total)');
        return [];
      }
      return [
        Hub(
          hubKey: 'recently_added_$sectionId',
          title: 'Recently Added',
          type: 'mixed',
          hubIdentifier: 'recently_added',
          size: items.length,
          more: (_toInt(response.data?['TotalRecordCount']) ?? 0) > items.length,
          items: items,
          serverId: serverId,
          serverName: serverName,
        ),
      ];
    } catch (e) {
      appLogger.d('Jellyfin getLibraryHubs(sectionId=$sectionId) failed: $e');
      return [];
    }
  }

  Future<List<Hub>> getGlobalHubs({int limit = 10}) async {
    if (_offlineMode) return [];
    final perHub = limit > 0 ? limit : 12;

    // Run all three hub requests in parallel. Try both common NextUp paths.
    Future<Map<String, dynamic>?> nextUp() async {
      try {
        final r = await _dio.get<Map<String, dynamic>>(
          '/Shows/NextUp',
          queryParameters: {'UserId': config.userId, 'Limit': perHub, 'Fields': _listFields},
        );
        if (r.data != null && (r.data!['Items'] as List?)?.isNotEmpty == true) return r.data;
      } catch (e) {
        appLogger.d('Jellyfin getGlobalHubs Next Up failed: $e');
      }
      try {
        final r = await _dio.get<Map<String, dynamic>>(
          '/Users/${config.userId}/Shows/NextUp',
          queryParameters: {'Limit': perHub, 'Fields': _listFields},
        );
        if (r.data != null && (r.data!['Items'] as List?)?.isNotEmpty == true) return r.data;
      } catch (e) {
        appLogger.d('Jellyfin getGlobalHubs NextUp fallback failed: $e');
      }
      return null;
    }

    Future<Map<String, dynamic>?> movies() async {
      try {
        final r = await _dio.get<Map<String, dynamic>>(
          '/Users/${config.userId}/Items',
          queryParameters: {
            'IncludeItemTypes': 'Movie',
            'SortBy': 'DateCreated',
            'SortOrder': 'Descending',
            'Limit': perHub,
            'Recursive': true,
            'Fields': _listFields,
          },
        );
        return r.data;
      } catch (e) {
        appLogger.d('Jellyfin getGlobalHubs Recently Added Movies failed: $e');
        return null;
      }
    }

    Future<Map<String, dynamic>?> shows() async {
      try {
        final r = await _dio.get<Map<String, dynamic>>(
          '/Users/${config.userId}/Items',
          queryParameters: {
            'IncludeItemTypes': 'Series',
            'SortBy': 'DateCreated',
            'SortOrder': 'Descending',
            'Limit': perHub,
            'Recursive': true,
            'Fields': _listFields,
          },
        );
        return r.data;
      } catch (e) {
        appLogger.d('Jellyfin getGlobalHubs Recently Added Shows failed: $e');
        return null;
      }
    }

    final results = await Future.wait([nextUp(), movies(), shows()]);
    final hubs = <Hub>[];

    final nextUpData = results[0];
    if (nextUpData != null) {
      final items = (nextUpData['Items'] as List?) ?? [];
      if (items.isNotEmpty) {
        hubs.add(Hub(
          hubKey: 'next_up',
          title: 'Next Up',
          type: 'show',
          hubIdentifier: 'nextup',
          size: items.length,
          more: (_toInt(nextUpData['TotalRecordCount']) ?? 0) > items.length,
          items: items.map((e) => _itemToMetadata(e as Map<String, dynamic>)).toList(),
          serverId: serverId,
          serverName: serverName,
        ));
      }
    }

    final moviesData = results[1];
    if (moviesData != null) {
      final list = (moviesData['Items'] as List?) ?? [];
      if (list.isNotEmpty) {
        hubs.add(Hub(
          hubKey: 'recently_added_movies',
          title: 'Recently Added Movies',
          type: 'movie',
          hubIdentifier: 'recently_added_movies',
          size: list.length,
          more: (_toInt(moviesData['TotalRecordCount']) ?? 0) > list.length,
          items: list.map((e) => _itemToMetadata(e as Map<String, dynamic>)).toList(),
          serverId: serverId,
          serverName: serverName,
        ));
      }
    }

    final showsData = results[2];
    if (showsData != null) {
      final list = (showsData['Items'] as List?) ?? [];
      if (list.isNotEmpty) {
        hubs.add(Hub(
          hubKey: 'recently_added_shows',
          title: 'Recently Added Shows',
          type: 'show',
          hubIdentifier: 'recently_added_shows',
          size: list.length,
          more: (_toInt(showsData['TotalRecordCount']) ?? 0) > list.length,
          items: list.map((e) => _itemToMetadata(e as Map<String, dynamic>)).toList(),
          serverId: serverId,
          serverName: serverName,
        ));
      }
    }

    appLogger.d('Jellyfin getGlobalHubs: ${hubs.length} hubs');
    return hubs;
  }

  Future<List<MediaMetadata>> getHubContent(String hubKey, {String? hubType}) async {
    if (_offlineMode) return [];
    const expandedLimit = 100;
    try {
      if (hubKey == 'next_up') {
        final response = await _dio.get<Map<String, dynamic>>(
          '/Shows/NextUp',
          queryParameters: {'UserId': config.userId, 'Limit': expandedLimit, 'Fields': _listFields},
        );
        final list = response.data?['Items'] as List? ?? [];
        return list.map((e) => _itemToMetadata(e as Map<String, dynamic>)).toList();
      }

      if (hubKey == 'recently_added_movies') {
        final response = await _dio.get<Map<String, dynamic>>(
          '/Users/${config.userId}/Items',
          queryParameters: {
            'IncludeItemTypes': 'Movie',
            'SortBy': 'DateCreated',
            'SortOrder': 'Descending',
            'Limit': expandedLimit,
            'Recursive': true,
            'Fields': _listFields,
          },
        );
        final list = response.data?['Items'] as List? ?? [];
        return list.map((e) => _itemToMetadata(e as Map<String, dynamic>)).toList();
      }

      if (hubKey == 'recently_added_shows') {
        final response = await _dio.get<Map<String, dynamic>>(
          '/Users/${config.userId}/Items',
          queryParameters: {
            'IncludeItemTypes': 'Series',
            'SortBy': 'DateCreated',
            'SortOrder': 'Descending',
            'Limit': expandedLimit,
            'Recursive': true,
            'Fields': _listFields,
          },
        );
        final list = response.data?['Items'] as List? ?? [];
        return list.map((e) => _itemToMetadata(e as Map<String, dynamic>)).toList();
      }

      if (hubKey == 'continue_watching') {
        final response = await _dio.get<Map<String, dynamic>>(
          '/Users/${config.userId}/Items/Resume',
          queryParameters: {'Limit': expandedLimit, 'Fields': _listFields},
        );
        final list = response.data?['Items'] as List? ?? [];
        return list.map((e) => _itemToMetadata(e as Map<String, dynamic>)).toList();
      }

      // recently_added_{sectionId} — library-scoped recently added
      final recentlyAddedMatch = RegExp(r'^recently_added_(.+)$').firstMatch(hubKey);
      if (recentlyAddedMatch != null) {
        final sectionId = recentlyAddedMatch.group(1)!;
        final response = await _dio.get<Map<String, dynamic>>(
          '/Users/${config.userId}/Items',
          queryParameters: {
            'ParentId': sectionId,
            'Recursive': true,
            'SortBy': 'DateCreated',
            'SortOrder': 'Descending',
            'Limit': expandedLimit,
            'Fields': _listFields,
          },
        );
        final list = response.data?['Items'] as List? ?? [];
        var items = list.map((e) => _itemToMetadata(e as Map<String, dynamic>)).toList();
        items = items.where((m) => ['movie', 'show', 'episode', 'collection'].contains(m.type)).toList();
        return items;
      }

      // library_continue_watching_{libraryId}
      final libResumeMatch = RegExp(r'^library_continue_watching_(.+)$').firstMatch(hubKey);
      if (libResumeMatch != null) {
        final libraryId = libResumeMatch.group(1)!;
        final response = await _dio.get<Map<String, dynamic>>(
          '/Users/${config.userId}/Items/Resume',
          queryParameters: {'ParentId': libraryId, 'Limit': expandedLimit, 'Fields': _listFields},
        );
        final list = response.data?['Items'] as List? ?? [];
        return list.map((e) => _itemToMetadata(e as Map<String, dynamic>)).toList();
      }

      // genre_{sectionId}_{genreKey}
      final genreMatch = RegExp(r'^genre_([^_]+)_(.+)$').firstMatch(hubKey);
      if (genreMatch != null) {
        final sectionId = genreMatch.group(1)!;
        final genreKey = genreMatch.group(2)!;
        final response = await _dio.get<Map<String, dynamic>>(
          '/Users/${config.userId}/Items',
          queryParameters: {
            'ParentId': sectionId,
            'Genres': genreKey,
            'Recursive': true,
            'SortBy': 'SortName',
            'SortOrder': 'Ascending',
            'Limit': expandedLimit,
            'Fields': _listFields,
          },
        );
        final list = response.data?['Items'] as List? ?? [];
        return list.map((e) => _itemToMetadata(e as Map<String, dynamic>)).toList();
      }

      appLogger.d('getHubContent: unrecognized hub key pattern: $hubKey');
      return [];
    } catch (e) {
      appLogger.e('getHubContent failed for hubKey=$hubKey', error: e);
      return [];
    }
  }

  Future<List<MediaMetadata>> getPlaylist(String playlistId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/Playlists/$playlistId/Items',
        queryParameters: {
          'UserId': config.userId,
          'Fields': _listFields,
        },
      );
      final list = response.data?['Items'] as List?;
      if (list == null) return [];
      return list.map((e) => _itemToMetadata(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Playlist>> getPlaylists({String playlistType = 'video', bool? smart}) async {
    if (_offlineMode) return [];
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/Users/${config.userId}/Items',
        queryParameters: {'IncludeItemTypes': 'Playlist', 'Recursive': true},
      );
      final list = response.data?['Items'] as List?;
      if (list == null) return [];
      return list.map((e) {
        final m = e as Map<String, dynamic>;
        final id = m['Id']?.toString() ?? '';
        return Playlist(
          itemId: id,
          key: id,
          type: 'playlist',
          title: m['Name'] as String? ?? 'Playlist',
          summary: m['Overview'] as String?,
          smart: false,
          playlistType: playlistType,
          leafCount: _toInt(m['ChildCount']),
          thumb: id.isNotEmpty ? id : null,
          serverId: serverId,
          serverName: serverName,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Playlist?> getPlaylistMetadata(String playlistId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/Playlists/$playlistId');
      final m = response.data;
      if (m == null) return null;
      final id = m['Id']?.toString() ?? playlistId;
      return Playlist(
        itemId: id,
        key: id,
        type: 'playlist',
        title: m['Name'] as String? ?? 'Playlist',
        summary: m['Overview'] as String?,
        smart: false,
        playlistType: 'video',
        leafCount: _toInt(m['ChildCount']),
        thumb: id.isNotEmpty ? id : null,
        serverId: serverId,
        serverName: serverName,
      );
    } catch (_) {
      return null;
    }
  }

  Future<Playlist?> createPlaylist({required String title, String? uri, int? playQueueId}) async {
    try {
      final data = <String, dynamic>{'Name': title};
      if (uri != null && uri.isNotEmpty) {
        data['Ids'] = [uri];
      }
      final response = await _dio.post<Map<String, dynamic>>('/Playlists', data: data);
      final m = response.data;
      if (m == null) return null;
      final id = m['Id']?.toString() ?? '';
      return Playlist(
        itemId: id,
        key: id,
        type: 'playlist',
        title: title,
        smart: false,
        playlistType: 'video',
        thumb: id.isNotEmpty ? id : null,
        serverId: serverId,
        serverName: serverName,
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> deletePlaylist(String playlistId) async {
    try {
      await _dio.delete('/Playlists/$playlistId');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> addToPlaylist({required String playlistId, required String uri}) async {
    try {
      await _dio.post('/Playlists/$playlistId/Items', queryParameters: {'Ids': uri});
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> removeFromPlaylist({required String playlistId, required String playlistItemId}) async {
    try {
      await _dio.delete('/Playlists/$playlistId/Items/$playlistItemId');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> clearPlaylist(String playlistId) async {
    try {
      final items = await getPlaylist(playlistId);
      for (final item in items) {
        await removeFromPlaylist(playlistId: playlistId, playlistItemId: item.itemId);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<MediaMetadata>> getLibraryCollections(String sectionId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/Users/${config.userId}/Items',
        queryParameters: {'ParentId': sectionId, 'IncludeItemTypes': 'BoxSet', 'Fields': _collectionListFields},
      );
      final list = response.data?['Items'] as List?;
      if (list == null) return [];
      return list.map((e) => _itemToMetadata(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<MediaMetadata>> getGlobalCollections() async {
    if (_offlineMode) return [];
    try {
      // Fetch all BoxSets (actual collections) directly; do not use ParentId so we get
      // all user-created collections, not children of a view (which may be other views).
      final response = await _dio.get<Map<String, dynamic>>(
        '/Users/${config.userId}/Items',
        queryParameters: {
          'Recursive': true,
          'IncludeItemTypes': 'BoxSet',
          'SortBy': 'SortName',
          'SortOrder': 'Ascending',
          'Fields': _collectionListFields,
        },
      );
      final list = response.data?['Items'] as List?;
      if (list == null) return [];
      return list.map((e) => _itemToMetadata(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<MediaMetadata>> getLibraryFavorites(String sectionId, {int start = 0, int limit = 0}) async {
    if (_offlineMode) return [];
    try {
      final queryParams = <String, dynamic>{
        'ParentId': sectionId,
        'Recursive': true,
        'IncludeItemTypes': 'Movie,Series',
        'IsFavorite': true,
        'Fields': _listFields,
        'SortBy': 'SortName',
        'SortOrder': 'Ascending',
      };
      if (limit > 0) {
        queryParams['StartIndex'] = start;
        queryParams['Limit'] = limit;
      }
      final response = await _dio.get<Map<String, dynamic>>(
        '/Users/${config.userId}/Items',
        queryParameters: queryParams,
      );
      final list = response.data?['Items'] as List?;
      if (list == null) return [];
      return list.map((e) => _itemToMetadata(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<MediaMetadata>> getCollectionItems(String collectionId) async {
    return getChildren(collectionId);
  }

  Future<bool> deleteCollection(String collectionId) async {
    try {
      await _dio.delete('/Items/$collectionId');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> createCollection({
    required String title,
    List<String>? itemIds,
  }) async {
    try {
      final params = <String, dynamic>{'Name': title};
      if (itemIds != null && itemIds.isNotEmpty) {
        params['Ids'] = itemIds;
      }
      final response = await _dio.post<Map<String, dynamic>>('/Collections', queryParameters: params);
      return response.data?['Id']?.toString();
    } catch (e) {
      appLogger.e('Failed to create collection', error: e);
      return null;
    }
  }

  Future<bool> addToCollection({required String collectionId, required List<String> itemIds}) async {
    try {
      await _dio.post('/Collections/$collectionId/Items', queryParameters: {'Ids': itemIds.join(',')});
      return true;
    } catch (e) {
      appLogger.e('Failed to add to collection', error: e);
      return false;
    }
  }

  Future<bool> removeFromCollection({required String collectionId, required String itemId}) async {
    try {
      await _dio.delete('/Collections/$collectionId/Items', queryParameters: {'Ids': itemId});
      return true;
    } catch (e) {
      appLogger.e('Failed to remove from collection', error: e);
      return false;
    }
  }

  Future<List<MediaMetadata>> getLibraryFolders(String sectionId) async {
    return getLibraryContent(sectionId);
  }

  Future<List<MediaMetadata>> getFolderChildren(String folderKey) async {
    return getChildren(folderKey);
  }

  Future<List<Playlist>> getLibraryPlaylists({String playlistType = 'video'}) async {
    return getPlaylists(playlistType: playlistType);
  }

  Future<void> scanLibrary(String sectionId) async {
    if (_offlineMode) return;
    await _dio.post('/Library/Refresh', queryParameters: {
      'ParentId': sectionId,
    });
  }

  Future<void> refreshLibraryMetadata(String sectionId) async {
    if (_offlineMode) return;
    await _dio.post('/Items/$sectionId/Refresh', queryParameters: {
      'MetadataRefreshMode': 'FullRefresh',
      'ImageRefreshMode': 'FullRefresh',
      'ReplaceAllMetadata': 'true',
      'ReplaceAllImages': 'false',
    });
  }

  Future<int> getLibraryTotalCount(String sectionId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/Users/${config.userId}/Items',
        queryParameters: {'ParentId': sectionId, 'Limit': 1},
      );
      return _toInt(response.data?['TotalRecordCount']) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<int> getLibraryEpisodeCount(String sectionId) async {
    return getLibraryTotalCount(sectionId);
  }

  /// Check if Jellyfin server has Live TV enabled by querying tuner info.
  /// Returns a synthetic LiveTvDvr per server so the provider can track availability.
  Future<List<LiveTvDvr>> getDvrs() async {
    if (_offlineMode) return [];
    try {
      final response = await _dio.get<Map<String, dynamic>>('/LiveTv/Info');
      if (response.statusCode != 200 || response.data == null) return [];
      final services = response.data!['Services'] as List?;
      final enabled = response.data!['IsEnabled'] as bool? ?? (services != null && services.isNotEmpty);
      if (!enabled) return [];
      return [
        LiveTvDvr(
          key: serverId,
          uuid: serverId,
          make: 'Jellyfin',
          model: 'Live TV',
          status: 'connected',
        ),
      ];
    } catch (e) {
      appLogger.d('Jellyfin getDvrs (LiveTv/Info) failed: $e');
      return [];
    }
  }

  Future<bool> hasDvr() async {
    final dvrs = await getDvrs();
    return dvrs.isNotEmpty;
  }

  /// Get Live TV channels from Jellyfin.
  Future<List<LiveTvChannel>> getEpgChannels({String? lineup}) async {
    if (_offlineMode) return [];
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/LiveTv/Channels',
        queryParameters: {
          'UserId': config.userId,
          'AddCurrentProgram': false,
          'EnableUserData': false,
          'SortBy': 'SortName',
          'SortOrder': 'Ascending',
        },
      );
      final list = response.data?['Items'] as List?;
      if (list == null) return [];
      return list.map((item) {
        final m = item as Map<String, dynamic>;
        return LiveTvChannel(
          key: m['Id'] as String? ?? '',
          identifier: m['Id'] as String?,
          callSign: m['Name'] as String?,
          title: m['Name'] as String?,
          thumb: m['Id'] as String?,
          number: m['ChannelNumber'] as String?,
          hd: m['IsHD'] as bool? ?? false,
          serverId: serverId,
          serverName: serverName,
        );
      }).toList();
    } catch (e) {
      appLogger.e('Jellyfin getEpgChannels failed: $e');
      return [];
    }
  }

  /// Get EPG grid (programs) for a time range.
  /// [beginsAt] and [endsAt] are epoch seconds.
  Future<List<LiveTvProgram>> getEpgGrid({int? beginsAt, int? endsAt}) async {
    if (_offlineMode) return [];
    try {
      final params = <String, dynamic>{
        'UserId': config.userId,
        'Fields': 'Overview',
        'EnableImages': true,
        'ImageTypeLimit': 1,
        'EnableUserData': false,
      };
      if (beginsAt != null) {
        params['MinStartDate'] = DateTime.fromMillisecondsSinceEpoch(beginsAt * 1000, isUtc: true).toIso8601String();
      }
      if (endsAt != null) {
        params['MaxEndDate'] = DateTime.fromMillisecondsSinceEpoch(endsAt * 1000, isUtc: true).toIso8601String();
      }

      final response = await _dio.get<Map<String, dynamic>>('/LiveTv/Programs', queryParameters: params);
      final list = response.data?['Items'] as List?;
      if (list == null) return [];
      return list.map((item) => _jellyfinProgramToLiveTvProgram(item as Map<String, dynamic>)).toList();
    } catch (e) {
      appLogger.e('Jellyfin getEpgGrid failed: $e');
      return [];
    }
  }

  /// Map a Jellyfin program BaseItemDto to LiveTvProgram.
  LiveTvProgram _jellyfinProgramToLiveTvProgram(Map<String, dynamic> m) {
    final startStr = m['StartDate'] as String?;
    final endStr = m['EndDate'] as String?;
    final startEpoch = startStr != null ? (DateTime.tryParse(startStr)?.millisecondsSinceEpoch ?? 0) ~/ 1000 : null;
    final endEpoch = endStr != null ? (DateTime.tryParse(endStr)?.millisecondsSinceEpoch ?? 0) ~/ 1000 : null;

    final isSeries = m['IsSeries'] as bool? ?? false;
    final episodeTitle = m['EpisodeTitle'] as String?;
    final seriesName = isSeries ? (m['Name'] as String?) : null;
    final imageTags = m['ImageTags'] as Map<String, dynamic>?;
    final hasPrimaryTag = imageTags?['Primary'] != null;
    final thumbId =
        m['PrimaryImageItemId'] as String? ??
        m['SeriesId'] as String? ??
        m['ChannelId'] as String? ??
        (hasPrimaryTag ? m['Id'] as String? : null);

    return LiveTvProgram(
      key: m['Id'] as String?,
      itemId: m['Id'] as String?,
      guid: m['Id'] as String?,
      title: isSeries ? (episodeTitle ?? m['Name'] as String? ?? 'Unknown Program') : (m['Name'] as String? ?? 'Unknown Program'),
      summary: m['Overview'] as String?,
      type: m['Type'] as String?,
      year: (m['ProductionYear'] as num?)?.toInt(),
      beginsAt: startEpoch,
      endsAt: endEpoch,
      seriesTitle: seriesName,
      seasonTitle: null,
      index: (m['IndexNumber'] as num?)?.toInt(),
      parentIndex: (m['ParentIndexNumber'] as num?)?.toInt(),
      thumb: thumbId,
      art: thumbId,
      channelIdentifier: m['ChannelId'] as String?,
      channelCallSign: m['ChannelName'] as String?,
      live: m['IsLive'] as bool? ?? false,
      premiere: m['IsPremiere'] as bool? ?? false,
    );
  }

  /// Get program hubs for the "Programs" tab: On Now + category rows.
  Future<List<LiveTvHubResult>> getLiveTvHubs({int count = 24}) async {
    if (_offlineMode) return [];
    try {
      final results = await Future.wait([
        _fetchRecommendedPrograms(count),
        _fetchProgramsByCategory(count, hubKey: 'shows', isSeries: true, isMovie: false, isSports: false, isKids: false, isNews: false),
        _fetchProgramsByCategory(count, hubKey: 'movies', isMovie: true),
        _fetchProgramsByCategory(count, hubKey: 'sports', isSports: true),
        _fetchProgramsByCategory(count, hubKey: 'kids', isKids: true),
        _fetchProgramsByCategory(count, hubKey: 'news', isNews: true),
      ]);

      return results.whereType<LiveTvHubResult>().toList();
    } catch (e) {
      appLogger.d('Jellyfin getLiveTvHubs failed: $e');
      return [];
    }
  }

  Future<LiveTvHubResult?> _fetchRecommendedPrograms(int count) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/LiveTv/Programs/Recommended',
        queryParameters: {
          'UserId': config.userId,
          'Limit': count,
          'IsAiring': true,
          'Fields': 'Overview',
          'ImageTypeLimit': 1,
          'EnableImages': true,
          'EnableImageTypes': 'Primary,Thumb,Backdrop',
        },
      );
      final entries = _programListToHubEntries(response.data?['Items'] as List?);
      if (entries.isEmpty) return null;
      return LiveTvHubResult(title: 'on_now', hubKey: 'on_now', entries: entries);
    } catch (e) {
      appLogger.d('Failed to fetch recommended programs: $e');
      return null;
    }
  }

  Future<LiveTvHubResult?> _fetchProgramsByCategory(
    int count, {
    required String hubKey,
    bool? isSeries,
    bool? isMovie,
    bool? isSports,
    bool? isKids,
    bool? isNews,
  }) async {
    try {
      final params = <String, dynamic>{
        'UserId': config.userId,
        'Limit': count,
        'HasAired': false,
        'Fields': 'ChannelInfo,PrimaryImageAspectRatio',
        'EnableTotalRecordCount': false,
        'EnableImageTypes': 'Primary,Thumb',
        'ImageTypeLimit': 1,
        'EnableImages': true,
      };
      if (isSeries != null) params['IsSeries'] = isSeries;
      if (isMovie != null) params['IsMovie'] = isMovie;
      if (isSports != null) params['IsSports'] = isSports;
      if (isKids != null) params['IsKids'] = isKids;
      if (isNews != null) params['IsNews'] = isNews;

      final response = await _dio.get<Map<String, dynamic>>('/LiveTv/Programs', queryParameters: params);
      final entries = _programListToHubEntries(response.data?['Items'] as List?);
      if (entries.isEmpty) return null;
      return LiveTvHubResult(title: hubKey, hubKey: hubKey, entries: entries);
    } catch (e) {
      appLogger.d('Failed to fetch $hubKey programs: $e');
      return null;
    }
  }

  List<LiveTvHubEntry> _programListToHubEntries(List? list) {
    if (list == null || list.isEmpty) return [];
    final entries = <LiveTvHubEntry>[];
    for (final item in list) {
      final m = item as Map<String, dynamic>;
      final program = _jellyfinProgramToLiveTvProgram(m);
      final imageTags = m['ImageTags'] as Map<String, dynamic>?;
      final hasPrimaryTag = imageTags?['Primary'] != null;
      final thumbId =
          m['PrimaryImageItemId'] as String? ??
          m['SeriesId'] as String? ??
          m['ChannelId'] as String? ??
          (hasPrimaryTag ? m['Id'] as String? : null);
      final metadata = MediaMetadata(
        itemId: m['Id'] as String? ?? '',
        key: m['Id'] as String? ?? '',
        type: (m['IsSeries'] == true) ? 'show' : (m['IsMovie'] == true ? 'movie' : 'clip'),
        title: m['Name'] as String? ?? '',
        summary: m['Overview'] as String?,
        thumb: thumbId,
        art: thumbId,
        serverId: serverId,
        seriesImageId: m['SeriesId'] as String?,
      );
      entries.add(LiveTvHubEntry(metadata: metadata, program: program));
    }
    return entries;
  }

  /// Reload the guide data. For Jellyfin, simply returns true to trigger a UI refresh.
  Future<bool> reloadGuide(String dvrKey) async {
    return true;
  }

  Future<List<MediaMetadata>> getLiveTvSessions() async {
    return [];
  }

  /// Get series timers (recurring recording rules).
  Future<List<LiveTvSubscription>> getSeriesTimers() async {
    if (_offlineMode) return [];
    try {
      final response = await _dio.get<Map<String, dynamic>>('/LiveTv/SeriesTimers');
      final list = response.data?['Items'] as List?;
      if (list == null) return [];
      return list.map((item) {
        return LiveTvSubscription.fromJellyfinJson(item as Map<String, dynamic>, serverId: serverId);
      }).toList();
    } catch (e) {
      appLogger.d('Failed to get series timers', error: e);
      return [];
    }
  }

  /// Delete a series timer.
  Future<bool> deleteSeriesTimer(String seriesTimerId) async {
    if (_offlineMode) return false;
    try {
      final response = await _dio.delete('/LiveTv/SeriesTimers/$seriesTimerId');
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      appLogger.d('Failed to delete series timer', error: e);
      return false;
    }
  }

  /// Update a series timer's settings.
  Future<bool> updateSeriesTimer(LiveTvSubscription seriesTimer) async {
    if (_offlineMode) return false;
    try {
      final response = await _dio.post(
        '/LiveTv/SeriesTimers/${seriesTimer.key}',
        data: seriesTimer.toUpdateJson(),
      );
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      appLogger.d('Failed to update series timer', error: e);
      return false;
    }
  }

  /// Get scheduled recordings (individual timers).
  Future<List<ScheduledRecording>> getTimers() async {
    if (_offlineMode) return [];
    try {
      final response = await _dio.get<Map<String, dynamic>>('/LiveTv/Timers');
      final list = response.data?['Items'] as List?;
      if (list == null) return [];
      final timers = list.map((item) {
        return ScheduledRecording.fromJellyfinJson(item as Map<String, dynamic>);
      }).toList();
      timers.sort((a, b) => (a.startTime ?? DateTime(0)).compareTo(b.startTime ?? DateTime(0)));
      return timers;
    } catch (e) {
      appLogger.d('Failed to get timers', error: e);
      return [];
    }
  }

  /// Cancel an individual timer.
  Future<bool> cancelTimer(String timerId) async {
    if (_offlineMode) return false;
    try {
      final response = await _dio.delete('/LiveTv/Timers/$timerId');
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      appLogger.d('Failed to cancel timer', error: e);
      return false;
    }
  }

  /// Get default timer settings pre-populated for a given program.
  /// Used as the body for [createTimer] or [createSeriesTimer].
  Future<Map<String, dynamic>?> getTimerDefaults(String programId) async {
    if (_offlineMode) return null;
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/LiveTv/Timers/Defaults',
        queryParameters: {'programId': programId},
      );
      return response.data;
    } catch (e) {
      appLogger.e('Failed to get timer defaults for program $programId', error: e);
      return null;
    }
  }

  /// Create a single recording timer from defaults obtained via [getTimerDefaults].
  Future<bool> createTimer(Map<String, dynamic> timerInfo) async {
    if (_offlineMode) return false;
    try {
      final response = await _dio.post('/LiveTv/Timers', data: timerInfo);
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      appLogger.e('Failed to create timer', error: e);
      return false;
    }
  }

  /// Create a series timer from defaults obtained via [getTimerDefaults].
  Future<bool> createSeriesTimer(Map<String, dynamic> timerInfo) async {
    if (_offlineMode) return false;
    try {
      final response = await _dio.post('/LiveTv/SeriesTimers', data: timerInfo);
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      appLogger.e('Failed to create series timer', error: e);
      return false;
    }
  }

  /// Fetch full program details including recording state (TimerId, SeriesTimerId).
  Future<Map<String, dynamic>?> getProgramDetails(String programId) async {
    if (_offlineMode) return null;
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/LiveTv/Programs/$programId',
        queryParameters: {'UserId': config.userId},
      );
      return response.data;
    } catch (e) {
      appLogger.e('Failed to get program details for $programId', error: e);
      return null;
    }
  }

  /// Get completed recordings.
  Future<List<LiveTvRecording>> getRecordings() async {
    if (_offlineMode) return [];
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/LiveTv/Recordings',
        queryParameters: {'UserId': config.userId},
      );
      final list = response.data?['Items'] as List?;
      if (list == null) return [];
      return list.map((item) {
        return LiveTvRecording.fromJellyfinJson(item as Map<String, dynamic>, serverId: serverId);
      }).toList();
    } catch (e) {
      appLogger.d('Failed to get recordings', error: e);
      return [];
    }
  }

  /// Get completed recordings as [MediaMetadata] for hub/library display.
  /// Recordings often lack their own Primary image, so we replicate the
  /// fallback chain from jellyfin-web's cardBuilder to find the best image.
  Future<List<MediaMetadata>> getRecordingsAsMetadata() async {
    if (_offlineMode) return [];
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/LiveTv/Recordings',
        queryParameters: {
          'UserId': config.userId,
          'SortBy': 'DateCreated',
          'SortOrder': 'Descending',
          'EnableImages': true,
          'ImageTypeLimit': 1,
          'EnableImageTypes': 'Primary,Backdrop,Thumb',
          'Fields': 'Overview,ChannelInfo,MediaSources,PrimaryImageAspectRatio',
        },
      );
      final list = response.data?['Items'] as List?;
      if (list == null) return [];
      return list.map((raw) {
        final item = raw as Map<String, dynamic>;
        return _recordingToMetadata(item);
      }).toList();
    } catch (e) {
      appLogger.d('Failed to get recordings as metadata', error: e);
      return [];
    }
  }

  /// Converts a Jellyfin recording item to [MediaMetadata] with image
  /// fallback matching jellyfin-web's cardBuilder `getCardImageUrl`.
  /// Web does `item = item.ProgramInfo || item` — we merge ProgramInfo
  /// image fields when the recording itself lacks images.
  MediaMetadata _recordingToMetadata(Map<String, dynamic> item) {
    final id = item['Id']?.toString() ?? '';
    final name = item['Name'] as String? ?? 'Unknown';
    final userData = item['UserData'] as Map<String, dynamic>? ?? {};

    final isSeries = item['IsSeries'] == true
        || item['EpisodeTitle'] != null
        || item['SeriesId'] != null;
    final isMovie = !isSeries && item['IsMovie'] == true;
    final type = isSeries ? 'episode' : (isMovie ? 'movie' : 'movie');

    // Jellyfin-web: item = item.ProgramInfo || item
    // Use ProgramInfo for image fields when available (richer metadata).
    final programInfo = item['ProgramInfo'] as Map<String, dynamic>?;
    final imgSource = programInfo ?? item;
    final imageTags = imgSource['ImageTags'] as Map<String, dynamic>?;

    // Image fallback chain — mirrors jellyfin-web cardBuilder getCardImageUrl
    String? thumbId;
    final imgId = imgSource['Id']?.toString() ?? id;

    if (imageTags?['Primary'] != null) {
      thumbId = imgId;
    } else if (imgSource['SeriesPrimaryImageTag'] != null && imgSource['SeriesId'] != null) {
      thumbId = imgSource['SeriesId'] as String;
    } else if (imgSource['PrimaryImageTag'] != null && imgSource['PrimaryImageItemId'] != null) {
      thumbId = imgSource['PrimaryImageItemId'] as String;
    } else if (imgSource['ParentPrimaryImageTag'] != null && imgSource['ParentPrimaryImageItemId'] != null) {
      thumbId = imgSource['ParentPrimaryImageItemId'] as String;
    } else {
      final backdrop = imgSource['BackdropImageTags'] as List?;
      final parentBackdrop = imgSource['ParentBackdropImageTags'] as List?;
      if (backdrop != null && backdrop.isNotEmpty) {
        thumbId = '$baseUrl/Items/$imgId/Images/Backdrop?quality=90'
            '${token != null && token!.isNotEmpty ? '&ApiKey=$token' : ''}';
      } else if (imageTags?['Thumb'] != null) {
        thumbId = '$baseUrl/Items/$imgId/Images/Thumb?quality=90'
            '${token != null && token!.isNotEmpty ? '&ApiKey=$token' : ''}';
      } else if (imgSource['SeriesThumbImageTag'] != null && imgSource['SeriesId'] != null) {
        final seriesId = imgSource['SeriesId'] as String;
        thumbId = '$baseUrl/Items/$seriesId/Images/Thumb?quality=90'
            '${token != null && token!.isNotEmpty ? '&ApiKey=$token' : ''}';
      } else if (imgSource['ParentThumbImageTag'] != null && imgSource['ParentThumbItemId'] != null) {
        final parentId = imgSource['ParentThumbItemId'] as String;
        thumbId = '$baseUrl/Items/$parentId/Images/Thumb?quality=90'
            '${token != null && token!.isNotEmpty ? '&ApiKey=$token' : ''}';
      } else if (parentBackdrop != null && parentBackdrop.isNotEmpty && imgSource['ParentBackdropItemId'] != null) {
        final parentId = imgSource['ParentBackdropItemId'] as String;
        thumbId = '$baseUrl/Items/$parentId/Images/Backdrop?quality=90'
            '${token != null && token!.isNotEmpty ? '&ApiKey=$token' : ''}';
      } else if (item['SeriesId'] != null) {
        thumbId = item['SeriesId'] as String;
      }
    }

    final hasBackdrop = (imgSource['BackdropImageTags'] as List?)?.isNotEmpty == true
        || (item['BackdropImageTags'] as List?)?.isNotEmpty == true;

    return MediaMetadata(
      itemId: id,
      key: id,
      guid: id,
      studio: _studioName(item['Studios']),
      type: type,
      title: name,
      titleSort: item['SortName'] as String?,
      contentRating: item['OfficialRating'] as String?,
      summary: item['Overview'] as String?,
      year: _toInt(item['ProductionYear']),
      originallyAvailableAt: item['PremiereDate'] as String?,
      thumb: thumbId,
      art: hasBackdrop ? id : null,
      duration: _ticksToMs(_toInt(item['RunTimeTicks'])),
      addedAt: item['DateCreated'] != null ? _parseDateToEpochSeconds(item['DateCreated']) : null,
      seriesTitle: item['SeriesName'] as String?,
      seriesImageId: isSeries && (imgSource['SeriesPrimaryImageTag'] != null || item['SeriesPrimaryImageTag'] != null)
          ? (item['SeriesId']?.toString())
          : null,
      seriesId: item['SeriesId']?.toString(),
      parentIndex: _toInt(item['ParentIndexNumber']),
      index: _toInt(item['IndexNumber']),
      resumePositionMs: _positionTicksToMs(_toInt(userData['PlaybackPositionTicks'])),
      playCount: _toInt(userData['PlayCount']),
      serverId: serverId,
      serverName: serverName,
    );
  }

  Future<String> buildMetadataUri(String itemId) async => itemId;

  Future<void> updateLiveTimeline({
    required String itemId,
    required String sessionPath,
    required String sessionIdentifier,
    required String state,
    required int time,
    required int duration,
    required int playbackTime,
  }) async {
    if (_offlineMode) return;
    await _dio.post(
      '/Sessions/Playing/Progress',
      data: {
        'ItemId': itemId,
        'MediaSourceId': sessionIdentifier,
        'LiveStreamId': sessionIdentifier,
        'PositionTicks': time * 10000,
        'IsPaused': state == 'paused',
        'CanSeek': false,
        'PlayMethod': 'Transcode',
        if (duration > 0) 'PlaybackDurationTicks': duration * 10000,
      },
    );
  }


  /// Tune a Live TV channel by getting a playback stream URL via PlaybackInfo.
  /// Follows the official jellyfin-web flow: PlaybackInfo -> LiveStreams/Open
  /// (if needed) -> build stream URL from MediaSource capabilities.
  Future<({MediaMetadata metadata, String streamPath, String sessionIdentifier, String sessionPath})?> tuneChannel(
    String dvrKey,
    String channelKey,
  ) async {
    if (_offlineMode) return null;
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/Items/$channelKey/PlaybackInfo',
        data: {
          'UserId': config.userId,
          'EnableDirectPlay': true,
          'EnableDirectStream': true,
          'EnableTranscoding': true,
          'AutoOpenLiveStream': true,
          'AllowVideoStreamCopy': true,
          'AllowAudioStreamCopy': true,
        },
      );
      if (response.statusCode != 200 || response.data == null) return null;
      final data = response.data!;

      final mediaSources = data['MediaSources'] as List?;
      if (mediaSources == null || mediaSources.isEmpty) return null;
      var source = mediaSources[0] as Map<String, dynamic>;

      appLogger.d('tuneChannel PlaybackInfo source: '
          'TranscodingUrl=${source['TranscodingUrl']}, '
          'SupportsDirectStream=${source['SupportsDirectStream']}, '
          'SupportsTranscoding=${source['SupportsTranscoding']}, '
          'RequiresOpening=${source['RequiresOpening']}, '
          'LiveStreamId=${source['LiveStreamId']}, '
          'OpenToken=${source['OpenToken']}, '
          'Container=${source['Container']}, '
          'Id=${source['Id']}');

      final requiresOpening = source['RequiresOpening'] as bool? ?? false;
      final existingLiveStreamId = source['LiveStreamId'] as String?;
      if (requiresOpening && existingLiveStreamId == null) {
        final openToken = source['OpenToken'] as String?;
        final playSessionId = data['PlaySessionId'] as String?;
        appLogger.d('tuneChannel: RequiresOpening=true, calling LiveStreams/Open');
        final openResponse = await _dio.post<Map<String, dynamic>>(
          '/LiveStreams/Open',
          queryParameters: {
            'UserId': config.userId,
            'ItemId': channelKey,
            'PlaySessionId': ?playSessionId,
          },
          data: {
            'OpenToken': ?openToken,
          },
        );
        if (openResponse.statusCode == 200 && openResponse.data != null) {
          final openSource = openResponse.data!['MediaSource'] as Map<String, dynamic>?;
          if (openSource != null) {
            source = openSource;
            appLogger.d('tuneChannel LiveStreams/Open source: '
                'TranscodingUrl=${source['TranscodingUrl']}, '
                'LiveStreamId=${source['LiveStreamId']}, '
                'SupportsDirectStream=${source['SupportsDirectStream']}, '
                'SupportsTranscoding=${source['SupportsTranscoding']}, '
                'Container=${source['Container']}');
          }
        }
      }

      final liveStreamId = source['LiveStreamId'] as String? ?? source['Id'] as String? ?? channelKey;
      final sourceId = source['Id'] as String? ?? liveStreamId;
      final container = (source['Container'] as String?)?.toLowerCase() ?? 'ts';
      final transcodingUrl = source['TranscodingUrl'] as String?;
      final supportsTranscoding = source['SupportsTranscoding'] as bool? ?? false;
      final supportsDirectStream = source['SupportsDirectStream'] as bool? ?? false;

      String streamPath;
      if (supportsTranscoding && transcodingUrl != null && transcodingUrl.isNotEmpty) {
        streamPath = transcodingUrl.startsWith('/') ? transcodingUrl : '/$transcodingUrl';
      } else if (supportsDirectStream) {
        streamPath = '/Videos/$channelKey/stream.$container'
            '?Static=true&mediaSourceId=$sourceId&LiveStreamId=$liveStreamId';
      } else if (transcodingUrl != null && transcodingUrl.isNotEmpty) {
        streamPath = transcodingUrl.startsWith('/') ? transcodingUrl : '/$transcodingUrl';
      } else {
        streamPath = '/Videos/$channelKey/stream.$container'
            '?Static=true&LiveStreamId=$liveStreamId';
      }

      appLogger.d('tuneChannel final streamPath: $streamPath');

      final metadata = MediaMetadata(
        itemId: channelKey,
        key: channelKey,
        type: 'clip',
        title: source['Name'] as String? ?? 'Live TV',
        serverId: serverId,
      );

      return (
        metadata: metadata,
        streamPath: streamPath,
        sessionIdentifier: liveStreamId,
        sessionPath: '/Videos/$channelKey/stream.$container',
      );
    } catch (e) {
      appLogger.e('Jellyfin tuneChannel failed for $channelKey: $e');
      return null;
    }
  }
}
