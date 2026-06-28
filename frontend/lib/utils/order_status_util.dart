/// Normalizes backend order status strings for customer UI.
///
/// Customers only see four steps:
///   Confirmed → Preparing → Out for Delivery → Delivered
///
/// Internal states (QC, Ready, Dispatch Queue, rider assignment, etc.)
/// are collapsed here and never shown as separate steps.
String normalizeOrderStatus(String? status) {
  if (status == null || status.trim().isEmpty) return 'confirmed';
  final raw = status.trim().toLowerCase().replaceAll('-', '_');

  switch (raw) {
    case 'payment_pending':
      return 'payment_pending';
    case 'payment_verified':
    case 'placed':
    case 'pending':
    case 'confirmed':
      return 'confirmed';
    case 'packing_started':
    case 'packed':
    case 'qc':
    case 'ready':
    case 'dispatch_queue':
    case 'batch_ready':
    case 'rider_assigned':
    case 'rider_assigned_pending':
    case 'rider_accepted':
    case 'accepted':
    case 'assigned':
    case 'picked_up':
      return 'preparing';
    case 'out_for_delivery':
    case 'on_the_way':
    case 'on_way':
    case 'rider_nearby':
      return 'out_for_delivery';
    case 'failed_delivery':
      return 'failed_delivery';
    case 'refunded':
      return 'cancelled';
    default:
      return raw;
  }
}

/// Customer-visible label for a normalized status key.
String customerStatusLabel(String? status) {
  final s = normalizeOrderStatus(status);
  switch (s) {
    case 'payment_pending':
      return 'Payment pending';
    case 'confirmed':
      return 'Confirmed';
    case 'preparing':
      return 'Preparing';
    case 'out_for_delivery':
      return 'Out for Delivery';
    case 'delivered':
      return 'Delivered';
    case 'failed_delivery':
      return 'Delivery Attempted';
    case 'cancelled':
      return 'Cancelled';
    default:
      return 'Confirmed';
  }
}

/// Total steps in the horizontal tracking stepper (customer-facing).
const int trackingStepCount = 4;

/// In-progress orders (not delivered or cancelled).
bool isOrderActive(String status) {
  final s = normalizeOrderStatus(status);
  return s != 'delivered' &&
      s != 'cancelled' &&
      s != 'failed_delivery';
}

bool isOrderCompleted(String status) =>
    normalizeOrderStatus(status) == 'delivered';

bool isOrderCancelled(String status) {
  final s = normalizeOrderStatus(status);
  return s == 'cancelled' || s == 'failed_delivery';
}

/// Whether the customer can track a live delivery for this order.
bool isOrderTrackable(String status) {
  final s = normalizeOrderStatus(status);
  if (s == 'payment_pending') return false;
  return s == 'confirmed' ||
      s == 'preparing' ||
      s == 'out_for_delivery';
}

/// Map index 0..3 for the 4-step horizontal stepper.
int resolveTrackingStepIndex(String status) {
  final s = normalizeOrderStatus(status);
  if (s == 'payment_pending') return 0;
  if (s == 'confirmed') return 0;
  if (s == 'preparing') return 1;
  if (s == 'out_for_delivery') return 2;
  if (s == 'delivered') return 3;
  return 0;
}

/// Progress fraction (0.0–1.0) for hero progress bar.
double trackingProgressFraction(String status) {
  final index = resolveTrackingStepIndex(status);
  if (normalizeOrderStatus(status) == 'delivered') return 1.0;
  return (index + 0.5) / trackingStepCount;
}

/// Show live map when delivery coordinates exist or rider is en route.
bool shouldShowLiveMap(
  String status, {
  bool hasRiderGps = false,
  bool hasDeliveryCoords = false,
}) {
  final s = normalizeOrderStatus(status);
  if (s == 'delivered' ||
      s == 'cancelled' ||
      s == 'failed_delivery' ||
      s == 'payment_pending') {
    return false;
  }
  if (hasDeliveryCoords) {
    return true;
  }
  if (hasRiderGps &&
      (s == 'out_for_delivery' || s == 'preparing')) {
    return true;
  }
  return s == 'out_for_delivery';
}

/// Delivery OTP card visible during last-mile delivery.
bool isDeliveryOtpVisible(String status) {
  return normalizeOrderStatus(status) == 'out_for_delivery';
}

/// Grace-period cancel: placed/confirmed within 60 seconds of order creation.
bool canCancelWithGrace(DateTime? createdAt, String status) {
  if (createdAt == null) return false;
  final s = normalizeOrderStatus(status);
  if (s != 'confirmed' && s != 'payment_pending') return false;
  final elapsed = DateTime.now().difference(createdAt).inSeconds;
  return elapsed <= 60;
}

/// Seconds remaining in the free-cancel grace window (0 if expired).
int cancelGraceSecondsRemaining(DateTime? createdAt, String status) {
  if (!canCancelWithGrace(createdAt, status)) return 0;
  final elapsed = DateTime.now().difference(createdAt!).inSeconds;
  return (60 - elapsed).clamp(0, 60);
}

/// Whether rider/partner section should show for active orders.
bool shouldShowPartnerSection(String status) {
  final s = normalizeOrderStatus(status);
  return s != 'delivered' && s != 'cancelled' && s != 'failed_delivery';
}

/// Notification-friendly status label for Android ongoing notification.
String trackingNotificationLabel(String status) {
  final s = normalizeOrderStatus(status);
  switch (s) {
    case 'payment_pending':
      return 'Payment pending';
    case 'confirmed':
      return 'Order confirmed';
    case 'preparing':
      return 'Preparing your order';
    case 'out_for_delivery':
      return 'Out for delivery';
    case 'delivered':
      return 'Delivered';
    case 'cancelled':
      return 'Order cancelled';
    default:
      return 'Tracking your order';
  }
}
