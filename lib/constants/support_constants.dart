/// Constants for the Support Development (tips) feature.
///
/// Configure before release:
/// - [kPayPalMeUsername]: Your PayPal.Me username for desktop (Linux, Mac, Windows).
///   Set to null to hide the section on desktop.
library;

/// PayPal.Me username for desktop tips.
/// Example: 'johndoe' → https://paypal.me/johndoe/2.99
// ignore: unnecessary_nullable_for_final_variable_declarations nullable allows null to hide section
const String? kPayPalMeUsername = 'dkmcgowan';

enum SupportTier {
  coffee(2.99),
  lunch(9.99),
  support(19.99);

  const SupportTier(this.amount);
  final double amount;
}
