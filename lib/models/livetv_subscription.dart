/// Represents a Jellyfin SeriesTimer (recurring recording rule).
class LiveTvSubscription {
  final String key;
  final String title;
  final String? overview;
  final String? channelId;
  final String? channelName;
  final String? programId;
  final String? serverId;
  final bool recordNewOnly;
  final int keepUpTo;
  final int priority;
  final int prePaddingSeconds;
  final int postPaddingSeconds;
  final List<String> days;

  LiveTvSubscription({
    required this.key,
    required this.title,
    this.overview,
    this.channelId,
    this.channelName,
    this.programId,
    this.serverId,
    this.recordNewOnly = false,
    this.keepUpTo = 0,
    this.priority = 0,
    this.prePaddingSeconds = 0,
    this.postPaddingSeconds = 0,
    this.days = const [],
  });

  factory LiveTvSubscription.fromJellyfinJson(Map<String, dynamic> json, {String? serverId}) {
    final daysList = <String>[];
    if (json['Days'] != null) {
      for (final d in json['Days'] as List) {
        daysList.add(d.toString());
      }
    }

    return LiveTvSubscription(
      key: json['Id'] as String? ?? '',
      title: json['Name'] as String? ?? 'Unknown',
      overview: json['Overview'] as String?,
      channelId: json['ChannelId'] as String?,
      channelName: json['ChannelName'] as String?,
      programId: json['ProgramId'] as String?,
      serverId: serverId,
      recordNewOnly: json['RecordNewOnly'] as bool? ?? false,
      keepUpTo: (json['KeepUpTo'] as num?)?.toInt() ?? 0,
      priority: (json['Priority'] as num?)?.toInt() ?? 0,
      prePaddingSeconds: (json['PrePaddingSeconds'] as num?)?.toInt() ?? 0,
      postPaddingSeconds: (json['PostPaddingSeconds'] as num?)?.toInt() ?? 0,
      days: daysList,
    );
  }

  /// Convert to JSON for updating via POST /LiveTv/SeriesTimers/{id}
  Map<String, dynamic> toUpdateJson() {
    return {
      'Id': key,
      'Name': title,
      'RecordNewOnly': recordNewOnly,
      'KeepUpTo': keepUpTo,
      'Priority': priority,
      'PrePaddingSeconds': prePaddingSeconds,
      'PostPaddingSeconds': postPaddingSeconds,
      'Days': days,
      if (channelId != null) 'ChannelId': channelId,
    };
  }

  LiveTvSubscription copyWith({
    bool? recordNewOnly,
    int? keepUpTo,
    int? priority,
    int? prePaddingSeconds,
    int? postPaddingSeconds,
    List<String>? days,
  }) {
    return LiveTvSubscription(
      key: key,
      title: title,
      overview: overview,
      channelId: channelId,
      channelName: channelName,
      programId: programId,
      serverId: serverId,
      recordNewOnly: recordNewOnly ?? this.recordNewOnly,
      keepUpTo: keepUpTo ?? this.keepUpTo,
      priority: priority ?? this.priority,
      prePaddingSeconds: prePaddingSeconds ?? this.prePaddingSeconds,
      postPaddingSeconds: postPaddingSeconds ?? this.postPaddingSeconds,
      days: days ?? this.days,
    );
  }
}
