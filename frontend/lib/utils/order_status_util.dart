/// Normalizes backend order status strings for UI filtering.
String normalizeOrderStatus(String? status) {
  if (status == null || status.trim().isEmpty) return 'pending';
  final raw = status.trim().toLowerCase().replaceAll('-', '_');

  switch (raw) {
    case 'payment_pending':
      return 'placed';
    case 'payment_verified':
      return 'confirmed';
    case 'packing_started':
    case 'packed':
      return 'preparing';
    case 'rider_assigned':
    case 'rider_assigned_pending':
      return 'assigned';
    case 'rider_accepted':
    case 'accepted':
      return 'assigned';
    case 'on_the_way':
    case 'on_way':
      return 'out_for_delivery';
    case 'rider_nearby':
      return 'rider_nearby';
    case 'failed_delivery':
      return 'failed_delivery';
    case 'refunded':
      return 'cancelled';
    default:
      return raw;
  }
}

/// Total steps in the horizontal tracking stepper.
const int trackingStepCount = 6;

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
  return s == 'placed' ||
      s == 'pending' ||
      s == 'confirmed' ||
      s == 'accepted' ||
      s == 'preparing' ||
      s == 'packed' ||
      s == 'assigned' ||
      s == 'picked_up' ||
      s == 'out_for_delivery' ||
      s == 'on_way' ||
      s == 'rider_nearby';
}

/// Map index 0..5 for the 6-step horizontal stepper.
int resolveTrackingStepIndex(String status) {
  final s = normalizeOrderStatus(status);
  if (s == 'pending' || s == 'placed') return 0;
  if (s == 'confirmed') return 1;
  if (s == 'preparing' || s == 'packed') return 2;
  if (s == 'assigned' || s == 'picked_up') return 3;
  if (s == 'out_for_delivery' || s == 'on_way' || s == 'rider_nearby') {
    return 4;
  }
  if (s == 'delivered') return 5;
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
  if (s == 'delivered' || s == 'cancelled' || s == 'failed_delivery') {
    return false;
  }
  // Map-first UX: store → customer route for any active order with an address pin.
  if (hasDeliveryCoords) {
    return true;
  }
  if (hasRiderGps &&
      (s == 'out_for_delivery' ||
          s == 'on_way' ||
          s == 'rider_nearby' ||
          s == 'picked_up' ||
          s == 'assigned')) {
    return true;
  }
  return s == 'out_for_delivery' ||
      s == 'on_way' ||
      s == 'rider_nearby' ||
      s == 'picked_up';
}

/// Delivery OTP card visible during last-mile delivery.
bool isDeliveryOtpVisible(String status) {
  final s = normalizeOrderStatus(status);
  return s == 'out_for_delivery' || s == 'on_way' || s == 'rider_nearby';
}

/// Grace-period cancel: placed/confirmed within 60 seconds of order creation.
bool canCancelWithGrace(DateTime? createdAt, String status) {
  if (createdAt == null) return false;
  final s = normalizeOrderStatus(status);
  if (s != 'placed' && s != 'confirmed' && s != 'pending') return false;
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
    case 'placed':
    case 'pending':
      return 'Order placed';
    case 'confirmed':
      return 'Order confirmed';
    case 'preparing':
    case 'packed':
      return 'Preparing your order';
    case 'assigned':
    case 'picked_up':
      return 'Rider assigned';
    case 'out_for_delivery':
    case 'on_way':
      return 'On the way to you';
    case 'rider_nearby':
      return 'Rider is nearby';
    case 'delivered':
      return 'Delivered';
    case 'cancelled':
      return 'Order cancelled';
    default:
      return 'Tracking your order';
  }
}
