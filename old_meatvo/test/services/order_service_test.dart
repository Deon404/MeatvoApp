import 'package:flutter_test/flutter_test.dart';
import 'package:meatvo_official/services/order_service.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_setup.dart';

/// Unit tests for OrderService
/// 
/// Note: These tests require Supabase to be properly configured.
/// For full integration tests, use a test Supabase instance.
void main() {
  group('OrderService', () {
    late OrderService orderService;

    setUpAll(() async {
      await TestSetup.initializeSupabase();
    });

    setUp(() {
      TestSetup.setUp();
      orderService = TestSetup.orderService;
    });

    group('Order Operations', () {
      test('getUserOrders should throw exception when user not logged in', () async {
        expect(
          () => orderService.getUserOrders(),
          throwsException,
        );
      });

      test('getOrderById should throw exception when user not logged in', () async {
        expect(
          () => orderService.getOrderById(TestHelpers.testOrderId),
          throwsException,
        );
      });

      test('cancelOrder should throw exception when user not logged in', () async {
        expect(
          () => orderService.cancelOrder(TestHelpers.testOrderId),
          throwsException,
        );
      });
    });

    group('Coupon Operations', () {
      test('applyCoupon should throw exception when user not logged in', () async {
        expect(
          () => orderService.applyCoupon('TEST10', 100.0),
          throwsException,
        );
      });
    });
  });
}

