import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Passive check for newer versions on GitHub.
/// No dialogs, no skip-version, no cooldowns — the About screen calls this
/// on demand and just displays the result.
class UpdateService {
  static final Logger _logger = Logger();
  static const String _githubRepo = 'dkmcgowan/finzy';

  /// Hits the GitHub releases API and reports whether a newer version exists.
  /// Returns null on network/parse error.
  static Future<UpdateCheckResult?> checkForUpdates() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final dio = Dio();
      final response = await dio.get(
        'https://api.github.com/repos/$_githubRepo/releases/latest',
        options: Options(headers: {'Accept': 'application/vnd.github+json'}),
      );

      if (response.statusCode != 200) return null;

      final data = response.data;
      final tag = data['tag_name'] as String;
      final latestVersion = tag.startsWith('v') ? tag.substring(1) : tag;
      final hasUpdate = _isNewerVersion(latestVersion, currentVersion);

      return UpdateCheckResult(currentVersion: currentVersion, latestVersion: latestVersion, hasUpdate: hasUpdate);
    } catch (e) {
      _logger.e('Failed to check for updates: $e');
      return null;
    }
  }

  static List<int> _parseVersionParts(String version) {
    return version.split('.').map((p) {
      final numPart = p.split('+').first.split('-').first;
      return int.tryParse(numPart) ?? 0;
    }).toList();
  }

  static bool _isNewerVersion(String newVersion, String currentVersion) {
    try {
      final newParts = _parseVersionParts(newVersion);
      final currentParts = _parseVersionParts(currentVersion);
      final maxLength = newParts.length > currentParts.length ? newParts.length : currentParts.length;

      for (int i = 0; i < maxLength; i++) {
        final newPart = i < newParts.length ? newParts[i] : 0;
        final currentPart = i < currentParts.length ? currentParts[i] : 0;
        if (newPart > currentPart) return true;
        if (newPart < currentPart) return false;
      }
      return false;
    } catch (e) {
      _logger.e('Error comparing versions: $e');
      return false;
    }
  }
}

class UpdateCheckResult {
  final String currentVersion;
  final String latestVersion;
  final bool hasUpdate;

  const UpdateCheckResult({required this.currentVersion, required this.latestVersion, required this.hasUpdate});
}
