import '../../utils/eta_display_util.dart';
import '../../utils/order_status_util.dart';
import 'push_notification_service.dart';

/// Thin wrapper for Android ongoing order-tracking notifications.
class OrderTrackingNotificationService {
  OrderTrackingNotificationService._();
  static final OrderTrackingNotificationService instance =
      OrderTrackingNotificationService._();

  final PushNotificationService _push = PushNotificationService();

  Future<void> update({
    required String orderId,
    required String status,
    int? etaMinutes,
    DateTime? estimatedDeliveryTime,
  }) async {
    final label = trackingNotificationLabel(status);
    final eta = formatArrivingInLabel(etaMinutes);
    final etaLabel = eta.isNotEmpty
        ? eta
        : (estimatedDeliveryTime != null
            ? formatDeliveryByTime(estimatedDeliveryTime)
            : null);

    await _push.showOngoingTrackingNotification(
      orderId: orderId,
      statusLabel: label,
      etaLabel: etaLabel,
    );
  }

  Future<void> dismiss() => _push.dismissOngoingTrackingNotification();
}
