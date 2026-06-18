import '../models/cart_model.dart';
import 'cart_service.dart';

/// Keeps a widget or view-model in sync with [CartService.cartNotifier].
///
/// Cart mutations from any screen (home cards, cart tab, product detail, etc.)
/// all flow through [CartService], which updates the notifier. Subscribe once
/// and dispose when the owner is torn down.
class CartSyncSubscription {
  CartSyncSubscription(void Function(CartModel cart) onChanged)
      : _onChanged = onChanged {
    CartService.cartNotifier.addListener(_handleChange);
    _onChanged(CartService.cartNotifier.value);
  }

  final void Function(CartModel cart) _onChanged;

  void _handleChange() {
    _onChanged(CartService.cartNotifier.value);
  }

  void dispose() {
    CartService.cartNotifier.removeListener(_handleChange);
  }
}
