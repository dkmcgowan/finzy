import '../utils/codec_utils.dart';

class MediaInfo {
  final String videoUrl;
  final List<MediaAudioTrack> audioTracks;
  final List<MediaSubtitleTrack> subtitleTracks;
  final List<Chapter> chapters;
  final int? partId;

  MediaInfo({
    required this.videoUrl,
    required this.audioTracks,
    required this.subtitleTracks,
    required this.chapters,
    this.partId,
  });
  int? getPartId() => partId;
}

/// Builds a track label from parts with the standard `' · '` joiner pattern.
///
/// Shared by both server track models and MPV track label utilities.
/// If [title] is non-empty it is added first, then [language], then [extraParts].
/// Falls back to `'$fallbackPrefix ${index + 1}'` when no parts are available.
String buildTrackLabel({
  String? title,
  String? language,
  List<String> extraParts = const [],
  required int index,
  String fallbackPrefix = 'Track',
}) {
  final parts = <String>[];
  if (title != null && title.isNotEmpty) parts.add(title);
  if (language != null && language.isNotEmpty) parts.add(language);
  parts.addAll(extraParts);
  return parts.isEmpty ? '$fallbackPrefix ${index + 1}' : parts.join(' · ');
}

/// Mixin for building track labels with a consistent pattern
mixin TrackLabelBuilder {
  int get id;
  int? get index;
  String? get displayTitle;
  String? get language;

  /// Builds a label from the given parts
  /// If displayTitle is present, returns it
  /// Otherwise, combines language and additional parts
  String buildLabel(List<String> additionalParts) {
    if (displayTitle != null && displayTitle!.isNotEmpty) {
      return displayTitle!;
    }
    return buildTrackLabel(language: language, extraParts: additionalParts, index: (index ?? id) - 1);
  }
}

class MediaAudioTrack with TrackLabelBuilder {
  @override
  final int id;
  @override
  final int? index;
  final String? codec;
  @override
  final String? language;
  final String? languageCode;
  final String? title;
  @override
  final String? displayTitle;
  final int? channels;
  final bool selected;

  MediaAudioTrack({
    required this.id,
    this.index,
    this.codec,
    this.language,
    this.languageCode,
    this.title,
    this.displayTitle,
    this.channels,
    required this.selected,
  });

  String get label {
    final additionalParts = <String>[];
    if (codec != null) additionalParts.add(CodecUtils.formatAudioCodec(codec!));
    if (channels != null) additionalParts.add('${channels!}ch');
    return buildLabel(additionalParts);
  }
}

class MediaSubtitleTrack with TrackLabelBuilder {
  @override
  final int id;
  @override
  final int? index;
  final String? codec;
  @override
  final String? language;
  final String? languageCode;
  final String? title;
  @override
  final String? displayTitle;
  final bool selected;
  final bool forced;
  final String? key;

  /// Server-provided URL (relative path like /Videos/.../Stream.srt).
  /// When present, use this instead of building from key (jellyfin-web parity).
  final String? deliveryUrl;

  MediaSubtitleTrack({
    required this.id,
    this.index,
    this.codec,
    this.language,
    this.languageCode,
    this.title,
    this.displayTitle,
    required this.selected,
    required this.forced,
    this.key,
    this.deliveryUrl,
  });

  String get label {
    final additionalParts = <String>[];
    if (forced) additionalParts.add('Forced');
    return buildLabel(additionalParts);
  }

  /// Returns true if this subtitle track can be fetched (has key or deliveryUrl)
  bool get isExternal => (key != null && key!.isNotEmpty) || (deliveryUrl != null && deliveryUrl!.isNotEmpty);

  /// Constructs the full URL for fetching external subtitle files
  /// Returns null if this is not an external subtitle.
  ///
  /// When [forceTextFormat] is true and the source codec is image-based (PGS/DVD/DVB),
  /// the URL extension is rewritten to `.srt` so the server OCRs to text. Use on
  /// ExoPlayer (Android) where image-based subtitles cannot be decoded.
  String? getSubtitleUrl(String baseUrl, String token, {bool forceTextFormat = false}) {
    if (!isExternal) return null;

    final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final auth = 'ApiKey=${Uri.encodeComponent(token)}';
    final shouldForceText = forceTextFormat && CodecUtils.isImageBasedSubtitleCodec(codec);

    // Prefer server DeliveryUrl when available (correct format, jellyfin-web parity)
    final url = deliveryUrl;
    if (url != null && url.isNotEmpty) {
      final effective = shouldForceText ? _replacePathExtension(url, 'srt') : url;
      // Already absolute URL (IsExternalUrl case)
      if (effective.contains('://')) {
        final separator = effective.contains('?') ? '&' : '?';
        return '$effective$separator$auth';
      }
      final path = effective.startsWith('/') ? effective : '/$effective';
      final separator = path.contains('?') ? '&' : '?';
      return '$base${path.substring(1)}$separator$auth';
    }

    // Fallback: build from key. getSubtitleExtension already maps PGS/DVD → 'srt'.
    final ext = CodecUtils.getSubtitleExtension(codec);
    return '$base$key.$ext?$auth';
  }

  /// Rewrite the extension of a URL path (preserving query string).
  /// e.g. `/Videos/x/y/Subtitles/0/0/Stream.pgssub?foo=bar` → `.../Stream.srt?foo=bar`
  static String _replacePathExtension(String url, String newExt) {
    final queryIdx = url.indexOf('?');
    final pathPart = queryIdx >= 0 ? url.substring(0, queryIdx) : url;
    final queryPart = queryIdx >= 0 ? url.substring(queryIdx) : '';
    final lastDot = pathPart.lastIndexOf('.');
    final lastSlash = pathPart.lastIndexOf('/');
    if (lastDot < 0 || lastDot < lastSlash) return url;
    return '${pathPart.substring(0, lastDot)}.$newExt$queryPart';
  }
}

class Chapter {
  final int id;
  final int? index;
  final int? startTimeOffset;
  final int? endTimeOffset;
  final String? title;
  final String? thumb;

  Chapter({required this.id, this.index, this.startTimeOffset, this.endTimeOffset, this.title, this.thumb});

  String get label => title ?? 'Chapter ${(index ?? 0) + 1}';

  Duration get startTime => Duration(milliseconds: startTimeOffset ?? 0);
  Duration? get endTime => endTimeOffset != null ? Duration(milliseconds: endTimeOffset!) : null;
}

class Marker {
  final int id;
  final String type; // 'intro', 'outro', 'recap', 'preview', 'commercial'
  final int startTimeOffset;
  final int endTimeOffset;

  Marker({required this.id, required this.type, required this.startTimeOffset, required this.endTimeOffset});

  Duration get startTime => Duration(milliseconds: startTimeOffset);
  Duration get endTime => Duration(milliseconds: endTimeOffset);

  bool get isIntro => type == 'intro';
  bool get isOutro => type == 'outro';
  bool get isRecap => type == 'recap';
  bool get isPreview => type == 'preview';
  bool get isCommercial => type == 'commercial';

  /// Whether this segment should trigger "Next Episode" instead of skip
  bool get triggersNextEpisode => isOutro;

  bool containsPosition(Duration position) {
    final posMs = position.inMilliseconds;
    return posMs >= startTimeOffset && posMs <= endTimeOffset;
  }
}

/// Combined chapters and markers fetched in a single API call
class PlaybackExtras {
  final List<Chapter> chapters;
  final List<Marker> markers;

  PlaybackExtras({required this.chapters, required this.markers});
}
