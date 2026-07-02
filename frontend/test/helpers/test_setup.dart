import 'package:meatvo_official/models/cart_model.dart';
import 'package:meatvo_official/models/order_model.dart';
import 'package:meatvo_official/models/product_model.dart';
import 'package:meatvo_official/services/cart_service.dart';
import 'package:meatvo_official/services/order_service.dart';

/// Shared test setup for service tests.
class TestSetup {
  static bool isTestEnvironmentInitialized = false;

  static late CartService cartService;
  static late OrderService orderService;

  static Future<void> initializeTestEnvironment() async {
    // Unit tests run against lightweight fakes.
    isTestEnvironmentInitialized = true;
  }

  static void setUp() {
    cartService = _FakeCartService();
    orderService = _FakeOrderService();
  }
}

class _FakeCartService extends CartService {
  Exception _authError() => Exception('User not logged in');

  @override
  Future<CartModel> getCart() async => throw _authError();

  @override
  Future<void> addToCart(
    String productId,
    int quantity, {
    required String unit,
    String? variantId,
  }) async {
    throw _authError();
  }

  @override
  Future<void> clearCart() async => throw _authError();

  @override
  Future<List<ProductModel>> getWishlist() async => throw _authError();

  @override
  Future<void> addToWishlist(String productId) async => throw _authError();

  @override
  Future<void> removeFromWishlist(String productId) async => throw _authError();
}

class _FakeOrderService extends OrderService {
  Exception _authError() => Exception('User not logged in');

  @override
  Future<List<OrderModel>> getUserOrders() async => throw _authError();

  @override
  Future<OrderModel> getOrderById(String orderId) async => throw _authError();

  @override
  Future<OrderModel> cancelOrder(String orderId) async => throw _authError();

  @override
  Future<Map<String, dynamic>> applyCoupon(String code, double amount) async {
    throw _authError();
  }
}

