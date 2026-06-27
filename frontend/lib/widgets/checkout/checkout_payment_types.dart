/// Checkout payment option enums shared across sheets and screens.
enum CheckoutPaymentOption { online, cod }

extension CheckoutPaymentOptionX on CheckoutPaymentOption {
  String get backendValue =>
      this == CheckoutPaymentOption.cod ? 'COD' : 'ONLINE';

  String get label => switch (this) {
        CheckoutPaymentOption.online => 'Pay Online',
        CheckoutPaymentOption.cod => 'Cash on Delivery',
      };

  /// Short label shown in the PAY VIA footer pill.
  String get footerLabel => switch (this) {
        CheckoutPaymentOption.online => 'Online',
        CheckoutPaymentOption.cod => 'Cash on Delivery',
      };

  String get subtitle => switch (this) {
        CheckoutPaymentOption.online => 'UPI, cards & wallets via Cashfree',
        CheckoutPaymentOption.cod => 'Pay when your order arrives',
      };
}

/// User's UPI quick-pay selection on checkout.
enum CheckoutUpiSelection {
  nativePicker,
  installedApp,
  webCheckout,
}
