/// Shared order pricing — uses admin-configured delivery fee when provided.
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
  static const double defaultDeliveryChargeAmount = 30;
  static const double defaultFreeDeliveryThreshold = 500;

  static OrderPricingBreakdown calculate({
    required double subtotal,
    double discount = 0,
    double? deliveryChargeAmount,
    double? freeDeliveryThreshold,
  }) {
    final double safeSubtotal = subtotal < 0 ? 0.0 : subtotal;
    final double safeDiscount = discount < 0 ? 0.0 : discount;
    final afterDiscount =
        (safeSubtotal - safeDiscount).clamp(0.0, double.infinity).toDouble();
    final deliveryFee =
        deliveryChargeAmount ?? defaultDeliveryChargeAmount;
    final threshold =
        freeDeliveryThreshold ?? defaultFreeDeliveryThreshold;
    final delivery = afterDiscount >= threshold ? 0.0 : deliveryFee;
    final grandTotal = afterDiscount + delivery;

    return OrderPricingBreakdown(
      subtotal: safeSubtotal,
      discount: safeDiscount,
      deliveryCharge: delivery,
      grandTotal: grandTotal,
    );
  }
}
