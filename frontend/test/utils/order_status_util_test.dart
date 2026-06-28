import 'package:flutter_test/flutter_test.dart';
import 'package:meatvo_official/utils/order_status_util.dart';

void main() {
  group('normalizeOrderStatus', () {
    test('lowercases and trims backend statuses', () {
      expect(normalizeOrderStatus('CANCELLED'), 'cancelled');
      expect(normalizeOrderStatus(' DELIVERED '), 'delivered');
      expect(normalizeOrderStatus(null), 'confirmed');
    });

    test('collapses internal statuses to customer-facing keys', () {
      expect(normalizeOrderStatus('PACKED'), 'preparing');
      expect(normalizeOrderStatus('RIDER_ASSIGNED'), 'preparing');
      expect(normalizeOrderStatus('OUT_FOR_DELIVERY'), 'out_for_delivery');
      expect(normalizeOrderStatus('PLACED'), 'confirmed');
    });
  });

  group('tracking steps', () {
    test('uses four customer-visible steps', () {
      expect(trackingStepCount, 4);
      expect(resolveTrackingStepIndex('CONFIRMED'), 0);
      expect(resolveTrackingStepIndex('PACKED'), 1);
      expect(resolveTrackingStepIndex('OUT_FOR_DELIVERY'), 2);
      expect(resolveTrackingStepIndex('DELIVERED'), 3);
    });
  });

  group('tab filters', () {
    test('active excludes delivered and cancelled', () {
      expect(isOrderActive('placed'), isTrue);
      expect(isOrderActive('packed'), isTrue);
      expect(isOrderActive('out_for_delivery'), isTrue);
      expect(isOrderActive('DELIVERED'), isFalse);
      expect(isOrderActive('CANCELLED'), isFalse);
    });

    test('completed and cancelled predicates', () {
      expect(isOrderCompleted('DELIVERED'), isTrue);
      expect(isOrderCompleted('placed'), isFalse);
      expect(isOrderCancelled('CANCELLED'), isTrue);
      expect(isOrderCancelled('placed'), isFalse);
    });

    test('trackable includes in-progress statuses', () {
      expect(isOrderTrackable('packed'), isTrue);
      expect(isOrderTrackable('cancelled'), isFalse);
      expect(isOrderTrackable('delivered'), isFalse);
    });
  });
}
