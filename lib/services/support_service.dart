import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

import '../constants/support_constants.dart' show kPayPalMeUsername, kSupportPayPalUrl;
import '../utils/app_logger.dart';

/// Handles support/tip payments via PayPal on desktop (Windows, Mac, Linux).
class SupportService {
  SupportService._();
  static final SupportService instance = SupportService._();

  /// Whether the support section should be shown (PayPal configured on desktop).
  bool get isAvailable =>
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS) &&
      kPayPalMeUsername != null &&
      kPayPalMeUsername!.isNotEmpty;

  /// Open the support PayPal link in the browser.
  /// Returns true if the URL launched successfully, false otherwise.
  Future<bool> openSupportLink() async {
    if (!isAvailable) {
      appLogger.w('SupportService: PayPal not configured');
      return false;
    }
    try {
      final uri = Uri.parse(kSupportPayPalUrl);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      return launched;
    } catch (e) {
      appLogger.e('SupportService: failed to launch PayPal', error: e);
      return false;
    }
  }
}
