/// Represents an EPG program entry (what's on a channel at a given time)
class LiveTvProgram {
  final String? key;
  final String? itemId;
  final String? guid;
  final String title;
  final String? summary;
  final String? type;
  final int? year;
  final int? beginsAt; // epoch seconds
  final int? endsAt; // epoch seconds
  final String? seriesTitle; // series name for episodes
  final String? seasonTitle; // season name
  final int? index; // episode number
  final int? parentIndex; // season number
  final String? thumb;
  final String? art;
  final String? channelIdentifier;
  final String? channelCallSign;
  final bool? live;
  final bool? premiere;

  LiveTvProgram({
    this.key,
    this.itemId,
    this.guid,
    required this.title,
    this.summary,
    this.type,
    this.year,
    this.beginsAt,
    this.endsAt,
    this.seriesTitle,
    this.seasonTitle,
    this.index,
    this.parentIndex,
    this.thumb,
    this.art,
    this.channelIdentifier,
    this.channelCallSign,
    this.live,
    this.premiere,
  });

  factory LiveTvProgram.fromJson(Map<String, dynamic> json) {
    // Grid endpoint nests timing/channel info inside Media[0] and Channel[0]
    final media = (json['Media'] as List?)?.firstOrNull as Map<String, dynamic>?;
    final channel = (json['Channel'] as List?)?.firstOrNull as Map<String, dynamic>?;

    return LiveTvProgram(
      key: json['key'] as String?,
      itemId: json['itemId'] as String?,
      guid: json['guid'] as String?,
      title: json['title'] as String? ?? 'Unknown Program',
      summary: json['summary'] as String?,
      type: json['type'] as String?,
      year: (json['year'] as num?)?.toInt(),
      beginsAt: (json['beginsAt'] as num?)?.toInt() ?? (media?['beginsAt'] as num?)?.toInt(),
      endsAt: (json['endsAt'] as num?)?.toInt() ?? (media?['endsAt'] as num?)?.toInt(),
      seriesTitle: json['seriesTitle'] as String?,
      seasonTitle: json['seasonTitle'] as String?,
      index: (json['index'] as num?)?.toInt(),
      parentIndex: (json['parentIndex'] as num?)?.toInt(),
      thumb: json['thumb'] as String? ?? json['seriesImageId'] as String?,
      art: json['art'] as String?,
      channelIdentifier:
          json['channelIdentifier'] as String? ?? media?['channelIdentifier']?.toString() ?? channel?['id']?.toString(),
      channelCallSign: json['channelCallSign'] as String? ?? media?['channelCallSign'] as String?,
      live: json['live'] == true || json['live'] == 1 || json['live'] == '1',
      premiere: json['premiere'] == true || json['premiere'] == 1 || json['premiere'] == '1',
    );
  }

  /// Start time as DateTime
  DateTime? get startTime => beginsAt != null ? DateTime.fromMillisecondsSinceEpoch(beginsAt! * 1000) : null;

  /// End time as DateTime
  DateTime? get endTime => endsAt != null ? DateTime.fromMillisecondsSinceEpoch(endsAt! * 1000) : null;

  /// Duration in minutes
  int get durationMinutes {
    if (beginsAt == null || endsAt == null) return 0;
    return ((endsAt! - beginsAt!) / 60).round();
  }

  /// Whether this program is currently airing
  bool get isCurrentlyAiring {
    if (beginsAt == null || endsAt == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now >= beginsAt! && now < endsAt!;
  }

  /// Progress through the program (0.0 to 1.0)
  double get progress {
    if (beginsAt == null || endsAt == null) return 0.0;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (now < beginsAt!) return 0.0;
    if (now >= endsAt!) return 1.0;
    return (now - beginsAt!) / (endsAt! - beginsAt!);
  }

  /// Display title including series info for episodes
  String get displayTitle {
    if (seriesTitle != null && index != null) {
      final seasonEpisode = parentIndex != null ? 'S${parentIndex}E$index' : 'E$index';
      return '$seriesTitle - $seasonEpisode - $title';
    }
    return title;
  }
}
