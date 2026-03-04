import 'dart:io';

import 'package:flutter/material.dart';
import 'package:finzy/widgets/app_icon.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../i18n/strings.g.dart';
import '../utils/app_logger.dart';

/// Extracts YouTube video ID from common URL formats.
/// Returns null if the URL is not a recognized YouTube URL.
String? extractYouTubeVideoId(String url) {
  if (url.isEmpty) return null;
  final uri = Uri.tryParse(url);
  if (uri == null) {
    appLogger.d('Trailer: extractYouTubeVideoId failed to parse URL: "$url"');
    return null;
  }

  // youtu.be/VIDEO_ID
  if (uri.host == 'youtu.be') {
    final path = uri.pathSegments;
    if (path.isNotEmpty) return path.first;
    return null;
  }

  // youtube.com, www.youtube.com, youtube-nocookie.com (privacy-enhanced)
  if (uri.host == 'youtube.com' ||
      uri.host == 'www.youtube.com' ||
      uri.host == 'youtube-nocookie.com' ||
      uri.host == 'www.youtube-nocookie.com') {
    return uri.queryParameters['v'];
  }

  // m.youtube.com (mobile)
  if (uri.host == 'm.youtube.com') {
    return uri.queryParameters['v'];
  }

  appLogger.d('Trailer: URL host "${uri.host}" not recognized as YouTube');
  return null;
}

/// Returns true if the URL is a YouTube URL we can embed.
bool isYouTubeUrl(String url) {
  return extractYouTubeVideoId(url) != null;
}

/// Full-screen overlay that plays a YouTube trailer in-app.
/// Uses youtube_player_iframe for embedded playback (no external app/browser).
class TrailerPlayerOverlay extends StatefulWidget {
  final String videoId;
  final String? title;

  const TrailerPlayerOverlay({
    super.key,
    required this.videoId,
    this.title,
  });

  @override
  State<TrailerPlayerOverlay> createState() => _TrailerPlayerOverlayState();
}

class _TrailerPlayerOverlayState extends State<TrailerPlayerOverlay> {
  late final YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        mute: false,
        showControls: true,
        showFullscreenButton: true,
        loop: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: YoutubePlayerScaffold(
                  controller: _controller,
                  aspectRatio: 16 / 9,
                  builder: (context, player) => player,
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton.filled(
                onPressed: () => Navigator.of(context).pop(),
                icon: const AppIcon(Symbols.close_rounded, fill: 1),
                tooltip: t.common.close,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the trailer overlay for YouTube URLs, or returns false if not a YouTube URL.
/// On unsupported platforms (Windows/Linux where webview may not work), falls back to launchUrl.
Future<bool> showTrailerOverlayIfYouTube(
  BuildContext context, {
  required String url,
  String? title,
}) async {
  appLogger.d('Trailer: showTrailerOverlayIfYouTube url="$url"');
  final videoId = extractYouTubeVideoId(url);
  if (videoId == null) {
    appLogger.d('Trailer: extractYouTubeVideoId returned null, not a YouTube URL');
    return false;
  }
  appLogger.d('Trailer: extracted videoId="$videoId"');

  // webview_flutter only has Android (webview_flutter_android) and iOS/macOS (webview_flutter_wkwebview).
  // No Windows/Linux implementation - WebViewPlatform.instance is null, causes assertion crash.
  if (!_isYoutubePlayerSupported()) {
    appLogger.d('Trailer: overlay not supported on ${_platformName()}, skipping');
    return false;
  }

  if (!context.mounted) return true;
  appLogger.d('Trailer: pushing TrailerPlayerOverlay (platform: ${_platformName()})');
  try {
    await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => TrailerPlayerOverlay(
        videoId: videoId,
        title: title,
      ),
      fullscreenDialog: true,
    ),
  );
    return true;
  } catch (e, st) {
    appLogger.w('Trailer: overlay failed, falling back to external browser', error: e, stackTrace: st);
    return false;
  }
}

bool _isYoutubePlayerSupported() {
  if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) return true;
  return false;
}

String _platformName() {
  try {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
  } catch (_) {}
  return 'unknown';
}
