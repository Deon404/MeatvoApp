import 'package:flutter/material.dart';

import '../../models/product_variant_model.dart';
import '../../ui/organisms/meatvo_product_card.dart';
import '../../ui/organisms/product_card_adapter.dart';

/// @deprecated Use [MeatvoProductCard] via [ProductCardAdapter].
class ProductGridItem extends StatelessWidget {
  final ProductWithVariants product;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;

  const ProductGridItem({
    super.key,
    required this.product,
    this.onTap,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final canAdd = ProductCardAdapter.canAdd(product);
    return MeatvoProductCard(
      product: product.product,
      displayPrice: ProductCardAdapter.displayPrice(product),
      displayUnit: ProductCardAdapter.displayUnit(product),
      originalPrice: ProductCardAdapter.originalPrice(product),
      inStock: canAdd,
      layout: MeatvoProductCardLayout.grid,
      onTap: onTap,
      onAdd: canAdd ? onAdd : null,
    );
  }
}
