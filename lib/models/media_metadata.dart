import 'package:json_annotation/json_annotation.dart';

import '../services/settings_service.dart' show EpisodePosterMode;
import '../widgets/optimized_image.dart' show kBlurArtwork, obfuscateText;
import 'mixins/multi_server_fields.dart';
import 'cast_role.dart';

part 'media_metadata.g.dart';

/// Media type enum for type-safe media type handling
enum MediaType {
  movie,
  show,
  season,
  episode,
  artist,
  album,
  track,
  collection,
  playlist,
  clip,
  photo,
  person,
  program,
  channel,
  unknown;

  /// Whether this type represents video content
  bool get isVideo => this == movie || this == episode || this == clip;

  /// Whether this type is part of a show hierarchy
  bool get isShowRelated => this == show || this == season || this == episode;

  /// Whether this type represents music content
  bool get isMusic => this == artist || this == album || this == track;

  /// Whether this type can be played directly
  bool get isPlayable => isVideo || this == track;
}

@JsonSerializable()
class MediaMetadata with MultiServerFields {
  final String itemId;
  final String key;
  final String? guid;
  final String? studio;
  final String type;
  final String title;
  final String? titleSort;
  final String? contentRating;
  final String? summary;
  final double? rating;
  final double? audienceRating;
  final double? userRating;
  final int? year;
  final String? originallyAvailableAt; // Full release date (YYYY-MM-DD)
  final String? thumb;

  /// Jellyfin ImageTag (content hash) for [thumb]. Used as a `tag=` query
  /// parameter in image URLs so cached images bust when the server's image
  /// changes (e.g. after a metadata refresh).
  final String? thumbTag;
  final String? art;

  /// Jellyfin ImageTag for [art] (Backdrop). See [thumbTag].
  final String? artTag;
  final int? duration;
  final int? addedAt;
  final int? updatedAt;
  final int? lastPlayedAt; // Timestamp when item was last viewed
  final String? seriesTitle; // Show title for episodes
  final String? seriesImageId; // Show poster for episodes
  /// Jellyfin SeriesPrimaryImageTag for [seriesImageId]. See [thumbTag].
  final String? seriesImageTag;
  final String? seriesArt; // Show art for episodes
  /// Jellyfin ParentBackdropImageTag for [seriesArt]. See [thumbTag].
  final String? seriesArtTag;
  final String? seriesId; // Show ID for episodes
  final String? seasonTitle; // Season title for episodes
  final String? seasonImageId; // Season poster for episodes
  /// Jellyfin ImageTag for [seasonImageId]. See [thumbTag].
  final String? seasonImageTag;
  final String? seasonId; // Season ID for episodes
  final int? parentIndex; // Season number
  final int? index; // Episode number
  final String? seriesTheme; // Show theme music
  final int? resumePositionMs; // Resume position in ms
  final int? playCount;
  final int? leafCount; // Total number of episodes in a series/season
  final int? watchedEpisodeCount; // Number of watched episodes in a series/season
  /// Unwatched/unplayed count when server provides it directly (e.g. Jellyfin UnplayedItemCount).
  /// Badge can show this without needing total (leafCount).
  final int? unwatchedCount;
  final int? childCount; // Number of items in a collection or playlist
  @JsonKey(name: 'Role')
  final List<CastRole>? role; // Cast members
  final String? audioLanguage; // Per-media preferred audio language
  final String? subtitleLanguage; // Per-media preferred subtitle language
  final int? playlistItemID; // Playlist item ID (for dumb playlists only)
  final int? playQueueItemID; // Play queue item ID (unique even for duplicates)
  final int? libraryId; // Library section ID this item belongs to
  final String? ratingImage; // Rating source URI (e.g. rottentomatoes://image.rating.ripe)
  final String? audienceRatingImage; // Audience rating source URI
  final String? subtype; // Clip subtype: "trailer", "behindTheScenes", "deleted", etc.
  final int? extraType; // Numeric extra type identifier
  final String? primaryExtraKey; // Points to main trailer (e.g., "/items/52601")

  // Multi-server support fields (from MultiServerFields mixin)
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String? serverId;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String? serverName;

  // Clear logo URL (extracted from Image array, but serialized for offline storage)
  final String? clearLogo;

  /// True when item is marked as favorite (Jellyfin only; set at runtime, not serialized).
  @JsonKey(includeFromJson: false, includeToJson: false)
  final bool? isFavorite;

  /// End year for TV series (Jellyfin only; from EndDate). Enables "2025 - 2026" display.
  @JsonKey(includeFromJson: false, includeToJson: false)
  final int? endYear;

  /// Series status e.g. "Continuing" or "Ended" (Jellyfin only). When "Continuing", show "year - Present".
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String? seriesStatus;

  /// Global unique identifier across all servers (serverId:itemId)
  String get globalKey => serverId != null ? '$serverId:$itemId' : itemId;

  /// Parsed media type enum for type-safe comparisons
  MediaType get mediaType {
    return switch (type.toLowerCase()) {
      'movie' => MediaType.movie,
      'show' => MediaType.show,
      'season' => MediaType.season,
      'episode' => MediaType.episode,
      'artist' => MediaType.artist,
      'album' => MediaType.album,
      'track' => MediaType.track,
      'collection' => MediaType.collection,
      'playlist' => MediaType.playlist,
      'clip' => MediaType.clip,
      'photo' => MediaType.photo,
      'person' => MediaType.person,
      'program' => MediaType.program,
      'channel' => MediaType.channel,
      'tvchannel' => MediaType.channel,
      _ => MediaType.unknown,
    };
  }

  MediaMetadata({
    required this.itemId,
    required this.key,
    this.guid,
    this.studio,
    required this.type,
    required this.title,
    this.titleSort,
    this.contentRating,
    this.summary,
    this.rating,
    this.audienceRating,
    this.userRating,
    this.year,
    this.originallyAvailableAt,
    this.thumb,
    this.thumbTag,
    this.art,
    this.artTag,
    this.duration,
    this.addedAt,
    this.updatedAt,
    this.lastPlayedAt,
    this.seriesTitle,
    this.seriesImageId,
    this.seriesImageTag,
    this.seriesArt,
    this.seriesArtTag,
    this.seriesId,
    this.seasonTitle,
    this.seasonImageId,
    this.seasonImageTag,
    this.seasonId,
    this.parentIndex,
    this.index,
    this.seriesTheme,
    this.resumePositionMs,
    this.playCount,
    this.leafCount,
    this.watchedEpisodeCount,
    this.unwatchedCount,
    this.childCount,
    this.role,
    this.audioLanguage,
    this.subtitleLanguage,
    this.playlistItemID,
    this.playQueueItemID,
    this.libraryId,
    this.ratingImage,
    this.audienceRatingImage,
    this.subtype,
    this.extraType,
    this.primaryExtraKey,
    this.serverId,
    this.serverName,
    this.clearLogo,
    this.isFavorite,
    this.endYear,
    this.seriesStatus,
  });

  /// Create a copy of this metadata with optional field overrides
  MediaMetadata copyWith({
    String? itemId,
    String? key,
    String? guid,
    String? studio,
    String? type,
    String? title,
    String? titleSort,
    String? contentRating,
    String? summary,
    double? rating,
    double? audienceRating,
    double? userRating,
    int? year,
    String? originallyAvailableAt,
    String? thumb,
    String? thumbTag,
    String? art,
    String? artTag,
    int? duration,
    int? addedAt,
    int? updatedAt,
    int? lastPlayedAt,
    String? seriesTitle,
    String? seriesImageId,
    String? seriesImageTag,
    String? seriesArt,
    String? seriesArtTag,
    String? seriesId,
    String? seasonTitle,
    String? seasonImageId,
    String? seasonImageTag,
    String? seasonId,
    int? parentIndex,
    int? index,
    String? seriesTheme,
    int? resumePositionMs,
    int? playCount,
    int? leafCount,
    int? watchedEpisodeCount,
    int? unwatchedCount,
    int? childCount,
    List<CastRole>? role,
    String? audioLanguage,
    String? subtitleLanguage,
    int? playlistItemID,
    int? playQueueItemID,
    int? libraryId,
    String? ratingImage,
    String? audienceRatingImage,
    String? subtype,
    int? extraType,
    String? primaryExtraKey,
    String? serverId,
    String? serverName,
    String? clearLogo,
    bool? isFavorite,
    int? endYear,
    String? seriesStatus,
  }) {
    return MediaMetadata(
      itemId: itemId ?? this.itemId,
      key: key ?? this.key,
      guid: guid ?? this.guid,
      studio: studio ?? this.studio,
      type: type ?? this.type,
      title: title ?? this.title,
      titleSort: titleSort ?? this.titleSort,
      contentRating: contentRating ?? this.contentRating,
      summary: summary ?? this.summary,
      rating: rating ?? this.rating,
      audienceRating: audienceRating ?? this.audienceRating,
      userRating: userRating ?? this.userRating,
      year: year ?? this.year,
      originallyAvailableAt: originallyAvailableAt ?? this.originallyAvailableAt,
      thumb: thumb ?? this.thumb,
      thumbTag: thumbTag ?? this.thumbTag,
      art: art ?? this.art,
      artTag: artTag ?? this.artTag,
      duration: duration ?? this.duration,
      addedAt: addedAt ?? this.addedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      seriesTitle: seriesTitle ?? this.seriesTitle,
      seriesImageId: seriesImageId ?? this.seriesImageId,
      seriesImageTag: seriesImageTag ?? this.seriesImageTag,
      seriesArt: seriesArt ?? this.seriesArt,
      seriesArtTag: seriesArtTag ?? this.seriesArtTag,
      seriesId: seriesId ?? this.seriesId,
      seasonTitle: seasonTitle ?? this.seasonTitle,
      seasonImageId: seasonImageId ?? this.seasonImageId,
      seasonImageTag: seasonImageTag ?? this.seasonImageTag,
      seasonId: seasonId ?? this.seasonId,
      parentIndex: parentIndex ?? this.parentIndex,
      index: index ?? this.index,
      seriesTheme: seriesTheme ?? this.seriesTheme,
      resumePositionMs: resumePositionMs ?? this.resumePositionMs,
      playCount: playCount ?? this.playCount,
      leafCount: leafCount ?? this.leafCount,
      watchedEpisodeCount: watchedEpisodeCount ?? this.watchedEpisodeCount,
      unwatchedCount: unwatchedCount ?? this.unwatchedCount,
      childCount: childCount ?? this.childCount,
      role: role ?? this.role,
      audioLanguage: audioLanguage ?? this.audioLanguage,
      subtitleLanguage: subtitleLanguage ?? this.subtitleLanguage,
      playlistItemID: playlistItemID ?? this.playlistItemID,
      playQueueItemID: playQueueItemID ?? this.playQueueItemID,
      libraryId: libraryId ?? this.libraryId,
      ratingImage: ratingImage ?? this.ratingImage,
      audienceRatingImage: audienceRatingImage ?? this.audienceRatingImage,
      subtype: subtype ?? this.subtype,
      extraType: extraType ?? this.extraType,
      primaryExtraKey: primaryExtraKey ?? this.primaryExtraKey,
      serverId: serverId ?? this.serverId,
      serverName: serverName ?? this.serverName,
      clearLogo: clearLogo ?? this.clearLogo,
      isFavorite: isFavorite ?? this.isFavorite,
      endYear: endYear ?? this.endYear,
      seriesStatus: seriesStatus ?? this.seriesStatus,
    );
  }

  /// Extract clearLogo from Image array in raw JSON
  static String? _extractClearLogoFromJson(Map<String, dynamic> json) {
    if (!json.containsKey('Image')) return null;

    final images = json['Image'] as List?;
    if (images == null) return null;

    for (var image in images) {
      if (image is Map && image['type'] == 'clearLogo') {
        return image['url'] as String?;
      }
    }
    return null;
  }

  /// Create from JSON with clearLogo extracted from Image array
  factory MediaMetadata.fromJsonWithImages(Map<String, dynamic> json) {
    // Extract clearLogo before parsing
    final clearLogoUrl = _extractClearLogoFromJson(json);
    // Add it to the json so it gets parsed
    if (clearLogoUrl != null) {
      json['clearLogo'] = clearLogoUrl;
    }
    return MediaMetadata.fromJson(json);
  }

  /// Year string for display: single year, or "2024 - 2026" (ended) / "2024 - Present" (continuing) for shows (Jellyfin).
  /// End year is only shown when the show is not continuing.
  String? get yearForDisplay {
    if (year == null) return null;
    if (mediaType == MediaType.show) {
      final isContinuing = seriesStatus != null && seriesStatus!.toLowerCase() == 'continuing';
      if (isContinuing) return '$year - Present';
      if (endYear != null) return '$year - $endYear';
    }
    return '$year';
  }

  // Helper to get the display title (show name for episodes/seasons, title otherwise)
  String get displayTitle {
    final itemType = type.toLowerCase();

    // For episodes and seasons, prefer grandparent title (show name)
    if ((itemType == 'episode' || itemType == 'season') && seriesTitle != null) {
      return seriesTitle!;
    }
    // For seasons without grandparent, check if this IS the show (seasonTitle might have show name)
    if (itemType == 'season' && seasonTitle != null) {
      return seasonTitle!;
    }
    return title;
  }

  // Helper to get the subtitle (episode/season title)
  String? get displaySubtitle {
    final itemType = type.toLowerCase();

    if (itemType == 'episode' || itemType == 'season') {
      // If we showed grandparent/parent as title, show this item's title as subtitle
      if (seriesTitle != null || (itemType == 'season' && seasonTitle != null)) {
        return title;
      }
    }
    return null;
  }

  /// Returns the appropriate image path based on episode poster mode.
  /// For episodes:
  ///   - seriesPoster: seriesImageId (series poster)
  ///   - seasonPoster: seasonImageId (season poster)
  ///   - episodeThumbnail: thumb (16:9 episode still)
  /// For seasons: returns seriesImageId (series poster), or art/thumb in mixed hub context
  /// For movies/shows/seasons in mixed hub context: returns art (16:9 background)
  /// For other types: returns thumb
  String? posterThumb({EpisodePosterMode mode = EpisodePosterMode.seriesPoster, bool mixedHubContext = false}) {
    final itemType = type.toLowerCase();

    if (itemType == 'episode') {
      switch (mode) {
        case EpisodePosterMode.episodeThumbnail:
          if (thumb == itemId || (thumb != null && thumb!.startsWith('http'))) {
            return thumb; // has own 16:9 episode thumbnail
          }
          return seriesImageId ?? thumb; // no own thumbnail — match seriesPoster
        case EpisodePosterMode.seasonPoster:
          return seasonImageId ?? seriesImageId ?? thumb;
        case EpisodePosterMode.seriesPoster:
          return seriesImageId ?? thumb;
      }
    } else if (itemType == 'season') {
      // In mixed hub with episode thumbnail mode, use art/thumb (16:9)
      if (mixedHubContext && mode == EpisodePosterMode.episodeThumbnail) {
        return art ?? thumb;
      }
      // Otherwise use series poster (2:3)
      if (seriesImageId != null) {
        return seriesImageId!;
      }
    }

    // For movies/shows in mixed hub context with episode thumbnail mode, use art (16:9)
    if (mixedHubContext && mode == EpisodePosterMode.episodeThumbnail && (itemType == 'movie' || itemType == 'show')) {
      return art ?? thumb;
    }

    return thumb;
  }

  /// Returns the (path, tag) pair for the image [posterThumb] would pick.
  /// The tag is paired with the chosen path so callers can pass `tag=` to the
  /// Jellyfin Images API for cache-busting on metadata refresh.
  ({String? path, String? tag}) posterImage({
    EpisodePosterMode mode = EpisodePosterMode.seriesPoster,
    bool mixedHubContext = false,
  }) {
    final itemType = type.toLowerCase();

    if (itemType == 'episode') {
      switch (mode) {
        case EpisodePosterMode.episodeThumbnail:
          if (thumb == itemId || (thumb != null && thumb!.startsWith('http'))) {
            return (path: thumb, tag: thumbTag);
          }
          if (seriesImageId != null) return (path: seriesImageId, tag: seriesImageTag);
          return (path: thumb, tag: thumbTag);
        case EpisodePosterMode.seasonPoster:
          if (seasonImageId != null) return (path: seasonImageId, tag: seasonImageTag);
          if (seriesImageId != null) return (path: seriesImageId, tag: seriesImageTag);
          return (path: thumb, tag: thumbTag);
        case EpisodePosterMode.seriesPoster:
          if (seriesImageId != null) return (path: seriesImageId, tag: seriesImageTag);
          return (path: thumb, tag: thumbTag);
      }
    } else if (itemType == 'season') {
      if (mixedHubContext && mode == EpisodePosterMode.episodeThumbnail) {
        if (art != null) return (path: art, tag: artTag);
        return (path: thumb, tag: thumbTag);
      }
      if (seriesImageId != null) return (path: seriesImageId, tag: seriesImageTag);
    }

    if (mixedHubContext && mode == EpisodePosterMode.episodeThumbnail && (itemType == 'movie' || itemType == 'show')) {
      if (art != null) return (path: art, tag: artTag);
      return (path: thumb, tag: thumbTag);
    }

    return (path: thumb, tag: thumbTag);
  }

  /// Returns true if this item should use 16:9 aspect ratio.
  /// Episodes use 16:9 when in episodeThumbnail mode.
  /// Clips (trailers, extras) always use 16:9.
  /// Movies, shows, and seasons use 16:9 in mixed hub context with episodeThumbnail mode.
  bool usesWideAspectRatio(EpisodePosterMode mode, {bool mixedHubContext = false}) {
    final itemType = type.toLowerCase();
    // Clips (trailers, extras) are always 16:9
    if (itemType == 'clip') return true;
    if (itemType == 'episode' && mode == EpisodePosterMode.episodeThumbnail) {
      // Only use 16:9 when the item has its own thumbnail (thumb == itemId) or
      // a URL-based wide image (Backdrop/Thumb). Borrowed poster IDs (e.g.
      // SeriesId) are 2:3 and should not be stretched into a 16:9 card.
      return thumb == itemId || (thumb != null && thumb!.startsWith('http'));
    }
    // Movies, shows, and seasons use 16:9 in mixed hubs with episode thumbnail mode
    if (mixedHubContext &&
        mode == EpisodePosterMode.episodeThumbnail &&
        (itemType == 'movie' || itemType == 'show' || itemType == 'season')) {
      return true;
    }
    return false;
  }

  /// Returns true if this item has started but not finished playback
  /// Only applicable for individual items (movies, episodes)
  bool get hasActiveProgress {
    if (duration == null || resumePositionMs == null) return false;
    return resumePositionMs! > 0 && resumePositionMs! < duration!;
  }

  /// Unwatched count for shows/seasons: use server-provided value or leafCount - watchedEpisodeCount.
  int? get effectiveUnwatchedCount {
    if (unwatchedCount != null && unwatchedCount! > 0) return unwatchedCount;
    if (leafCount != null && watchedEpisodeCount != null && leafCount! > watchedEpisodeCount!) {
      return leafCount! - watchedEpisodeCount!;
    }
    return null;
  }

  // Helper to determine if content is watched
  bool get isWatched {
    // For series/seasons: unwatchedCount 0 or viewed >= total
    if (unwatchedCount != null) return unwatchedCount! == 0;
    if (leafCount != null && watchedEpisodeCount != null) {
      return watchedEpisodeCount! >= leafCount!;
    }

    // For individual items (movies, episodes), check playCount
    return playCount != null && playCount! > 0;
  }

  factory MediaMetadata.fromJson(Map<String, dynamic> json) =>
      _$MediaMetadataFromJson(kBlurArtwork ? _obfuscateJson(json) : json);

  static Map<String, dynamic> _obfuscateJson(Map<String, dynamic> json) {
    final copy = Map<String, dynamic>.from(json);
    for (final key in const ['title', 'summary', 'tagline', 'seriesTitle', 'seasonTitle', 'studio']) {
      if (copy[key] is String) copy[key] = obfuscateText(copy[key] as String);
    }
    return copy;
  }

  Map<String, dynamic> toJson() => _$MediaMetadataToJson(this);
}
