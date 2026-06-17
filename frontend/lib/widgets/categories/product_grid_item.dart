import 'package:flutter/material.dart';

import '../../models/product_variant_model.dart';
import '../../ui/organisms/meatvo_product_card.dart';
import '../../ui/organisms/product_card_adapter.dart';

/// Grid cell wrapper around [MeatvoProductCard] with full cart/discount wiring.
class ProductGridItem extends StatelessWidget {
  const ProductGridItem({
    super.key,
    required this.product,
    this.quantity = 0,
    this.isBusy = false,
    this.orderingPaused = false,
    this.onTap,
    this.onAdd,
    this.onIncrement,
    this.onDecrement,
  });

  final ProductWithVariants product;
  final int quantity;
  final bool isBusy;
  final bool orderingPaused;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    final inStock = ProductCardAdapter.canAdd(product);
    return MeatvoProductCard(
      product: product.product,
      displayPrice: ProductCardAdapter.displayPrice(product),
      displayUnit: ProductCardAdapter.displayUnit(product),
      originalPrice: ProductCardAdapter.originalPrice(product),
      discountPercent: ProductCardAdapter.discountPercent(product),
      quantity: quantity,
      isBusy: isBusy,
      inStock: inStock,
      orderingPaused: orderingPaused,
      layout: MeatvoProductCardLayout.grid,
      onTap: onTap,
      onAdd: inStock ? onAdd : null,
      onIncrement: inStock && quantity > 0 ? onIncrement : null,
      onDecrement: quantity > 0 ? onDecrement : null,
    );
  }
}
