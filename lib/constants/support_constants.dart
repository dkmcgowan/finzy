/// Constants for the Support Development (tips) feature.
///
/// Configure before release:
/// - [kPayPalMeUsername]: Your PayPal.Me username for desktop (Linux, Mac, Windows).
///   Set to null to hide the section on desktop.
/// - Product IDs in [SupportTier]: Create consumable products in App Store Connect
///   and Google Play Console.
library;

/// PayPal.Me username for desktop tips.
/// Example: 'johndoe' → https://paypal.me/johndoe/2.99
// ignore: unnecessary_nullable_for_final_variable_declarations nullable allows null to hide section
const String? kPayPalMeUsername = 'dkmcgowan';

enum SupportTier {
  coffee(2.99, 'finzy_tip_coffee'),
  lunch(9.99, 'finzy_tip_lunch'),
  support(19.99, 'finzy_tip_support');

  const SupportTier(this.amount, this.productId);
  final double amount;
  final String productId;
}
