import 'package:flutter/material.dart';

import '../../../constants/home_strings.dart';
import '../../../models/cart_model.dart';
import '../../../models/product_variant_model.dart';
import '../../../ui/organisms/meatvo_product_card.dart';
import '../../../ui/organisms/product_card_adapter.dart';
import '../../../ui/shells/section_header.dart';
import '../../../widgets/skeletons/product_card_skeleton.dart';
import '../../../design_system/theme/meatvo_theme_extensions.dart';

/// Horizontal strip for egg products, derived from catalog lists.
class FreshEggsSection extends StatelessWidget {
  const FreshEggsSection({
    super.key,
    required this.featured,
    required this.bestSellers,
    required this.cart,
    required this.busyProductIds,
    required this.isLoading,
    required this.onViewAll,
    required this.onProductTap,
    required this.onQuantityChange,
  });

  final List<ProductWithVariants> featured;
  final List<ProductWithVariants> bestSellers;
  final CartModel cart;
  final Set<String> busyProductIds;
  final bool isLoading;
  final VoidCallback onViewAll;
  final ValueChanged<ProductWithVariants> onProductTap;
  final Future<void> Function(ProductWithVariants product, int nextQuantity)
      onQuantityChange;

  static List<ProductWithVariants> eggProducts(
    List<ProductWithVariants> featured,
    List<ProductWithVariants> bestSellers,
  ) {
    final seen = <String>{};
    final merged = [...featured, ...bestSellers];
    final eggs = <ProductWithVariants>[];

    for (final product in merged) {
      final id = product.product.id;
      if (!seen.add(id)) continue;
      if (_isEggProduct(product)) eggs.add(product);
    }
    return eggs;
  }

  static bool _isEggProduct(ProductWithVariants product) {
    final category = (product.product.categoryName ?? '').toLowerCase();
    final name = product.product.name.toLowerCase();
    return category.contains('egg') || name.contains('egg');
  }

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final products = eggProducts(featured, bestSellers);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = ProductCardAdapter.carouselWidth(screenWidth);
    final listHeight = ProductCardAdapter.carouselHeight(screenWidth);

    if (!isLoading && products.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: HomeStrings.freshEggsTitle,
          actionLabel: HomeStrings.viewAllLabel,
          onAction: onViewAll,
        ),
        SizedBox(height: mv.spacing.sm),
        if (isLoading && products.isEmpty)
          SizedBox(
            height: listHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: mv.spacing.md),
              itemCount: 3,
              separatorBuilder: (_, __) => SizedBox(width: mv.spacing.sm),
              itemBuilder: (_, __) => SizedBox(
                width: cardWidth,
                child: const ProductCardSkeleton(),
              ),
            ),
          )
        else
          SizedBox(
            height: listHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: mv.spacing.md),
              itemCount: products.length,
              separatorBuilder: (_, __) => SizedBox(width: mv.spacing.sm),
              itemBuilder: (context, index) {
                final product = products[index];
                final productId = product.product.id;
                final qty =
                    cart.findItemByProductId(productId)?.quantity.round() ?? 0;
                final busy = busyProductIds.contains(productId);
                final canAdd = ProductCardAdapter.canAdd(product);

                return SizedBox(
                  width: cardWidth,
                  height: listHeight,
                  child: MeatvoProductCard(
                    product: product.product.copyWith(
                      unit: ProductCardAdapter.displayUnit(product),
                    ),
                    displayPrice: ProductCardAdapter.displayPrice(product),
                    displayUnit: ProductCardAdapter.displayUnit(product),
                    originalPrice: ProductCardAdapter.originalPrice(product),
                    discountPercent: product.product.discount,
                    quantity: qty,
                    isBusy: busy,
                    inStock: canAdd,
                    layout: MeatvoProductCardLayout.carousel,
                    onTap: () => onProductTap(product),
                    onAdd: canAdd
                        ? () => onQuantityChange(product, qty == 0 ? 1 : qty + 1)
                        : null,
                    onIncrement: canAdd
                        ? () => onQuantityChange(product, qty + 1)
                        : null,
                    onDecrement: qty > 0
                        ? () => onQuantityChange(product, qty - 1)
                        : null,
                  ),
                );
              },
            ),
          ),
        SizedBox(height: mv.spacing.md),
      ],
    );
  }
}
