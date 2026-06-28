/// Shared customer support contact details.
abstract final class SupportConfig {
  static const phone = '+918092144650';
  static const email = 'support@meatvo.in';
  static const faqUrl = 'https://meatvo.in/faq';

  /// Human-readable phone for UI (E.164 dial string stays [phone]).
  static String get phoneDisplay {
    const digits = phone;
    if (digits.startsWith('+91') && digits.length == 13) {
      final local = digits.substring(3);
      return '+91 ${local.substring(0, 5)} ${local.substring(5)}';
    }
    return phone;
  }
}
