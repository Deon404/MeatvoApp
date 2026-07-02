import '../models/order_model.dart';
import 'order_status_util.dart';

String _rawOrderStatusKey(OrderModel order) =>
    order.status.trim().toLowerCase().replaceAll('-', '_');

/// Whether the gateway has marked this order as paid.
bool isOrderPaid(OrderModel order) {
  final paymentStatus = order.paymentStatus?.toLowerCase();
  return paymentStatus == 'paid' || paymentStatus == 'completed';
}

/// Online order cancelled because payment did not go through.
bool isPaymentFailed(OrderModel order) {
  if (order.paymentMethod != 'online') return false;
  return normalizeOrderStatus(order.status) == 'cancelled';
}

/// Online order created at checkout but payment not completed yet (retryable).
bool isOrderAwaitingPayment(OrderModel order) {
  if (order.paymentMethod != 'online') return false;
  if (isOrderPaid(order)) return false;
  if (isPaymentFailed(order)) return false;

  final rawStatus = _rawOrderStatusKey(order);
  return rawStatus == 'placed' ||
      rawStatus == 'pending' ||
      rawStatus == 'payment_pending';
}

/// Active delivery tracking (map, ETA, rider) — excludes unpaid online orders.
bool isOrderLiveForTracking(OrderModel order) {
  if (isOrderAwaitingPayment(order)) return false;
  if (isPaymentFailed(order)) return false;
  return isOrderActive(order.status);
}

/// Live map visibility for a full [OrderModel] (payment-aware).
bool shouldShowLiveMapForOrder(
  OrderModel order, {
  bool hasRiderGps = false,
  bool hasDeliveryCoords = false,
}) {
  if (isOrderAwaitingPayment(order)) return false;
  if (isPaymentFailed(order)) return false;
  return shouldShowLiveMap(
    order.status,
    hasRiderGps: hasRiderGps,
    hasDeliveryCoords: hasDeliveryCoords,
  );
}
