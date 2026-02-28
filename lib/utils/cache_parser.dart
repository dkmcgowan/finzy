/// Utility class for parsing API cache responses.
class CacheParser {
  CacheParser._();

  /// Extract the Items list from a cached response.
  static List<dynamic>? extractMetadataList(Map<String, dynamic>? cached) {
    if (cached == null) return null;
    return cached['Items'] as List?;
  }

  /// Extract the first item from a cached response.
  static Map<String, dynamic>? extractFirstMetadata(Map<String, dynamic>? cached) {
    final list = extractMetadataList(cached);
    if (list == null || list.isEmpty) return null;
    return list.first as Map<String, dynamic>;
  }

  /// Check if a cached response has valid items.
  static bool hasMetadata(Map<String, dynamic>? cached) {
    final list = extractMetadataList(cached);
    return list != null && list.isNotEmpty;
  }

  /// Extract Chapter list from the first item.
  static List<dynamic>? extractChapters(Map<String, dynamic>? cached) {
    final metadata = extractFirstMetadata(cached);
    if (metadata == null) return null;
    return metadata['Chapter'] as List?;
  }

  /// Extract Marker list from the first item.
  static List<dynamic>? extractMarkers(Map<String, dynamic>? cached) {
    final metadata = extractFirstMetadata(cached);
    if (metadata == null) return null;
    return metadata['Marker'] as List?;
  }
}
