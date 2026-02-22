class PlexFilter {
  final String filter;
  final String filterType;
  final String key;
  final String title;
  final String type;
  /// Optional group/category for UI (e.g. "Filters", "Features"). When null, no section header.
  final String? group;

  PlexFilter({
    required this.filter,
    required this.filterType,
    required this.key,
    required this.title,
    required this.type,
    this.group,
  });

  factory PlexFilter.fromJson(Map<String, dynamic> json) {
    return PlexFilter(
      filter: json['filter'] ?? '',
      filterType: json['filterType'] ?? 'string',
      key: json['key'] ?? '',
      title: json['title'] ?? '',
      type: json['type'] ?? 'filter',
      group: json['group'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'filter': filter,
      'filterType': filterType,
      'key': key,
      'title': title,
      'type': type,
      if (group != null) 'group': group,
    };
  }
}

class PlexFilterValue {
  final String key;
  final String title;
  final String? type;

  PlexFilterValue({required this.key, required this.title, this.type});

  factory PlexFilterValue.fromJson(Map<String, dynamic> json) {
    return PlexFilterValue(key: json['key'] ?? '', title: json['title'] ?? '', type: json['type']);
  }

  Map<String, dynamic> toJson() {
    return {'key': key, 'title': title, if (type != null) 'type': type};
  }
}
