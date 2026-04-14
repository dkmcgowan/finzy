import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Jellyfin user primary image with auth headers (switch profile, app bar).
class JellyfinProfileNetworkAvatar extends StatelessWidget {
  const JellyfinProfileNetworkAvatar({
    super.key,
    required this.userId,
    required this.imageUrl,
    required this.httpHeaders,
    required this.size,
    required this.placeholderIcon,
  });

  final String userId;
  final String imageUrl;
  final Map<String, String>? httpHeaders;
  final double size;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    final s = size;
    final iconSize = s * 0.67;
    return CachedNetworkImage(
      imageUrl: imageUrl,
      httpHeaders: httpHeaders,
      cacheKey: 'jfin_profile_${userId}_${Uri.tryParse(imageUrl)?.queryParameters['tag'] ?? 'notag'}',
      width: s,
      height: s,
      fit: BoxFit.cover,
      imageBuilder: (context, imageProvider) => Image(
        image: imageProvider,
        width: s,
        height: s,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      ),
      placeholder: (context, loadingProgress) => Icon(placeholderIcon, size: iconSize),
      errorWidget: (context, error, stackTrace) => Icon(placeholderIcon, size: iconSize),
    );
  }
}
