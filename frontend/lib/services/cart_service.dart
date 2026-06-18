import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart' show ApiCartPaths;
import '../models/cart_model.dart';
import '../models/product_model.dart';
import 'api_service.dart';
import 'error_tracking_service.dart';

/// Cart service — custom Node.js backend
final cartServiceProvider = Provider<CartService>((ref) {
  return CartService(ref.read(apiServiceProvider));
});

class CartService {
  final ApiService _api;
  static final ValueNotifier<CartModel> cartNotifier =
      ValueNotifier<CartModel>(CartModel());
  static final ValueNotifier<int> cartItemCountNotifier = ValueNotifier<int>(0);

  CartService([ApiService? api]) : _api = api ?? ApiService();

  // ── Parse helpers ─────────────────────────────────────────────────────────

  bool _isRequestSuccessful(dynamic data) {
    if (data is! Map) return false;
    final map = data.cast<String, dynamic>();
    return map['success'] == true || map['ok'] == true;
  }

  dynamic _extractData(dynamic responseData) {
    if (responseData is Map) {
      return responseData['data'];
    }
    return null;
  }

  String _normalizeId(String id) => id.trim();

  Map<String, dynamic> _normalizeProductJson(Map<String, dynamic> json) {
    final productJson = Map<String, dynamic>.from(json);
    if (productJson['id'] != null) {
      productJson['id'] = productJson['id'].toString();
    }
    if (productJson['category_id'] != null) {
      productJson['category_id'] = productJson['category_id'].toString();
    }
    productJson['image_url'] ??= productJson['imageUrl'];
    final displayPrice = productJson['display_price'] ?? productJson['displayPrice'];
    if (displayPrice != null) {
      productJson['price'] = displayPrice is num
          ? displayPrice.toDouble()
          : double.tryParse(displayPrice.toString()) ?? productJson['price'];
    }
    if (!productJson.containsKey('price')) {
      productJson['price'] = productJson['base_price'] ??
          productJson['basePrice'] ??
          productJson['display_price'] ??
          0;
    }
    if (!productJson.containsKey('is_available')) {
      productJson['is_available'] = productJson['is_active'] ??
          productJson['isActive'] ??
          productJson['inStock'] ??
          true;
    }
    return productJson;
  }

  CartModel _parseCartResponse(dynamic data) {
    List<dynamic> rawItems = [];
    if (data is List) {
      rawItems = data;
    } else if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      if (map['items'] is List) {
        rawItems = map['items'] as List;
      } else if (map['cart'] is Map &&
          (map['cart'] as Map)['items'] is List) {
        rawItems = ((map['cart'] as Map)['items'] as List);
      }
    }

    final items = rawItems.map((json) {
      final j = json as Map<String, dynamic>;

      // Store cart-item-id for later update/delete
      final productJson =
          _normalizeProductJson(j['product'] as Map<String, dynamic>? ?? {});
      final productId = _normalizeId(
        (j['productId'] ?? j['product_id'] ?? productJson['id'] ?? '')
            .toString(),
      );
      // Backend cart is keyed by productId — use it as the stable line id.
      final itemId = _normalizeId((j['id'] ??
              j['_id'] ??
              j['itemId'] ??
              j['productId'] ??
              j['product_id'] ??
              productId)
          .toString());
      final product = ProductModel.fromJson(productJson);

      final qty = j['quantity'] is num
          ? (j['quantity'] as num).toDouble()
          : double.tryParse(j['quantity']?.toString() ?? '') ?? 1.0;

      final variantId =
          (j['variantId'] ?? j['variant_id'])?.toString();

      // Variant price from nested variant object or direct field
      double? variantPrice;
      final variantJson = j['variant'] as Map<String, dynamic>?;
      if (variantJson != null) {
        final p = variantJson['price'];
        if (p is num) variantPrice = p.toDouble();
      }

      final unit = (variantJson?['weight'] ??
              j['unit'] ??
              productJson['unit'] ??
              'kg')
          .toString();

      return CartItem(
        itemId: itemId,
        productId: productId,
        product: product,
        variantId: variantId,
        variantPrice: variantPrice,
        quantity: qty,
        unit: unit,
      );
    }).toList();

    final cart = CartModel(items: items);
    _syncCartState(cart);
    return cart;
  }

  void _syncCartState(CartModel cart) {
    cartNotifier.value = cart;
    cartItemCountNotifier.value = cart.totalQuantity.round();
  }

  // ── Cart CRUD ─────────────────────────────────────────────────────────────

  Future<CartModel> getCart() async {
    try {
      final res = await _api.get(ApiCartPaths.cart);
      if (!_isRequestSuccessful(res.data)) {
        throw Exception(res.data['message'] ?? 'Failed to fetch cart');
      }
      return _parseCartResponse(_extractData(res.data));
    } on DioException catch (e) {
      await ErrorTrackingService.captureException(e, tag: 'cart_fetch');
      throw Exception(
          'Failed to fetch cart: ${e.response?.data?['message'] ?? e.message}');
    } catch (e, st) {
      await ErrorTrackingService.captureException(e, stackTrace: st, tag: 'cart_fetch');
      throw Exception('Failed to fetch cart: $e');
    }
  }

  Future<void> addToCart(
    String productId,
    int quantity, {
    required String unit,
    String? variantId,
  }) async {
    final normalizedProductId = _normalizeId(productId);
    try {
      final body = <String, dynamic>{
        'productId': normalizedProductId.toString(),
        'quantity': quantity,
      };
      if (variantId != null && variantId.isNotEmpty) {
        body['variantId'] = variantId;
      }
      final res = await _api.post(ApiCartPaths.cart, data: body);
      if (!_isRequestSuccessful(res.data)) {
        throw Exception(res.data['message'] ?? 'Failed to add item to cart');
      }

      _parseCartResponse(_extractData(res.data));
    } on DioException catch (e) {
      await ErrorTrackingService.captureException(
        e,
        tag: 'cart_add',
        context: {'product_id': normalizedProductId, 'quantity': quantity},
      );
      throw Exception(
          'Failed to add item to cart: ${e.response?.data?['message'] ?? e.message}');
    } catch (e, st) {
      await ErrorTrackingService.captureException(e, stackTrace: st, tag: 'cart_add');
      throw Exception('Failed to add item to cart: $e');
    }
  }

  Future<void> updateCartItem(
    String itemId,
    int quantity,
  ) async {
    final normalizedItemId = _normalizeId(itemId);
    if (quantity <= 0) {
      await removeFromCart(normalizedItemId);
      return;
    }

    try {
      final res = await _api.put(
        '${ApiCartPaths.cartItem}$normalizedItemId',
        data: {'quantity': quantity},
      );
      if (!_isRequestSuccessful(res.data)) {
        throw Exception(res.data['message'] ?? 'Failed to update cart item');
      }
      _parseCartResponse(_extractData(res.data));
    } on DioException catch (e) {
      throw Exception(
          'Failed to update cart item: ${e.response?.data?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to update cart item: $e');
    }
  }

  /// Backend-aligned update using cart item id.
  Future<void> updateCart(String id, int quantity) async {
    if (quantity <= 0) {
      await _api.delete('${ApiCartPaths.cartItem}$id');
      return;
    }
    final res = await _api.put(
      '${ApiCartPaths.cartItem}$id',
      data: {'quantity': quantity},
    );
    if (!_isRequestSuccessful(res.data)) {
      throw Exception(res.data['message'] ?? 'Failed to update cart item');
    }
    _parseCartResponse(_extractData(res.data));
  }

  /// Removes a cart line by product id (backend cart key).
  Future<void> removeFromCart(String productId) async {
    try {
      final normalizedProductId = _normalizeId(productId);
      if (normalizedProductId.isEmpty) return;

      final res =
          await _api.delete('${ApiCartPaths.cartItem}$normalizedProductId');
      if (!_isRequestSuccessful(res.data)) {
        throw Exception(
            res.data['message'] ?? 'Failed to remove item from cart');
      }
      _parseCartResponse(_extractData(res.data));
    } on DioException catch (e) {
      throw Exception(
          'Failed to remove item from cart: ${e.response?.data?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to remove item from cart: $e');
    }
  }

  Future<void> clearCart() async {
    try {
      final res = await _api.delete(ApiCartPaths.cart);
      if (!_isRequestSuccessful(res.data)) {
        throw Exception(res.data['message'] ?? 'Failed to clear cart');
      }
      cartNotifier.value = CartModel();
      cartItemCountNotifier.value = 0;
    } on DioException catch (e) {
      await ErrorTrackingService.captureException(e, tag: 'cart_clear');
      throw Exception(
          'Failed to clear cart: ${e.response?.data?['message'] ?? e.message}');
    } catch (e, st) {
      await ErrorTrackingService.captureException(e, stackTrace: st, tag: 'cart_clear');
      throw Exception('Failed to clear cart: $e');
    }
  }

  // ── Wishlist stubs (not yet in backend API) ────────────────────────────────

  Future<void> addToWishlist(String productId) async {
    debugPrint('⚠️ addToWishlist: not yet supported by backend');
  }

  Future<void> removeFromWishlist(String productId) async {
    debugPrint('⚠️ removeFromWishlist: not yet supported by backend');
  }

  Future<List<ProductModel>> getWishlist() async => [];

  Future<bool> isInWishlist(String productId) async => false;

  // ── Realtime stub (REST backend has no realtime) ───────────────────────────

  Stream<CartModel> subscribeToCartUpdates({
    required Function() onCartUpdated,
    Function(String)? onError,
  }) async* {
    try {
      final cart = await getCart();
      yield cart;
      onCartUpdated();
    } catch (e) {
      onError?.call('Failed to load cart: $e');
    }
  }

  void unsubscribeFromCartUpdates() {}

  // ── Optimistic updates (instant UI, sync API in background) ─────────────

  /// Pushes a cart snapshot to all listeners without waiting for the server.
  void applyOptimisticCart(CartModel cart) {
    _syncCartState(cart);
  }

  /// Builds a local cart snapshot for [nextQuantity] before the API responds.
  CartModel buildOptimisticCart({
    required CartModel current,
    required ProductModel product,
    required String productId,
    required int nextQuantity,
    String? variantId,
    double? variantPrice,
    required String unit,
  }) {
    final currentItems = [...current.items];
    final existingIndex =
        currentItems.indexWhere((item) => item.productId == productId);

    if (existingIndex == -1 && nextQuantity > 0) {
      currentItems.add(
        CartItem(
          itemId: productId,
          productId: productId,
          product: product,
          variantId: variantId,
          variantPrice: variantPrice,
          quantity: nextQuantity.toDouble(),
          unit: unit,
        ),
      );
    } else if (existingIndex != -1 && nextQuantity > 0) {
      currentItems[existingIndex] = currentItems[existingIndex].copyWith(
        quantity: nextQuantity.toDouble(),
        variantId: variantId ?? currentItems[existingIndex].variantId,
        variantPrice: variantPrice ?? currentItems[existingIndex].variantPrice,
      );
    } else if (existingIndex != -1) {
      currentItems.removeAt(existingIndex);
    }

    return CartModel(items: currentItems);
  }
}
