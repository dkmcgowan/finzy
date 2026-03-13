/// Constants for the Support Development feature.
///
/// Configure before release:
/// - [kPayPalMeUsername]: Your PayPal.Me username for desktop (Linux, Mac, Windows).
///   Set to null to hide the section on desktop.
library;

/// PayPal.Me username for desktop support link.
/// Set to null to hide the section on desktop.
// ignore: unnecessary_nullable_for_final_variable_declarations nullable allows null to hide section
const String? kPayPalMeUsername = 'dkmcgowan';

/// Full PayPal.Me URL for support development (no amount).
const String kSupportPayPalUrl = 'https://www.paypal.com/paypalme/dkmcgowan';
