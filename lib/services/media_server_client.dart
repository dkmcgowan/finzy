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
import '../models/plex_metadata.dart';
import '../models/plex_playlist.dart';
import '../models/plex_sort.dart';
import '../models/plex_video_playback_data.dart';

/// Minimal abstraction for a media server client.
///
/// This is intentionally Plex-shaped for now so existing UI and models
/// continue to work. Future work can introduce more backend-agnostic
/// models while keeping this as the main surface for Plex/Jellyfin.
abstract class MediaServerClient {
  String get serverId;
  String? get serverName;

  /// True when this client is a Jellyfin server (affects UX e.g. library tabs).
  bool get isJellyfin => false;

  /// Base URL for the server (e.g. https://plex.example.com:32400 or https://jellyfin.example.com)
  String get baseUrl;

  /// Auth token for API requests (Plex token or Jellyfin access token)
  String? get token;

  /// Headers to send with playback/stream requests (e.g. X-Plex-Token or Authorization)
  Map<String, String> get requestHeaders;

  bool get isOfflineMode;
  void setOfflineMode(bool offline);

  Future<Map<String, dynamic>> getServerIdentity();

  /// Server machine identifier (Plex) or server id (Jellyfin). Used for play queue URIs etc.
  Future<String?> getMachineIdentifier();

  Future<List<PlexLibrary>> getLibraries();
  Future<List<PlexMetadata>> getLibraryContent(
    String sectionId, {
    int? start,
    int? size,
    Map<String, String>? filters,
    dynamic cancelToken,
  });

  Future<PlexMetadata?> getMetadataWithImages(String ratingKey);
  Future<Map<String, dynamic>> getMetadataWithImagesAndOnDeck(String ratingKey);

  Future<List<PlexMetadata>> getChildren(String ratingKey);
  Future<List<PlexMetadata>> getExtras(String ratingKey);
  Future<List<PlexMetadata>> getAllUnwatchedEpisodes(String showRatingKey);
  Future<List<PlexMetadata>> getUnwatchedEpisodesInSeason(String seasonRatingKey);

  String getThumbnailUrl(String? thumbPath);

  /// Optional HTTP headers for image requests (e.g. Jellyfin Authorization).
  /// When non-null, the image widget will send these with GET requests for artwork.
  Map<String, String>? get imageHttpHeaders => null;

  Future<bool> checkThumbnailsAvailable(int partId);

  Future<List<PlexChapter>> getChapters(String ratingKey);
  Future<List<PlexMarker>> getMarkers(String ratingKey);
  Future<PlaybackExtras> getPlaybackExtras(String ratingKey);

  Future<PlexVideoPlaybackData> getVideoPlaybackData(String ratingKey, {int mediaIndex = 0});
  Future<PlexFileInfo?> getFileInfo(String ratingKey);

  Future<void> markAsWatched(String ratingKey, {PlexMetadata? metadata});
  Future<void> markAsUnwatched(String ratingKey, {PlexMetadata? metadata});

  /// Toggle favorite for the item. [isCurrentlyFavorite] is the current state (needed for Jellyfin: POST to add, DELETE to remove).
  /// Returns new favorite state (true/false), or null if not supported (e.g. Plex).
  Future<bool?> toggleFavorite(String ratingKey, {bool? isCurrentlyFavorite}) async => null;
  Future<void> updateProgress(
    String ratingKey, {
    required int time,
    required String state,
    int? duration,
  });

  Future<void> removeFromOnDeck(String ratingKey);
  Future<bool> rateItem(String ratingKey, double rating);
  Future<bool> deleteMediaItem(String ratingKey);

  Future<List<PlexMetadata>> search(String query, {int limit = 10});
  Future<List<PlexMetadata>> getRecentlyAdded({int limit = 50});
  Future<List<PlexMetadata>> getOnDeck();
  Future<List<PlexMetadata>> getOnDeckForLibrary(String sectionId);

  Future<Map<String, dynamic>> getServerPreferences();
  Future<List<dynamic>> getSessions();

  Future<List<PlexFilter>> getLibraryFilters(String sectionId, {String? libraryType});
  Future<List<PlexFirstCharacter>> getFirstCharacters(
    String sectionId, {
    int? type,
    Map<String, String>? filters,
  });
  Future<List<PlexFilterValue>> getFilterValues(String filterKey);
  Future<List<PlexSort>> getLibrarySorts(String sectionId, {String? libraryType});

  Future<List<PlexHub>> getLibraryHubs(String sectionId, {int limit = 10});

  /// Movie recommendations by category (e.g. "Because you watched X"). Jellyfin only; Plex returns empty.
  Future<List<PlexHub>> getMovieRecommendations(String sectionId, {int categoryLimit = 10, int itemLimit = 12}) async =>
      [];

  Future<List<PlexHub>> getGlobalHubs({int limit = 10});
  Future<List<PlexMetadata>> getHubContent(String hubKey);

  Future<List<PlexMetadata>> getPlaylist(String playlistId);
  Future<List<PlexPlaylist>> getPlaylists({String playlistType = 'video', bool? smart});
  Future<PlexPlaylist?> getPlaylistMetadata(String playlistId);
  Future<PlexPlaylist?> createPlaylist({required String title, String? uri, int? playQueueId});
  Future<bool> deletePlaylist(String playlistId);
  Future<bool> addToPlaylist({required String playlistId, required String uri});
  Future<bool> removeFromPlaylist({required String playlistId, required String playlistItemId});
  Future<bool> movePlaylistItem({
    required String playlistId,
    required int playlistItemId,
    required int afterPlaylistItemId,
  });
  Future<bool> clearPlaylist(String playlistId);
  Future<bool> updatePlaylist({required String playlistId, String? title, String? summary});

  Future<List<PlexMetadata>> getLibraryCollections(String sectionId);

  /// All collections/box sets across libraries (Jellyfin only; Plex returns empty).
  /// Used when "Collections" is a top-level library.
  Future<List<PlexMetadata>> getGlobalCollections() async => [];

  /// Returns favorite items in the library (Jellyfin only; Plex returns empty).
  /// [start] and [limit] support pagination (Jellyfin); when [limit] is 0 all items are returned.
  Future<List<PlexMetadata>> getLibraryFavorites(String sectionId, {int start = 0, int limit = 0});
  Future<List<PlexMetadata>> getCollectionItems(String collectionId);
  Future<bool> deleteCollection(String sectionId, String collectionId);
  Future<String?> createCollection({
    required String sectionId,
    required String title,
    required String uri,
    int? type,
  });
  Future<bool> addToCollection({required String collectionId, required String uri});
  Future<bool> removeFromCollection({required String collectionId, required String itemId});

  Future<PlayQueueResponse?> createPlayQueue({
    String? uri,
    int? playlistID,
    required String type,
    String? key,
    int shuffle = 0,
    int repeat = 0,
    int continuous = 0,
  });
  Future<PlayQueueResponse?> getPlayQueue(
    int playQueueId, {
    String? center,
    int window = 50,
    int includeBefore = 1,
    int includeAfter = 1,
  });
  Future<PlayQueueResponse?> shufflePlayQueue(int playQueueId);
  Future<bool> clearPlayQueue(int playQueueId);
  Future<PlayQueueResponse?> createShowPlayQueue({
    required String showRatingKey,
    int shuffle = 0,
    String? startingEpisodeKey,
  });

  Future<List<PlexMetadata>> getLibraryFolders(String sectionId);
  Future<List<PlexMetadata>> getFolderChildren(String folderKey);
  Future<List<PlexPlaylist>> getLibraryPlaylists({String playlistType = 'video'});

  Future<void> scanLibrary(String sectionId);
  Future<void> refreshLibraryMetadata(String sectionId);
  Future<void> emptyLibraryTrash(String sectionId);
  Future<void> analyzeLibrary(String sectionId);

  Future<int> getLibraryTotalCount(String sectionId);
  Future<int> getLibraryEpisodeCount(String sectionId);
  Future<int> getWatchHistoryCount({DateTime? since});

  Future<List<LiveTvDvr>> getDvrs();
  Future<bool> hasDvr();
  Future<List<LiveTvChannel>> getEpgChannels({String? lineup});
  Future<List<LiveTvProgram>> getEpgGrid({int? beginsAt, int? endsAt});
  Future<List<LiveTvHubResult>> getLiveTvHubs({int count = 12});
  Future<bool> reloadGuide(String dvrKey);
  Future<List<PlexMetadata>> getLiveTvSessions();
  Future<List<LiveTvSubscription>> getSubscriptions();
  Future<LiveTvSubscription?> createSubscription({
    required String type,
    required int targetSectionID,
    required int targetLibrarySectionID,
    Map<String, String>? prefs,
    String? hint,
    String? uri,
  });
  Future<bool> deleteSubscription(String subscriptionId);
  Future<bool> editSubscription(String subscriptionId, Map<String, String> prefs);
  Future<List<ScheduledRecording>> getScheduledRecordings();
  Future<Map<String, dynamic>?> getSubscriptionTemplate(String guid);

  /// Build a server-specific metadata URI for playlists/collections (e.g. Plex server://… or Jellyfin item id).
  Future<String> buildMetadataUri(String ratingKey);

  /// Live TV: send timeline heartbeat to keep session alive. No-op on Jellyfin.
  Future<void> updateLiveTimeline({
    required String ratingKey,
    required String sessionPath,
    required String sessionIdentifier,
    required String state,
    required int time,
    required int duration,
    required int playbackTime,
  });

  /// Set per-media language preferences. No-op on Jellyfin (returns true).
  Future<bool> setMetadataPreferences(String ratingKey, {String? audioLanguage, String? subtitleLanguage});

  /// Select audio/subtitle streams for playback. No-op on Jellyfin (returns true).
  Future<bool> selectStreams(int partId, {int? audioStreamID, int? subtitleStreamID, bool allParts = true});

  /// Tune to a live TV channel (Plex). Returns null if not supported (e.g. Jellyfin).
  Future<({PlexMetadata metadata, String streamPath, String sessionIdentifier, String sessionPath})?> tuneChannel(
    String dvrKey,
    String channelKey,
  );
}

