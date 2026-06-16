/// Shared order pricing — aligned with backend `orders.controller.js` createOrder logic.
class OrderPricingBreakdown {
  final double subtotal;
  final double discount;
  final double deliveryCharge;
  final double grandTotal;

  const OrderPricingBreakdown({
    required this.subtotal,
    this.discount = 0,
    required this.deliveryCharge,
    required this.grandTotal,
  });

  bool get isFreeDelivery => deliveryCharge <= 0;
}

abstract final class OrderPricingCalculator {
  /// Backend: delivery free when subtotal >= 500, else ₹40.
  static const double deliveryChargeAmount = 40;
  static const double freeDeliveryThreshold = 500;

  static OrderPricingBreakdown calculate({
    required double subtotal,
    double discount = 0,
  }) {
    final double safeSubtotal = subtotal < 0 ? 0.0 : subtotal;
    final double safeDiscount = discount < 0 ? 0.0 : discount;
    final afterDiscount =
        (safeSubtotal - safeDiscount).clamp(0.0, double.infinity).toDouble();
    final delivery = afterDiscount >= freeDeliveryThreshold
        ? 0.0
        : deliveryChargeAmount;
    final grandTotal = afterDiscount + delivery;

    return OrderPricingBreakdown(
      subtotal: safeSubtotal,
      discount: safeDiscount,
      deliveryCharge: delivery,
      grandTotal: grandTotal,
    );
  }
}
