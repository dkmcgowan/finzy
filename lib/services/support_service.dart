import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

import '../constants/support_constants.dart';
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

  /// Initiate a tip by opening PayPal.Me in the browser.
  /// Returns true if the URL launched successfully, false otherwise.
  Future<bool> tip(SupportTier tier) async {
    final username = kPayPalMeUsername;
    if (username == null || username.isEmpty) {
      appLogger.w('SupportService: PayPal username not configured');
      return false;
    }
    // PayPal.Me format: https://paypal.me/username/amount (no currency = USD)
    final amountStr = tier.amount.toStringAsFixed(2);
    final uri = Uri.parse('https://paypal.me/$username/$amountStr');
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      return launched;
    } catch (e) {
      appLogger.e('SupportService: failed to launch PayPal', error: e);
      return false;
    }
  }
}
