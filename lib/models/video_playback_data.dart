import 'media_info.dart';
import 'media_version.dart';

/// Consolidated data model containing all information needed for video playback.
/// This model combines data from multiple server API endpoints to reduce redundant requests.
class VideoPlaybackData {
  /// Direct video URL for playback
  final String? videoUrl;

  /// True when using TranscodingUrl (player reports position from stream start).
  final bool isTranscode;

  /// Media information including audio/subtitle tracks and chapters
  final MediaInfo? mediaInfo;

  /// Available media versions/qualities for this content
  final List<MediaVersion> availableVersions;

  /// Markers for intro/credits skip functionality
  final List<Marker> markers;

  /// Server-reported playback error (e.g. NoCompatibleStream) when PlaybackInfo returns ErrorCode
  final String? playbackErrorReason;

  /// PlaySessionId from PlaybackInfo; used for playback reporting (Start, Progress, Stopped).
  final String? playSessionId;

  /// MediaSourceId of the chosen source; used for playback reporting.
  final String? mediaSourceId;

  VideoPlaybackData({
    required this.videoUrl,
    this.isTranscode = false,
    required this.mediaInfo,
    required this.availableVersions,
    this.markers = const [],
    this.playbackErrorReason,
    this.playSessionId,
    this.mediaSourceId,
  });

  /// Returns true if this playback data has a valid video URL
  bool get hasValidVideoUrl => videoUrl != null && videoUrl!.isNotEmpty;

  /// Returns true if media info is available
  bool get hasMediaInfo => mediaInfo != null;

  /// Returns true if there are multiple media versions available
  bool get hasMultipleVersions => availableVersions.length > 1;
}
