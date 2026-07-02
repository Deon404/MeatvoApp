import 'package:flutter_test/flutter_test.dart';
import 'package:meatvo_official/models/order_model.dart';
import 'package:meatvo_official/utils/order_payment_util.dart';

OrderModel buildOrder({
  required String status,
  String paymentMethod = 'online',
  String? paymentStatus,
}) {
  return OrderModel(
    id: '101',
    userId: '7',
    items: const [],
    totalAmount: 250,
    finalAmount: 250,
    status: status,
    paymentMethod: paymentMethod,
    paymentStatus: paymentStatus,
  );
}

void main() {
  group('isOrderAwaitingPayment', () {
    test('treats placed online orders as awaiting payment', () {
      final order = buildOrder(status: 'PLACED');
      expect(isOrderAwaitingPayment(order), isTrue);
    });

    test('treats payment_pending online orders as awaiting payment', () {
      final order = buildOrder(status: 'PAYMENT_PENDING');
      expect(isOrderAwaitingPayment(order), isTrue);
    });

    test('stops awaiting once payment is paid', () {
      final order = buildOrder(
        status: 'PAYMENT_PENDING',
        paymentStatus: 'paid',
      );
      expect(isOrderAwaitingPayment(order), isFalse);
    });

    test('does not flag cod orders as awaiting payment', () {
      final order = buildOrder(
        status: 'CONFIRMED',
        paymentMethod: 'cod',
      );
      expect(isOrderAwaitingPayment(order), isFalse);
    });
  });
}
