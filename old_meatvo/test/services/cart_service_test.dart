import 'package:flutter_test/flutter_test.dart';
import 'package:meatvo_official/services/cart_service.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_setup.dart';

/// Unit tests for CartService
/// 
/// Note: These tests require Supabase to be properly initialized.
/// For full integration tests, use a test Supabase instance.
/// 
/// To run these tests, ensure Supabase is initialized in test setup.
void main() {
  group('CartService', () {
    late CartService cartService;

    setUpAll(() async {
      await TestSetup.initializeSupabase();
    });

    setUp(() {
      TestSetup.setUp();
      cartService = TestSetup.cartService;
    });

    group('Cart Operations', () {
      test('getCart should return empty cart when user not logged in', () async {
        try {
          final cart = await cartService.getCart();
          expect(cart.items, isEmpty);
        } catch (e) {
          // Expected if user is not logged in
          expect(e.toString(), contains('not logged in'));
        }
      });

      test('addToCart should throw exception when user not logged in', () async {
        expect(
          () => cartService.addToCart(
            TestHelpers.testProductId,
            1,
            unit: 'kg',
          ),
          throwsException,
        );
      });

      test('clearCart should throw exception when user not logged in', () async {
        expect(
          () => cartService.clearCart(),
          throwsException,
        );
      });
    });

    group('Wishlist Operations', () {
      test('getWishlist should throw exception when user not logged in', () async {
        expect(
          () => cartService.getWishlist(),
          throwsException,
        );
      });

      test('addToWishlist should throw exception when user not logged in', () async {
        expect(
          () => cartService.addToWishlist(TestHelpers.testProductId),
          throwsException,
        );
      });

      test('removeFromWishlist should throw exception when user not logged in', () async {
        expect(
          () => cartService.removeFromWishlist(TestHelpers.testProductId),
          throwsException,
        );
      });
    });
  });
}

