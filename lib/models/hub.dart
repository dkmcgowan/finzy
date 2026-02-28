import '../widgets/optimized_image.dart' show kBlurArtwork, obfuscateText;
import 'media_metadata.dart';

/// Represents a hub/recommendation section (e.g., Trending Movies, Top Thrillers)
class Hub {
  final String hubKey;
  final String title;
  final String type;
  final String? hubIdentifier;
  final int size;
  final bool more;
  final List<MediaMetadata> items;

  // Multi-server support fields
  final String? serverId; // Server machine identifier
  final String? serverName; // Server display name

  Hub({
    required this.hubKey,
    required this.title,
    required this.type,
    this.hubIdentifier,
    required this.size,
    required this.more,
    required this.items,
    this.serverId,
    this.serverName,
  });

  factory Hub.fromJson(Map<String, dynamic> json) {
    final items = <MediaMetadata>[];
    final jsonItems = json['Items'] as List?;
    if (jsonItems != null) {
      for (final item in jsonItems) {
        try {
          items.add(MediaMetadata.fromJson(item as Map<String, dynamic>));
        } catch (_) {}
      }
    }

    return Hub(
      hubKey: json['key'] as String? ?? '',
      title: kBlurArtwork ? obfuscateText(json['title'] as String? ?? 'Unknown') : json['title'] as String? ?? 'Unknown',
      type: json['type'] as String? ?? 'hub',
      hubIdentifier: json['hubIdentifier'] as String?,
      size: (json['size'] as num?)?.toInt() ?? items.length,
      more: json['more'] == true || json['more'] == 1,
      items: items,
    );
  }
}
