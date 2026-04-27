import 'dart:math';
import 'package:flutter/widgets.dart';
import '../services/jellyfin_client.dart';
import '../services/settings_service.dart';

/// Image types for different transcoding strategies
enum ImageType {
  poster, // 2:3 ratio posters
  art, // Wide background art
  thumb, // 16:9 episode thumbnails
  logo, // Variable ratio clear logos
  avatar, // Square-ish user avatars
}

class MediaImageHelper {
  static const int _widthRoundingFactor = 40;
  static const int _heightRoundingFactor = 60;

  static const int _maxTranscodedWidth = 1920;
  static const int _maxTranscodedHeight = 1080;

  static const int _minTranscodedWidth = 160;
  static const int _minTranscodedHeight = 240;

  /// Rounds dimensions to cache-friendly values to increase cache hit rate
  static (int width, int height) roundDimensions(double width, double height) {
    final roundedWidth = (width / _widthRoundingFactor).ceil() * _widthRoundingFactor;
    final roundedHeight = (height / _heightRoundingFactor).ceil() * _heightRoundingFactor;

    return (
      roundedWidth.clamp(_minTranscodedWidth, _maxTranscodedWidth),
      roundedHeight.clamp(_minTranscodedHeight, _maxTranscodedHeight),
    );
  }

  /// Computes an effective device pixel ratio that accounts for displays where
  /// the platform-reported DPR doesn't reflect the true physical density
  /// (common on Linux X11 with compositor scaling).
  /// When [performanceProfile] is [PerformanceProfile.small], returns 1.0 for faster loading.
  static double effectiveDevicePixelRatio(BuildContext context, {PerformanceProfile? performanceProfile}) {
    if (performanceProfile == PerformanceProfile.small) {
      return 1.0;
    }
    final reportedDpr = MediaQuery.of(context).devicePixelRatio;
    try {
      final displayWidth = View.of(context).display.size.width;
      // Scale quality with display resolution: 1920px = baseline (1.0x)
      final displayBasedDpr = (displayWidth / 1920).clamp(1.0, 3.0);
      return max(reportedDpr, displayBasedDpr);
    } catch (_) {
      return reportedDpr;
    }
  }

  /// Calculates optimal image dimensions based on image type and constraints
  static (int width, int height) calculateOptimalDimensions({
    required double maxWidth,
    required double maxHeight,
    required double devicePixelRatio,
    ImageType imageType = ImageType.poster,
  }) {
    final targetWidth = maxWidth.isFinite ? maxWidth * devicePixelRatio : 300 * devicePixelRatio;
    final targetHeight = maxHeight.isFinite ? maxHeight * devicePixelRatio : 450 * devicePixelRatio;

    switch (imageType) {
      case ImageType.art:
        // For art/background images, preserve aspect ratio while covering container
        // Calculate dimensions that ensure the image covers the container without stretching
        // This mimics BoxFit.cover behavior for the transcoding request

        // Use larger dimensions to ensure coverage while preserving aspect ratio
        // This will request a slightly larger image that can be cropped by Flutter's BoxFit.cover
        final coverWidth = targetWidth * 1.1; // 10% larger for better coverage
        final coverHeight = targetHeight * 1.1;

        return roundDimensions(coverWidth, coverHeight);

      case ImageType.logo:
        // For logos, use generous bounds to avoid forcing aspect ratio
        // Prefer width-based scaling for most logos
        final logoWidth = targetWidth;
        final logoHeight = targetHeight; // Allow full height flexibility
        return roundDimensions(logoWidth, logoHeight);

      case ImageType.thumb:
        // For episode thumbs, optimize for 16:9 but allow flexibility
        final thumbHeight = targetHeight;
        final thumbWidth = min(targetWidth, thumbHeight * (16 / 9));
        return roundDimensions(thumbWidth, thumbHeight);

      case ImageType.avatar:
        // For avatars, use square dimensions based on smaller constraint
        final size = min(targetWidth, targetHeight);
        return roundDimensions(size, size);

      case ImageType.poster:
        // For posters, maintain 2:3 aspect ratio (width:height)
        final calculatedWidth = min(targetWidth, targetHeight * (2 / 3));
        final calculatedHeight = calculatedWidth * (3 / 2);
        return roundDimensions(calculatedWidth, calculatedHeight);
    }
  }

  /// Builds a Jellyfin image URL with resize parameters.
  ///
  /// Uses `fillWidth`/`fillHeight` (Jellyfin 10.7+) so the server returns an
  /// image large enough to *cover* the requested dimensions, matching
  /// jellyfin-web behaviour. A generous `maxWidth` cap prevents the server
  /// from returning excessively large images on older versions that ignore
  /// the fill parameters.
  static String buildImageUrl({
    required JellyfinClient client,
    required String itemId,
    required int width,
    int? height,
    String imageType = 'Primary',
    int quality = 90,
    String? tag,
    bool preserveAspect = false,
  }) {
    final baseUrl = client.baseUrl;
    final token = client.token;

    // `tag` is the Jellyfin image content hash. Including it makes the URL
    // change after a server-side metadata refresh so cached_network_image
    // (and any HTTP cache in front) fetches the new bytes instead of serving
    // the stale file. Mirrors jellyfin-web cardbuilder/utils/url.ts.
    //
    // `preserveAspect`: when true, omit fillWidth/fillHeight (which make the
    // server crop/scale to fill the box) and use maxWidth only. The server
    // returns an image at its native aspect ratio, capped at maxWidth. Use
    // this for variable-aspect content like channel logos that shouldn't be
    // forced into a 2:3 poster shape.
    final params = <String, String>{
      if (!preserveAspect) 'fillWidth': width.toString(),
      if (!preserveAspect && height != null) 'fillHeight': height.toString(),
      'maxWidth': (width * 2).clamp(width, _maxTranscodedWidth).toString(),
      'quality': quality.toString(),
      if (tag != null && tag.isNotEmpty) 'tag': tag,
      if (token != null && token.isNotEmpty) 'ApiKey': token,
    };

    final queryString = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');

    return '$baseUrl/Items/$itemId/Images/$imageType?$queryString';
  }

  /// Creates an optimized image URL for server content
  /// Falls back to original URL if transcoding is not appropriate
  /// If client is null (offline mode), returns empty string for relative paths
  /// When [performanceProfile] is [PerformanceProfile.small], uses quality 75 for faster loading.
  static String getOptimizedImageUrl({
    JellyfinClient? client,
    required String? thumbPath,
    required double maxWidth,
    required double maxHeight,
    required double devicePixelRatio,
    bool enableTranscoding = true,
    ImageType imageType = ImageType.poster,
    PerformanceProfile? performanceProfile,
    String? tag,
    bool preserveAspect = false,
  }) {
    if (thumbPath == null || thumbPath.isEmpty) {
      return '';
    }

    final basePath = thumbPath;

    // External URLs (e.g. EPG provider images, or `_recordingToMetadata`'s
    // pre-built Backdrop/Thumb URLs that already include their own `tag=`)
    // — use directly without re-wrapping.
    if (basePath.startsWith('http://') || basePath.startsWith('https://')) {
      return basePath;
    }

    // If no client (offline mode), we can't build URLs for relative paths
    // Images should already be cached from when they were originally loaded
    if (client == null) {
      return '';
    }

    final canTranscode = enableTranscoding && shouldTranscode(basePath);

    // If marked non-transcodable or transcoding disabled, use the direct thumbnail URL.
    if (!canTranscode) {
      return client.getThumbnailUrl(basePath, tag: tag);
    }

    // For very small images use original URL
    if (maxWidth < 80 || maxHeight < 120) {
      return client.getThumbnailUrl(basePath, tag: tag);
    }

    // Calculate optimal dimensions
    final (width, height) = calculateOptimalDimensions(
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      devicePixelRatio: devicePixelRatio,
      imageType: imageType,
    );

    // For dimensions close to minimum, use original to avoid unnecessary processing
    if (width <= _minTranscodedWidth * 1.2 && height <= _minTranscodedHeight * 1.2) {
      return client.getThumbnailUrl(basePath, tag: tag);
    }

    try {
      final quality = performanceProfile == PerformanceProfile.small ? 75 : 90;
      return buildImageUrl(
        client: client,
        itemId: basePath,
        width: width,
        height: height,
        imageType: _jellyfinApiImageType(imageType),
        quality: quality,
        tag: tag,
        preserveAspect: preserveAspect,
      );
    } catch (e) {
      return client.getThumbnailUrl(basePath, tag: tag);
    }
  }

  /// Generates cache-friendly dimensions for memory caching
  /// When [performanceProfile] is [PerformanceProfile.small], uses lower caps (600×900) for less memory.
  static (int memWidth, int memHeight) getMemCacheDimensions({
    required int displayWidth,
    required int displayHeight,
    double scaleFactor = 1.0,
    PerformanceProfile? performanceProfile,
  }) {
    final scaledWidth = (displayWidth * scaleFactor).round();
    final scaledHeight = (displayHeight * scaleFactor).round();
    final (maxW, maxH) = performanceProfile == PerformanceProfile.small ? (600, 900) : (1200, 1800);

    return (scaledWidth.clamp(120, maxW), scaledHeight.clamp(180, maxH));
  }

  /// Determines if an image path is suitable for resizing via the Jellyfin Images API.
  /// Jellyfin item IDs (GUIDs or 32-char hex) can be resized; external URLs cannot.
  static bool shouldTranscode(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return false;

    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return false;
    }

    // Already a full Jellyfin image URL
    if (imagePath.contains('/Items/') && imagePath.contains('/Images/')) {
      return false;
    }

    // Jellyfin item IDs (GUIDs or 32-char hex) are valid for resizing
    if (!imagePath.contains('/')) {
      return _looksLikeGuid(imagePath) || _looksLikeJellyfinIdOrTag(imagePath);
    }

    return false;
  }

  static bool _looksLikeGuid(String s) {
    if (s.length < 30) return false;
    final parts = s.split('-');
    return parts.length == 5 &&
        parts.first.length == 8 &&
        parts[1].length == 4 &&
        parts[2].length == 4 &&
        parts[3].length == 4 &&
        parts[4].length == 12;
  }

  /// Jellyfin item IDs or image tags can be 32-char hex (no hyphens).
  static bool _looksLikeJellyfinIdOrTag(String s) {
    if (s.length != 32) return false;
    return s.split('').every((c) => '0123456789abcdefABCDEF'.contains(c));
  }

  /// Maps the internal [ImageType] enum to the Jellyfin API image type
  /// path segment (Primary, Backdrop, Logo, etc.).
  static String _jellyfinApiImageType(ImageType type) {
    switch (type) {
      case ImageType.art:
        return 'Backdrop';
      case ImageType.logo:
        return 'Logo';
      case ImageType.poster:
      case ImageType.thumb:
      case ImageType.avatar:
        return 'Primary';
    }
  }

  /// Creates a consistent cache key for rounded dimensions
  static String generateCacheKey({
    required String originalPath,
    required int width,
    required int height,
    String? serverId,
  }) {
    final serverPrefix = serverId != null ? '${serverId}_' : '';
    return '${serverPrefix}transcode_${width}x${height}_${originalPath.hashCode}';
  }
}
