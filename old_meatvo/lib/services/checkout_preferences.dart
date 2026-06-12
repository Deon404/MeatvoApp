import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/checkout/checkout_payment_methods.dart';

/// Persists the user's last checkout payment selection.
class CheckoutPreferences {
  CheckoutPreferences._();

  static const _prefKey = 'meatvo_checkout_payment_option';

  static Future<CheckoutPaymentOption> loadPaymentOption() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey)?.trim().toLowerCase();
    return switch (saved) {
      'online' => CheckoutPaymentOption.online,
      'cod' => CheckoutPaymentOption.cod,
      _ => CheckoutPaymentOption.cod,
    };
  }

  static Future<void> savePaymentOption(CheckoutPaymentOption option) async {
    final prefs = await SharedPreferences.getInstance();
    final value =
        option == CheckoutPaymentOption.cod ? 'cod' : 'online';
    await prefs.setString(_prefKey, value);
  }
}
