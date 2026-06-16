import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cart_model.dart';
import '../services/cart_service.dart';

class CartState {
  const CartState({
    required this.isLoading,
    required this.cart,
    required this.error,
  });

  factory CartState.initial() => CartState(
        isLoading: true,
        cart: CartModel(),
        error: null,
      );

  final bool isLoading;
  final CartModel cart;
  final String? error;

  CartState copyWith({
    bool? isLoading,
    CartModel? cart,
    Object? error = _sentinel,
  }) {
    return CartState(
      isLoading: isLoading ?? this.isLoading,
      cart: cart ?? this.cart,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

const Object _sentinel = Object();

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier(ref.read(cartServiceProvider))..loadCart();
});

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier(this._cartService) : super(CartState.initial());

  final CartService _cartService;

  Future<void> loadCart() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final cart = await _cartService.getCart();
      state = state.copyWith(isLoading: false, cart: cart);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> updateQuantity(String itemId, int quantity) async {
    try {
      await _cartService.updateCartItem(itemId, quantity);
      await loadCart();
    } catch (error) {
      state = state.copyWith(
        error: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> removeItem(String itemId) async {
    try {
      await _cartService.removeFromCart(itemId);
      await loadCart();
    } catch (error) {
      state = state.copyWith(
        error: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> clearCart() async {
    try {
      await _cartService.clearCart();
      state = state.copyWith(cart: CartModel(), error: null);
    } catch (error) {
      state = state.copyWith(
        error: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}
