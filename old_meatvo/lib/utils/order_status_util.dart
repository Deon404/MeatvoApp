/// Normalizes backend order status strings for UI filtering.
String normalizeOrderStatus(String? status) {
  if (status == null || status.trim().isEmpty) return 'pending';
  return status.trim().toLowerCase();
}

/// In-progress orders (not delivered or cancelled).
bool isOrderActive(String status) {
  final s = normalizeOrderStatus(status);
  return s != 'delivered' && s != 'cancelled';
}

bool isOrderCompleted(String status) =>
    normalizeOrderStatus(status) == 'delivered';

bool isOrderCancelled(String status) =>
    normalizeOrderStatus(status) == 'cancelled';

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
      s == 'on_way';
}
