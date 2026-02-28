import 'dart:async';
import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/support_constants.dart';
import '../utils/app_logger.dart';

/// Handles support/tip payments: PayPal on desktop, IAP on iOS and Android.
class SupportService {
  SupportService._();
  static final SupportService instance = SupportService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  Completer<bool>? _purchaseCompleter;

  /// Whether the support section should be shown (we have a payment method available).
  bool get isAvailable {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return kPayPalMeUsername != null && kPayPalMeUsername!.isNotEmpty;
    }
    return Platform.isIOS || Platform.isAndroid;
  }

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  /// Start listening to purchase updates. Call from app startup on iOS/Android.
  void init() {
    if (!_isDesktop) {
      _purchaseSubscription = _iap.purchaseStream.listen(
        _onPurchaseUpdate,
        onDone: () => _purchaseSubscription?.cancel(),
        onError: (e) {
          appLogger.w('SupportService: purchase stream error', error: e);
          _purchaseCompleter?.complete(false);
        },
      );
    }
  }

  void dispose() {
    _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.error:
          appLogger.e('SupportService: purchase error', error: purchase.error);
          _purchaseCompleter?.complete(false);
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (purchase.pendingCompletePurchase) {
            _iap.completePurchase(purchase);
          }
          _purchaseCompleter?.complete(true);
          break;
        case PurchaseStatus.canceled:
          _purchaseCompleter?.complete(false);
          break;
      }
    }
  }

  /// Initiate a tip. On desktop opens PayPal; on mobile starts IAP flow.
  /// Returns true if the flow completed successfully, false on cancel/error.
  Future<bool> tip(SupportTier tier) async {
    if (_isDesktop) {
      return _launchPayPal(tier);
    }
    return _buyConsumable(tier);
  }

  Future<bool> _launchPayPal(SupportTier tier) async {
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

  Future<bool> _buyConsumable(SupportTier tier) async {
    try {
      final available = await _iap.isAvailable();
      if (!available) {
        appLogger.w('SupportService: IAP not available');
        return false;
      }

      final productIds = {tier.productId};
      final response = await _iap.queryProductDetails(productIds);

      if (response.notFoundIDs.isNotEmpty) {
        appLogger.w('SupportService: product not found: ${response.notFoundIDs}');
        return false;
      }

      final product = response.productDetails.firstWhere(
        (p) => p.id == tier.productId,
        orElse: () => throw StateError('Product ${tier.productId} not in response'),
      );

      _purchaseCompleter = Completer<bool>();
      await _iap.buyConsumable(purchaseParam: PurchaseParam(productDetails: product));
      return _purchaseCompleter!.future;
    } catch (e) {
      appLogger.e('SupportService: IAP failed', error: e);
      _purchaseCompleter?.complete(false);
      return false;
    }
  }
}
