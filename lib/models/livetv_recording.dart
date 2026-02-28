/// Represents a completed Jellyfin Live TV recording.
class LiveTvRecording {
  final String id;
  final String title;
  final String? overview;
  final String? channelName;
  final String? status;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? imageTag;
  final String? serverId;

  /// For episodes
  final String? seriesName;
  final int? seasonNumber;
  final int? episodeNumber;

  LiveTvRecording({
    required this.id,
    required this.title,
    this.overview,
    this.channelName,
    this.status,
    this.startTime,
    this.endTime,
    this.imageTag,
    this.serverId,
    this.seriesName,
    this.seasonNumber,
    this.episodeNumber,
  });

  factory LiveTvRecording.fromJellyfinJson(Map<String, dynamic> json, {String? serverId}) {
    final startStr = json['StartDate'] as String?;
    final endStr = json['EndDate'] as String?;

    return LiveTvRecording(
      id: json['Id'] as String? ?? '',
      title: json['Name'] as String? ?? 'Unknown',
      overview: json['Overview'] as String?,
      channelName: json['ChannelName'] as String?,
      status: json['Status'] as String?,
      startTime: startStr != null ? DateTime.tryParse(startStr) : null,
      endTime: endStr != null ? DateTime.tryParse(endStr) : null,
      imageTag: json['ImageTags']?['Primary'] as String?,
      serverId: serverId,
      seriesName: json['SeriesName'] as String?,
      seasonNumber: (json['ParentIndexNumber'] as num?)?.toInt(),
      episodeNumber: (json['IndexNumber'] as num?)?.toInt(),
    );
  }

  int get durationMinutes {
    if (startTime == null || endTime == null) return 0;
    return endTime!.difference(startTime!).inMinutes;
  }

  String get displayTitle {
    if (seriesName != null && episodeNumber != null) {
      final se = seasonNumber != null ? 'S${seasonNumber}E$episodeNumber' : 'E$episodeNumber';
      return '$seriesName - $se - $title';
    }
    return title;
  }
}
