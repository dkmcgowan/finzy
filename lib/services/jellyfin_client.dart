import 'package:dio/dio.dart';

import '../models/jellyfin_config.dart';
import '../models/livetv_channel.dart';
import '../models/livetv_dvr.dart';
import '../models/livetv_hub_result.dart';
import '../models/livetv_program.dart';
import '../models/livetv_scheduled_recording.dart';
import '../models/livetv_subscription.dart';
import '../models/play_queue_response.dart';
import '../models/plex_file_info.dart';
import '../models/plex_filter.dart';
import '../models/plex_first_character.dart';
import '../models/plex_hub.dart';
import '../models/plex_library.dart';
import '../models/plex_media_info.dart';
import '../models/plex_media_version.dart';
import '../models/plex_metadata.dart';
import '../models/plex_playlist.dart';
import '../models/plex_role.dart';
import '../models/plex_sort.dart';
import '../models/plex_video_playback_data.dart';
import '../utils/app_logger.dart';
import '../utils/watch_state_notifier.dart';
import 'media_server_client.dart';

/// Jellyfin API client implementing [MediaServerClient].
/// Maps Jellyfin REST API to Plex-shaped DTOs for use by the existing UI.
class JellyfinClient implements MediaServerClient {
  /// Minimal Fields for list/grid views (thumbnails, title, watch state, duration).
  /// ItemCounts ensures Series/Season get UnplayedItemCount and episode counts for unwatched badge.
  static const String _listFields = 'Genres,UserData,RunTimeTicks,ItemCounts';

  final JellyfinConfig config;
  late final Dio _dio;
  bool _offlineMode = false;

  @override
  final String serverId;
  @override
  final String? serverName;

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
  }

  @override
  String get baseUrl => config.baseUrl;

  @override
  String? get token => config.token;

  @override
  Map<String, String> get requestHeaders => {'Authorization': config.authorizationHeader};

  @override
  bool get isOfflineMode => _offlineMode;

  @override
  void setOfflineMode(bool offline) {
    _offlineMode = offline;
  }

  @override
  bool get isJellyfin => true;

  /// Jellyfin uses PascalCase; normalize type to Plex lowercase and Series -> show, BoxSet/Boxsets -> collection.
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

  /// Safely parse dynamic (num or String) to double.
  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  /// Map Jellyfin BaseItemDto to PlexMetadata (with serverId/serverName).
  PlexMetadata _itemToMetadata(Map<String, dynamic> item) {
    final id = item['Id']?.toString() ?? '';
    final name = item['Name'] as String? ?? 'Unknown';
    final type = _normalizeType(item['Type'] as String?);
    final userData = item['UserData'] as Map<String, dynamic>? ?? {};
    // Always use item id for thumb/art: Jellyfin serves at /Items/{Id}/Images/Primary (and Backdrop).
    // List responses often omit ImageTags; using id ensures thumbnails load everywhere.
    final hasBackdrop = item['BackdropImageTags'] != null;

    final leafCount = _leafCountForItem(item, type);
    final viewedLeafCount = _viewedLeafCountForItem(item, type, userData);
    // Unwatched badge: use unplayed count directly when API provides it (no need to fake leafCount).
    final unwatchedCount = (type == 'show' || type == 'season') ? _toInt(userData['UnplayedItemCount']) : null;

    return PlexMetadata(
      ratingKey: id,
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
      ratingImage: _jellyfinRating(item) != null ? 'themoviedb://' : null,
      audienceRatingImage: _jellyfinAudienceRating(item) != null ? 'themoviedb://' : null,
      userRating: _toDouble(userData['UserRating']),
      year: _toInt(item['ProductionYear']),
      originallyAvailableAt: item['PremiereDate'] as String?,
      thumb: id.isNotEmpty ? id : null,
      art: hasBackdrop ? id : null,
      duration: _ticksToMs(_toInt(item['RunTimeTicks'])),
      addedAt: item['DateCreated'] != null ? _parseDateToEpochSeconds(item['DateCreated']) : null,
      updatedAt: item['DateLastMediaAdded'] != null ? _parseDateToEpochSeconds(item['DateLastMediaAdded']) : null,
      lastViewedAt: userData['LastPlayedDate'] != null ? _parseDateToEpochSeconds(userData['LastPlayedDate']) : null,
      grandparentTitle: item['SeriesName'] as String?,
      grandparentThumb: item['SeriesId']?.toString(),
      grandparentRatingKey: item['SeriesId']?.toString(),
      parentTitle: item['SeasonName'] as String? ?? (item['ParentId'] != null ? null : null),
      parentRatingKey: item['SeasonId']?.toString(),
      parentIndex: _toInt(item['ParentIndexNumber']),
      index: _toInt(item['IndexNumber']),
      viewOffset: _positionTicksToMs(_toInt(userData['PlaybackPositionTicks'])),
      viewCount: _toInt(userData['PlayCount']),
      leafCount: leafCount,
      viewedLeafCount: viewedLeafCount,
      unwatchedCount: unwatchedCount,
      childCount: _toInt(item['ChildCount']),
      role: _peopleToRoles(item['People']),
      librarySectionID: _toInt(item['ParentId']),
      serverId: serverId,
      serverName: serverName,
      isFavorite: (userData['IsFavorite'] as bool?) == true ? true : null,
    );
  }

  /// Jellyfin rating for star chip: CriticRating, else CommunityRating (e.g. 6.5 from TMDB), else parsed CustomRating.
  static double? _jellyfinRating(Map<String, dynamic> item) {
    final critic = _toDouble(item['CriticRating']);
    if (critic != null) return critic;
    final community = _toDouble(item['CommunityRating']);
    if (community != null) return community;
    return _parseCustomRating(item['CustomRating']);
  }

  /// Jellyfin audience rating (people chip): only when we also have CriticRating, so both chips show.
  static double? _jellyfinAudienceRating(Map<String, dynamic> item) {
    final critic = _toDouble(item['CriticRating']);
    final community = _toDouble(item['CommunityRating']);
    if (critic != null && community != null) return community;
    return null;
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

  /// Map Jellyfin People array to PlexRole list for cast. People: [{Name, Id, Role, Type}, ...].
  static List<PlexRole>? _peopleToRoles(dynamic people) {
    final list = people as List?;
    if (list == null || list.isEmpty) return null;
    final roles = <PlexRole>[];
    for (final p in list) {
      if (p is! Map) continue;
      final name = p['Name'] as String?;
      if (name == null || name.isEmpty) continue;
      final characterRole = p['Role'] as String?;
      final id = p['Id']?.toString();
      roles.add(PlexRole(
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

  /// Watched episode count for shows/seasons when we have total (leafCount). Unwatched = leafCount - viewedLeafCount.
  /// When API omits ChildCount/EpisodeCount, we only set unwatchedCount from UnplayedItemCount; viewedLeafCount stays null.
  int? _viewedLeafCountForItem(Map<String, dynamic> item, String type, Map<String, dynamic> userData) {
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

  /// Map Jellyfin view to PlexLibrary.
  /// Jellyfin CollectionType is "movies" / "tvshows"; Plex uses "movie" / "show" for hub filtering.
  PlexLibrary _viewToLibrary(Map<String, dynamic> view) {
    final id = view['Id']?.toString() ?? '';
    final name = view['Name'] as String? ?? 'Unknown';
    final colType = view['CollectionType'] as String? ?? view['Type'] as String? ?? 'mixed';
    var type = _normalizeType(colType);
    if (type == 'movies') type = 'movie';
    if (type == 'tvshows') type = 'show';

    return PlexLibrary(
      key: id,
      title: name,
      type: type,
      serverId: serverId,
      serverName: serverName,
    );
  }

  @override
  Future<Map<String, dynamic>> getServerIdentity() async {
    final response = await _dio.get<Map<String, dynamic>>('/System/Info');
    return response.data ?? {};
  }

  @override
  Future<String?> getMachineIdentifier() async => serverId;

  /// Synthetic library keys for top-level Collections and Playlists (Jellyfin treats these as libraries).
  static const String syntheticCollectionsKey = 'jellyfin_collections';
  static const String syntheticPlaylistsKey = 'jellyfin_playlists';

  @override
  Future<List<PlexLibrary>> getLibraries() async {
    if (_offlineMode) return [];
    final response = await _dio.get<Map<String, dynamic>>('/Users/${config.userId}/Views');
    final list = response.data?['Items'] as List?;
    if (list == null) return [];
    final all = list
        .map((e) => _viewToLibrary(e as Map<String, dynamic>))
        .toList();

    // Split: content libraries (Movies, Shows, etc.) vs Collections/Playlists (always at bottom).
    bool isCollectionOrPlaylist(PlexLibrary l) {
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

    final result = <PlexLibrary>[...contentLibraries];

    if (hasCollectionLib) {
      result.add(collectionPlaylistFromViews.firstWhere((l) {
        final t = l.type.toLowerCase();
        return t == 'collection' || t == 'boxset' || t == 'boxsets' || l.title == 'Collections';
      }));
    } else {
      final collections = await getGlobalCollections();
      if (collections.isNotEmpty) {
        result.add(PlexLibrary(
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
        result.add(PlexLibrary(
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

  @override
  Future<List<PlexMetadata>> getLibraryContent(
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

    // Parse app-level sort/type/filters into Jellyfin API params (do not pass raw Plex keys)
    final rest = <String, String>{};
    String? sortBy;
    String? sortOrder;
    String? includeItemTypes;
    final genres = <String>[];
    final years = <int>[];

    for (final e in (filters ?? {}).entries) {
      switch (e.key) {
        case 'sort':
          final v = e.value;
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
          includeItemTypes = _plexTypeIdToJellyfin(e.value);
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
        default:
          rest[e.key] = e.value;
      }
    }

    if (sortBy != null) query['SortBy'] = sortBy;
    if (sortOrder != null) query['SortOrder'] = sortOrder;
    if (includeItemTypes != null) query['IncludeItemTypes'] = includeItemTypes;
    if (genres.isNotEmpty) query['Genres'] = genres.join(',');
    if (years.isNotEmpty) query['Years'] = years.join(',');

    appLogger.d('Jellyfin getLibraryContent: ParentId=$sectionId Fields=${query['Fields']} IncludeItemTypes=$includeItemTypes StartIndex=${query['StartIndex']} Limit=${query['Limit']}');

    final response = await _dio.get<Map<String, dynamic>>(
      '/Users/${config.userId}/Items',
      queryParameters: query,
      cancelToken: cancelToken,
    );
    final list = response.data?['Items'] as List? ?? [];
    return list.map((e) => _itemToMetadata(e as Map<String, dynamic>)).toList();
  }

  /// Map Plex type id (1=movie, 2=show, 3=season, 4=episode) to Jellyfin IncludeItemTypes.
  static String? _plexTypeIdToJellyfin(String typeId) {
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

  @override
  Future<PlexMetadata?> getMetadataWithImages(String ratingKey) async {
    if (_offlineMode) return null;
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/Users/${config.userId}/Items/$ratingKey',
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

  @override
  Future<Map<String, dynamic>> getMetadataWithImagesAndOnDeck(String ratingKey) async {
    final metadata = await getMetadataWithImages(ratingKey);
    PlexMetadata? onDeckEpisode;
    final type = metadata?.type.toLowerCase() ?? '';
    if (metadata != null && type == 'show' && !_offlineMode) {
      // Try NextUp API (omit Limit to work around Jellyfin 10.9 bug; take first result for this series)
      try {
        final query = {
          'UserId': config.userId,
          'SeriesId': ratingKey,
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
          onDeckEpisode = _itemToMetadata(first);
        }
      } catch (_) {}
      // Fallback: if NextUp returned nothing, compute first unwatched episode from seasons
      if (onDeckEpisode == null) {
        try {
          onDeckEpisode = await _getFirstUnwatchedEpisodeForShow(ratingKey);
        } catch (_) {}
      }
    }
    return {'metadata': metadata, 'onDeckEpisode': onDeckEpisode};
  }

  /// Returns the first unwatched episode for a series (by season order, then episode index).
  Future<PlexMetadata?> _getFirstUnwatchedEpisodeForShow(String showRatingKey) async {
    final seasons = await getChildren(showRatingKey);
    if (seasons.isEmpty) return null;
    seasons.sort((a, b) => (a.parentIndex ?? 0).compareTo(b.parentIndex ?? 0));
    for (final season in seasons) {
      if (season.type.toLowerCase() != 'season') continue;
      final episodes = await getChildren(season.ratingKey);
      episodes.sort((a, b) => (a.index ?? 0).compareTo(b.index ?? 0));
      for (final ep in episodes) {
        if (ep.type.toLowerCase() != 'episode') continue;
        if (ep.viewCount == null || ep.viewCount! == 0) return ep;
      }
    }
    return null;
  }

  @override
  Future<List<PlexMetadata>> getChildren(String ratingKey) async {
    if (_offlineMode) return [];
    final response = await _dio.get<Map<String, dynamic>>(
      '/Users/${config.userId}/Items',
      queryParameters: {'ParentId': ratingKey, 'Fields': _listFields},
    );
    final list = response.data?['Items'] as List?;
    if (list == null) return [];
    return list.map((e) => _itemToMetadata(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<PlexMetadata>> getExtras(String ratingKey) async {
    if (_offlineMode) return [];
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/Users/${config.userId}/Items/$ratingKey',
        queryParameters: {'Fields': 'RemoteTrailers'},
      );
      final item = response.data;
      final trailers = item?['RemoteTrailers'] as List?;
      if (trailers == null || trailers.isEmpty) return [];
      final list = <PlexMetadata>[];
      for (final t in trailers) {
        if (t is! Map) continue;
        final url = t['Url'] as String?;
        if (url == null || url.isEmpty) continue;
        final name = t['Name'] as String? ?? 'Trailer';
        list.add(PlexMetadata(
          ratingKey: url,
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

  @override
  Future<List<PlexMetadata>> getAllUnwatchedEpisodes(String showRatingKey) async {
    final seasons = await getChildren(showRatingKey);
    final all = <PlexMetadata>[];
    for (final s in seasons) {
      if (s.type.toLowerCase() == 'season') {
        final episodes = await getChildren(s.ratingKey);
        all.addAll(episodes.where((e) => e.type.toLowerCase() == 'episode' && (e.viewCount ?? 0) == 0));
      }
    }
    return all;
  }

  @override
  Future<List<PlexMetadata>> getUnwatchedEpisodesInSeason(String seasonRatingKey) async {
    final episodes = await getChildren(seasonRatingKey);
    return episodes.where((e) => e.type.toLowerCase() == 'episode' && (e.viewCount ?? 0) == 0).toList();
  }

  @override
  String getThumbnailUrl(String? thumbPath) {
    if (thumbPath == null || thumbPath.isEmpty) return '';
    final base = config.baseUrl.endsWith('/') ? config.baseUrl : '${config.baseUrl}/';
    final token = config.token;
    return token.isEmpty
        ? '${base}Items/$thumbPath/Images/Primary'
        : '${base}Items/$thumbPath/Images/Primary?ApiKey=${Uri.encodeComponent(token)}';
  }

  @override
  Map<String, String>? get imageHttpHeaders => requestHeaders;

  @override
  Future<bool> checkThumbnailsAvailable(int partId) async {
    return false;
  }

  @override
  Future<List<PlexChapter>> getChapters(String ratingKey) async {
    try {
      final item = await _dio.get<Map<String, dynamic>>(
        '/Users/${config.userId}/Items/$ratingKey',
        queryParameters: {'Fields': 'Chapters'},
      );
      final chapters = item.data?['Chapters'] as List?;
      if (chapters == null) return [];
      final list = <PlexChapter>[];
      for (var i = 0; i < chapters.length; i++) {
        final c = chapters[i] as Map<String, dynamic>;
        final start = _toInt(c['StartPositionTicks']);
        final end = _toInt(c['EndPositionTicks']);
        list.add(PlexChapter(
          id: i,
          index: i,
          startTimeOffset: _ticksToMs(start),
          endTimeOffset: _ticksToMs(end),
          title: c['Name'] as String?,
          thumb: null,
        ));
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<PlexMarker>> getMarkers(String ratingKey) async {
    return [];
  }

  @override
  Future<PlaybackExtras> getPlaybackExtras(String ratingKey) async {
    final chapters = await getChapters(ratingKey);
    return PlaybackExtras(chapters: chapters, markers: []);
  }

  @override
  Future<PlexVideoPlaybackData> getVideoPlaybackData(String ratingKey, {int mediaIndex = 0}) async {
    String? videoUrl;
    PlexMediaInfo? mediaInfo;
    final versions = <PlexMediaVersion>[];
    final markers = <PlexMarker>[];

    if (!_offlineMode) {
      try {
        final itemResponse = await _dio.get<Map<String, dynamic>>(
          '/Users/${config.userId}/Items/$ratingKey',
          queryParameters: {'Fields': 'MediaSources,MediaStreams,Chapters'},
        );
        final item = itemResponse.data;
        if (item != null) {
          final mediaSources = item['MediaSources'] as List?;
          if (mediaSources != null && mediaSources.isNotEmpty) {
            final idx = mediaIndex.clamp(0, mediaSources.length - 1);
            final source = mediaSources[idx] as Map<String, dynamic>;
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
            videoUrl ??= '${config.baseUrl}/Videos/$ratingKey/stream?api_key=${config.token}';
            final streams = item['MediaStreams'] as List? ?? [];
            final audioTracks = <PlexAudioTrack>[];
            final subtitleTracks = <PlexSubtitleTrack>[];
            var audioIdx = 0;
            var subIdx = 0;
            for (final s in streams) {
              final m = s as Map<String, dynamic>;
              final type = m['Type'] as String?;
              if (type == 'Audio') {
                audioTracks.add(PlexAudioTrack(
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
                subtitleTracks.add(PlexSubtitleTrack(
                  id: subIdx,
                  index: subIdx,
                  codec: m['Codec'] as String?,
                  language: m['Language'] as String?,
                  languageCode: m['Language'] as String?,
                  title: m['Title'] as String?,
                  displayTitle: m['DisplayTitle'] as String?,
                  selected: m['IsDefault'] == true,
                  forced: m['IsForced'] == true,
                  key: null,
                ));
                subIdx++;
              }
            }
            final chapters = await getChapters(ratingKey);
            mediaInfo = PlexMediaInfo(
              videoUrl: videoUrl,
              audioTracks: audioTracks,
              subtitleTracks: subtitleTracks,
              chapters: chapters,
              partId: null,
            );
            for (final ms in mediaSources) {
              final m = ms as Map<String, dynamic>;
              versions.add(PlexMediaVersion(
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
        videoUrl = '${config.baseUrl}/Videos/$ratingKey/stream?api_key=${config.token}';
      }
    }

    return PlexVideoPlaybackData(
      videoUrl: videoUrl,
      mediaInfo: mediaInfo,
      availableVersions: versions,
      markers: markers,
    );
  }

  @override
  Future<PlexFileInfo?> getFileInfo(String ratingKey) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/Users/${config.userId}/Items/$ratingKey',
        queryParameters: {'Fields': 'MediaSources,MediaStreams'},
      );
      final item = response.data;
      final sources = item?['MediaSources'] as List?;
      if (sources == null || sources.isEmpty) return null;
      final source = sources.first as Map<String, dynamic>;
      final streams = item?['MediaStreams'] as List? ?? [];
      Map<String, dynamic>? videoStream;
      Map<String, dynamic>? audioStream;
      for (final s in streams) {
        final m = s as Map<String, dynamic>;
        if (m['Type'] == 'Video' && videoStream == null) videoStream = m;
        if (m['Type'] == 'Audio' && audioStream == null) audioStream = m;
      }
      return PlexFileInfo(
        container: source['Container'] as String?,
        videoCodec: source['VideoCodec'] as String?,
        videoResolution: source['VideoType'] as String?,
        width: _toInt(source['Width']),
        height: _toInt(source['Height']),
        bitrate: _toInt(source['Bitrate']),
        duration: _ticksToMs(_toInt(source['RunTimeTicks'])),
        audioCodec: source['AudioCodec'] as String?,
        audioChannels: _toInt(source['AudioChannels']),
        frameRate: _toDouble(videoStream?['FrameRate']),
        bitDepth: _toInt(videoStream?['BitDepth']),
        audioChannelLayout: audioStream?['ChannelLayout'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> markAsWatched(String ratingKey, {PlexMetadata? metadata}) async {
    if (_offlineMode) return;
    await _dio.post('/Users/${config.userId}/PlayedItems/$ratingKey');
    if (metadata != null) {
      WatchStateNotifier().notifyWatched(metadata: metadata, isNowWatched: true);
    }
  }

  @override
  Future<void> markAsUnwatched(String ratingKey, {PlexMetadata? metadata}) async {
    if (_offlineMode) return;
    await _dio.delete('/Users/${config.userId}/PlayedItems/$ratingKey');
    if (metadata != null) {
      WatchStateNotifier().notifyWatched(metadata: metadata, isNowWatched: false);
    }
  }

  @override
  Future<bool?> toggleFavorite(String ratingKey, {bool? isCurrentlyFavorite}) async {
    if (_offlineMode) return null;
    try {
      final isFavorite = isCurrentlyFavorite ?? false;
      if (isFavorite) {
        await _dio.delete('/Users/${config.userId}/FavoriteItems/$ratingKey');
        return false;
      } else {
        await _dio.post('/Users/${config.userId}/FavoriteItems/$ratingKey');
        return true;
      }
    } catch (e) {
      appLogger.e('Jellyfin toggleFavorite failed', error: e);
      return null;
    }
  }

  @override
  Future<void> updateProgress(
    String ratingKey, {
    required int time,
    required String state,
    int? duration,
  }) async {
    if (_offlineMode) return;
    await _dio.post(
      '/Sessions/Playing/Progress',
      data: {
        'ItemId': ratingKey,
        'PositionTicks': time * 10000,
        'IsPaused': state == 'paused',
        if (duration != null) 'PlaybackDurationTicks': duration * 10000,
      },
    );
  }

  @override
  Future<void> removeFromOnDeck(String ratingKey) async {}

  @override
  Future<bool> rateItem(String ratingKey, double rating) async {
    try {
      await _dio.post(
        '/Users/${config.userId}/Items/$ratingKey/Rating',
        data: {'Rating': rating < 0 ? 0 : rating},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> deleteMediaItem(String ratingKey) async {
    try {
      await _dio.delete('/Items/$ratingKey');
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<PlexMetadata>> search(String query, {int limit = 10}) async {
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

  @override
  Future<List<PlexMetadata>> getRecentlyAdded({int limit = 50}) async {
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

  @override
  Future<List<PlexMetadata>> getOnDeck() async {
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

  @override
  Future<List<PlexMetadata>> getOnDeckForLibrary(String sectionId) async {
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

  @override
  Future<Map<String, dynamic>> getServerPreferences() async {
    return {};
  }

  @override
  Future<List<dynamic>> getSessions() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/Sessions');
      final list = response.data?['Sessions'] as List?;
      return list ?? [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<PlexFilter>> getLibraryFilters(String sectionId) async {
    if (_offlineMode) return [];
    // Key encodes sectionId so getFilterValues can scope to this library
    return [
      PlexFilter(
        filter: 'genre',
        filterType: 'string',
        key: 'genre:$sectionId',
        title: 'Genre',
        type: 'filter',
      ),
      PlexFilter(
        filter: 'year',
        filterType: 'string',
        key: 'year:$sectionId',
        title: 'Year',
        type: 'filter',
      ),
    ];
  }

  @override
  Future<List<PlexFirstCharacter>> getFirstCharacters(
    String sectionId, {
    int? type,
    Map<String, String>? filters,
  }) async {
    return [];
  }

  @override
  Future<List<PlexFilterValue>> getFilterValues(String filterKey) async {
    if (_offlineMode) return [];
    if (!filterKey.contains(':')) return [];
    final parts = filterKey.split(':');
    final kind = parts[0];
    final sectionId = parts.sublist(1).join(':');
    if (sectionId.isEmpty) return [];

    if (kind == 'genre') {
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
              return PlexFilterValue(key: name, title: name, type: 'genre');
            })
            .toList();
      } catch (e) {
        appLogger.d('Jellyfin getFilterValues(genre) failed: $e');
        return [];
      }
    }

    if (kind == 'year') {
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
              return PlexFilterValue(key: name, title: name, type: 'year');
            })
            .toList();
      } catch (e) {
        appLogger.d('Jellyfin getFilterValues(year) failed: $e');
        return [];
      }
    }

    return [];
  }

  @override
  Future<List<PlexSort>> getLibrarySorts(String sectionId, {String? libraryType}) async {
    // All options from Jellyfin API ItemSortBy enum (OpenAPI spec). No server endpoint returns this list.
    final sorts = [
      PlexSort(key: 'SortName', title: 'Name', defaultDirection: 'asc'),
      PlexSort(key: 'Name', title: 'Title', defaultDirection: 'asc'),
      PlexSort(key: 'DateCreated', descKey: 'DateCreated:desc', title: 'Date added', defaultDirection: 'desc'),
      PlexSort(key: 'PremiereDate', descKey: 'PremiereDate:desc', title: 'Premiere date', defaultDirection: 'desc'),
      PlexSort(key: 'ProductionYear', descKey: 'ProductionYear:desc', title: 'Production year', defaultDirection: 'desc'),
      PlexSort(key: 'DatePlayed', descKey: 'DatePlayed:desc', title: 'Last played', defaultDirection: 'desc'),
      PlexSort(key: 'CommunityRating', descKey: 'CommunityRating:desc', title: 'Community rating', defaultDirection: 'desc'),
      PlexSort(key: 'CriticRating', descKey: 'CriticRating:desc', title: 'Critic rating', defaultDirection: 'desc'),
      PlexSort(key: 'OfficialRating', title: 'Official rating', defaultDirection: 'asc'),
      PlexSort(key: 'Runtime', descKey: 'Runtime:desc', title: 'Runtime', defaultDirection: 'desc'),
      PlexSort(key: 'PlayCount', descKey: 'PlayCount:desc', title: 'Play count', defaultDirection: 'desc'),
      PlexSort(key: 'Random', title: 'Random', defaultDirection: 'asc'),
      PlexSort(key: 'Default', title: 'Default', defaultDirection: 'asc'),
      PlexSort(key: 'Album', title: 'Album', defaultDirection: 'asc'),
      PlexSort(key: 'AlbumArtist', title: 'Album artist', defaultDirection: 'asc'),
      PlexSort(key: 'Artist', title: 'Artist', defaultDirection: 'asc'),
      PlexSort(key: 'StartDate', descKey: 'StartDate:desc', title: 'Start date', defaultDirection: 'desc'),
      PlexSort(key: 'SeriesSortName', title: 'Series name', defaultDirection: 'asc'),
      PlexSort(key: 'VideoBitRate', descKey: 'VideoBitRate:desc', title: 'Video bit rate', defaultDirection: 'desc'),
      PlexSort(key: 'AirTime', title: 'Air time', defaultDirection: 'asc'),
      PlexSort(key: 'Studio', title: 'Studio', defaultDirection: 'asc'),
      PlexSort(key: 'IsFavoriteOrLiked', descKey: 'IsFavoriteOrLiked:desc', title: 'Favorite', defaultDirection: 'desc'),
      PlexSort(key: 'DateLastContentAdded', descKey: 'DateLastContentAdded:desc', title: 'Date last content added', defaultDirection: 'desc'),
      PlexSort(key: 'SeriesDatePlayed', descKey: 'SeriesDatePlayed:desc', title: 'Series last played', defaultDirection: 'desc'),
      PlexSort(key: 'AiredEpisodeOrder', title: 'Aired episode order', defaultDirection: 'asc'),
      PlexSort(key: 'ParentIndexNumber', title: 'Season', defaultDirection: 'asc'),
      PlexSort(key: 'IndexNumber', title: 'Index number', defaultDirection: 'asc'),
      PlexSort(key: 'IsFolder', title: 'Is folder', defaultDirection: 'asc'),
      PlexSort(key: 'IsUnplayed', descKey: 'IsUnplayed:desc', title: 'Unplayed', defaultDirection: 'desc'),
      PlexSort(key: 'IsPlayed', descKey: 'IsPlayed:desc', title: 'Played', defaultDirection: 'desc'),
    ];
    return sorts;
  }

  /// Jellyfin GET /Movies/Recommendations returns categories (Because you watched X, Because you liked X, etc.).
  @override
  Future<List<PlexHub>> getMovieRecommendations(String sectionId, {int categoryLimit = 10, int itemLimit = 12}) async {
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
      final hubs = <PlexHub>[];
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
        hubs.add(PlexHub(
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

  @override
  Future<List<PlexHub>> getLibraryHubs(String sectionId, {int limit = 10}) async {
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
        PlexHub(
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

  @override
  Future<List<PlexHub>> getGlobalHubs({int limit = 10}) async {
    if (_offlineMode) return [];
    final perHub = limit > 0 ? limit : 12;

    // Run all three hub requests in parallel. Try both common NextUp paths.
    Future<Map<String, dynamic>?> _nextUp() async {
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
      } catch (_) {}
      return null;
    }

    Future<Map<String, dynamic>?> _movies() async {
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

    Future<Map<String, dynamic>?> _shows() async {
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

    final results = await Future.wait([_nextUp(), _movies(), _shows()]);
    final hubs = <PlexHub>[];

    final nextUp = results[0];
    if (nextUp != null) {
      final items = (nextUp['Items'] as List?) ?? [];
      if (items.isNotEmpty) {
        hubs.add(PlexHub(
          hubKey: 'next_up',
          title: 'Next Up',
          type: 'show',
          hubIdentifier: 'nextup',
          size: items.length,
          more: (_toInt(nextUp['TotalRecordCount']) ?? 0) > items.length,
          items: items.map((e) => _itemToMetadata(e as Map<String, dynamic>)).toList(),
          serverId: serverId,
          serverName: serverName,
        ));
      }
    }

    final movies = results[1];
    if (movies != null) {
      final list = (movies['Items'] as List?) ?? [];
      if (list.isNotEmpty) {
        hubs.add(PlexHub(
          hubKey: 'recently_added_movies',
          title: 'Recently Added Movies',
          type: 'movie',
          hubIdentifier: 'recently_added_movies',
          size: list.length,
          more: (_toInt(movies['TotalRecordCount']) ?? 0) > list.length,
          items: list.map((e) => _itemToMetadata(e as Map<String, dynamic>)).toList(),
          serverId: serverId,
          serverName: serverName,
        ));
      }
    }

    final shows = results[2];
    if (shows != null) {
      final list = (shows['Items'] as List?) ?? [];
      if (list.isNotEmpty) {
        hubs.add(PlexHub(
          hubKey: 'recently_added_shows',
          title: 'Recently Added Shows',
          type: 'show',
          hubIdentifier: 'recently_added_shows',
          size: list.length,
          more: (_toInt(shows['TotalRecordCount']) ?? 0) > list.length,
          items: list.map((e) => _itemToMetadata(e as Map<String, dynamic>)).toList(),
          serverId: serverId,
          serverName: serverName,
        ));
      }
    }

    appLogger.d('Jellyfin getGlobalHubs: ${hubs.length} hubs');
    return hubs;
  }

  @override
  Future<List<PlexMetadata>> getHubContent(String hubKey) async {
    return [];
  }

  @override
  Future<List<PlexMetadata>> getPlaylist(String playlistId) async {
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

  @override
  Future<List<PlexPlaylist>> getPlaylists({String playlistType = 'video', bool? smart}) async {
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
        return PlexPlaylist(
          ratingKey: m['Id']?.toString() ?? '',
          key: m['Id']?.toString() ?? '',
          type: 'playlist',
          title: m['Name'] as String? ?? 'Playlist',
          summary: m['Overview'] as String?,
          smart: false,
          playlistType: playlistType,
          leafCount: _toInt(m['ChildCount']),
          serverId: serverId,
          serverName: serverName,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<PlexPlaylist?> getPlaylistMetadata(String playlistId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/Playlists/$playlistId');
      final m = response.data;
      if (m == null) return null;
      return PlexPlaylist(
        ratingKey: m['Id']?.toString() ?? playlistId,
        key: m['Id']?.toString() ?? playlistId,
        type: 'playlist',
        title: m['Name'] as String? ?? 'Playlist',
        summary: m['Overview'] as String?,
        smart: false,
        playlistType: 'video',
        leafCount: _toInt(m['ChildCount']),
        serverId: serverId,
        serverName: serverName,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<PlexPlaylist?> createPlaylist({required String title, String? uri, int? playQueueId}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>('/Playlists', data: {'Name': title});
      final m = response.data;
      if (m == null) return null;
      return PlexPlaylist(
        ratingKey: m['Id']?.toString() ?? '',
        key: m['Id']?.toString() ?? '',
        type: 'playlist',
        title: title,
        smart: false,
        playlistType: 'video',
        serverId: serverId,
        serverName: serverName,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> deletePlaylist(String playlistId) async {
    try {
      await _dio.delete('/Playlists/$playlistId');
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> addToPlaylist({required String playlistId, required String uri}) async {
    try {
      await _dio.post('/Playlists/$playlistId/Items', queryParameters: {'Ids': uri});
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> removeFromPlaylist({required String playlistId, required String playlistItemId}) async {
    try {
      await _dio.delete('/Playlists/$playlistId/Items/$playlistItemId');
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> movePlaylistItem({
    required String playlistId,
    required int playlistItemId,
    required int afterPlaylistItemId,
  }) async {
    return false;
  }

  @override
  Future<bool> clearPlaylist(String playlistId) async {
    try {
      final items = await getPlaylist(playlistId);
      for (final item in items) {
        await removeFromPlaylist(playlistId: playlistId, playlistItemId: item.ratingKey);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> updatePlaylist({required String playlistId, String? title, String? summary}) async {
    return false;
  }

  @override
  Future<List<PlexMetadata>> getLibraryCollections(String sectionId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/Users/${config.userId}/Items',
        queryParameters: {'ParentId': sectionId, 'IncludeItemTypes': 'BoxSet', 'Fields': _listFields},
      );
      final list = response.data?['Items'] as List?;
      if (list == null) return [];
      return list.map((e) => _itemToMetadata(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<PlexMetadata>> getGlobalCollections() async {
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

  @override
  Future<List<PlexMetadata>> getLibraryFavorites(String sectionId) async {
    if (_offlineMode) return [];
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/Users/${config.userId}/Items',
        queryParameters: {
          'ParentId': sectionId,
          'Recursive': true,
          'IncludeItemTypes': 'Movie,Series',
          'IsFavorite': true,
          'Fields': _listFields,
          'SortBy': 'SortName',
          'SortOrder': 'Ascending',
        },
      );
      final list = response.data?['Items'] as List?;
      if (list == null) return [];
      return list.map((e) => _itemToMetadata(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<PlexMetadata>> getCollectionItems(String collectionId) async {
    return getChildren(collectionId);
  }

  @override
  Future<bool> deleteCollection(String sectionId, String collectionId) async {
    try {
      await _dio.delete('/Items/$collectionId');
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> createCollection({
    required String sectionId,
    required String title,
    required String uri,
    int? type,
  }) async {
    return null;
  }

  @override
  Future<bool> addToCollection({required String collectionId, required String uri}) async {
    return false;
  }

  @override
  Future<bool> removeFromCollection({required String collectionId, required String itemId}) async {
    return false;
  }

  @override
  Future<PlayQueueResponse?> createPlayQueue({
    String? uri,
    int? playlistID,
    required String type,
    String? key,
    int shuffle = 0,
    int repeat = 0,
    int continuous = 0,
  }) async {
    return null;
  }

  @override
  Future<PlayQueueResponse?> getPlayQueue(
    int playQueueId, {
    String? center,
    int window = 50,
    int includeBefore = 1,
    int includeAfter = 1,
  }) async {
    return null;
  }

  @override
  Future<PlayQueueResponse?> shufflePlayQueue(int playQueueId) async {
    return null;
  }

  @override
  Future<bool> clearPlayQueue(int playQueueId) async {
    return false;
  }

  @override
  Future<PlayQueueResponse?> createShowPlayQueue({
    required String showRatingKey,
    int shuffle = 0,
    String? startingEpisodeKey,
  }) async {
    return null;
  }

  @override
  Future<List<PlexMetadata>> getLibraryFolders(String sectionId) async {
    return getLibraryContent(sectionId);
  }

  @override
  Future<List<PlexMetadata>> getFolderChildren(String folderKey) async {
    return getChildren(folderKey);
  }

  @override
  Future<List<PlexPlaylist>> getLibraryPlaylists({String playlistType = 'video'}) async {
    return getPlaylists(playlistType: playlistType);
  }

  @override
  Future<void> scanLibrary(String sectionId) async {}

  @override
  Future<void> refreshLibraryMetadata(String sectionId) async {}

  @override
  Future<void> emptyLibraryTrash(String sectionId) async {}

  @override
  Future<void> analyzeLibrary(String sectionId) async {}

  @override
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

  @override
  Future<int> getLibraryEpisodeCount(String sectionId) async {
    return getLibraryTotalCount(sectionId);
  }

  @override
  Future<int> getWatchHistoryCount({DateTime? since}) async {
    return 0;
  }

  @override
  Future<List<LiveTvDvr>> getDvrs() async {
    return [];
  }

  @override
  Future<bool> hasDvr() async {
    return false;
  }

  @override
  Future<List<LiveTvChannel>> getEpgChannels({String? lineup}) async {
    return [];
  }

  @override
  Future<List<LiveTvProgram>> getEpgGrid({int? beginsAt, int? endsAt}) async {
    return [];
  }

  @override
  Future<List<LiveTvHubResult>> getLiveTvHubs({int count = 12}) async {
    return [];
  }

  @override
  Future<bool> reloadGuide(String dvrKey) async {
    return false;
  }

  @override
  Future<List<PlexMetadata>> getLiveTvSessions() async {
    return [];
  }

  @override
  Future<List<LiveTvSubscription>> getSubscriptions() async {
    return [];
  }

  @override
  Future<LiveTvSubscription?> createSubscription({
    required String type,
    required int targetSectionID,
    required int targetLibrarySectionID,
    Map<String, String>? prefs,
    String? hint,
    String? uri,
  }) async {
    return null;
  }

  @override
  Future<bool> deleteSubscription(String subscriptionId) async {
    return false;
  }

  @override
  Future<bool> editSubscription(String subscriptionId, Map<String, String> prefs) async {
    return false;
  }

  @override
  Future<List<ScheduledRecording>> getScheduledRecordings() async {
    return [];
  }

  @override
  Future<Map<String, dynamic>?> getSubscriptionTemplate(String guid) async {
    return null;
  }

  @override
  Future<String> buildMetadataUri(String ratingKey) async => ratingKey;

  @override
  Future<void> updateLiveTimeline({
    required String ratingKey,
    required String sessionPath,
    required String sessionIdentifier,
    required String state,
    required int time,
    required int duration,
    required int playbackTime,
  }) async {}

  @override
  Future<bool> setMetadataPreferences(String ratingKey, {String? audioLanguage, String? subtitleLanguage}) async =>
      true;

  @override
  Future<bool> selectStreams(int partId, {int? audioStreamID, int? subtitleStreamID, bool allParts = true}) async =>
      true;

  @override
  Future<({PlexMetadata metadata, String streamPath, String sessionIdentifier, String sessionPath})?> tuneChannel(
    String dvrKey,
    String channelKey,
  ) async =>
      null;
}
