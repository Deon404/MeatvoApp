import 'package:flutter/material.dart';

import '../../models/product_variant_model.dart';
import '../../ui/atoms/meatvo_badge.dart';
import '../../ui/organisms/meatvo_product_card.dart';
import '../../ui/organisms/product_card_adapter.dart';

/// Premium rail card — same design system as home; sirf badge alag.
class PremiumProductCard extends StatelessWidget {
  const PremiumProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.onQuantityChange,
    this.quantity = 0,
    this.isBusy = false,
    this.highlightLabel,
  });

  final ProductWithVariants product;
  final VoidCallback onTap;
  final Future<void> Function(int nextQuantity) onQuantityChange;
  final int quantity;
  final bool isBusy;
  final String? highlightLabel;

  @override
  Widget build(BuildContext context) {
    final canAdd = ProductCardAdapter.canAdd(product);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = screenWidth * 0.42;

    return SizedBox(
      width: cardWidth,
      height: ProductCardAdapter.carouselHeight(screenWidth),
      child: MeatvoProductCard(
        product: product.product.copyWith(
          unit: ProductCardAdapter.displayUnit(product),
        ),
        displayPrice: ProductCardAdapter.displayPrice(product),
        displayUnit: ProductCardAdapter.displayUnit(product),
        originalPrice: ProductCardAdapter.originalPrice(product),
        discountPercent: product.product.discount,
        quantity: quantity,
        isBusy: isBusy,
        inStock: canAdd,
        showFreshBadge: false,
        badgeLabel: highlightLabel,
        badgeVariant: MeatvoBadgeVariant.popular,
        layout: MeatvoProductCardLayout.carousel,
        onTap: onTap,
        onAdd: canAdd
            ? () => onQuantityChange(quantity == 0 ? 1 : quantity + 1)
            : null,
        onIncrement: canAdd ? () => onQuantityChange(quantity + 1) : null,
        onDecrement:
            quantity > 0 ? () => onQuantityChange(quantity - 1) : null,
      ),
    );
  }
}
