import '../../models/cart_model.dart';
import '../../models/product_variant_model.dart';
import '../../services/store_status_service.dart';
import '../organisms/product_card_adapter.dart';

/// Shared MeatvoProductCard cart callbacks + store-closed visual flags.
abstract final class ProductCardBindings {
  static ({
    bool inStock,
    bool orderingPaused,
    void Function()? onAdd,
    void Function()? onIncrement,
    void Function()? onDecrement,
  }) forProduct({
    required StoreStatus storeStatus,
    required ProductWithVariants product,
    required CartModel cart,
    required Future<void> Function(ProductWithVariants product, int nextQuantity)
        onQuantityChange,
  }) {
    final productId = product.product.id;
    final qty = cart.findItemByProductId(productId)?.quantity.round() ?? 0;
    final inStock = ProductCardAdapter.canAdd(product);
    final orderingPaused =
        ProductCardAdapter.isOrderingPaused(storeStatus, product);

    return (
      inStock: inStock,
      orderingPaused: orderingPaused,
      onAdd: inStock
          ? () => onQuantityChange(product, qty == 0 ? 1 : qty + 1)
          : null,
      onIncrement: inStock && qty > 0
          ? () => onQuantityChange(product, qty + 1)
          : null,
      onDecrement:
          qty > 0 ? () => onQuantityChange(product, qty - 1) : null,
    );
  }
}
