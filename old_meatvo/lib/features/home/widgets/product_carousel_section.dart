import 'package:flutter/material.dart';

import '../../../constants/home_strings.dart';
import '../../../design_system/theme/meatvo_theme_extensions.dart';
import '../../../models/cart_model.dart';
import '../../../models/product_variant_model.dart';
import '../../../ui/organisms/meatvo_product_card.dart';
import '../../../ui/organisms/product_card_adapter.dart';
import '../../../ui/shells/section_header.dart';
import '../../../widgets/skeletons/product_card_skeleton.dart';

class ProductCarouselSection extends StatelessWidget {
  const ProductCarouselSection({
    super.key,
    required this.title,
    required this.products,
    required this.cart,
    required this.busyProductIds,
    required this.isLoading,
    this.errorMessage,
    required this.onViewAll,
    required this.onRetry,
    required this.onProductTap,
    required this.onQuantityChange,
    this.emptyTitle,
    this.emptyMessage,
    this.onEmptyAction,
  });

  final String title;
  final List<ProductWithVariants> products;
  final CartModel cart;
  final Set<String> busyProductIds;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onViewAll;
  final VoidCallback onRetry;
  final ValueChanged<ProductWithVariants> onProductTap;
  final Future<void> Function(ProductWithVariants product, int nextQuantity)
      onQuantityChange;
  final String? emptyTitle;
  final String? emptyMessage;
  final VoidCallback? onEmptyAction;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = ProductCardAdapter.carouselWidth(screenWidth);
    final listHeight = ProductCardAdapter.carouselHeight(screenWidth);

    // Local copy enables Dart's smart-cast inside the `if` so the
    // `errorMessage!` bang below disappears — eliminating the
    // "Null check operator used on a null value" we used to see when
    // the error was cleared on the same frame as a rebuild.
    final error = errorMessage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title,
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
        else if (error != null && products.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: mv.spacing.md),
            child: _SectionRetryBanner(message: error, onRetry: onRetry),
          )
        else if (products.isEmpty)
          Padding(
            padding: EdgeInsets.all(mv.spacing.md),
            child: Text(
              emptyMessage ?? 'Nothing here yet',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: mv.textMuted,
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

class _SectionRetryBanner extends StatelessWidget {
  const _SectionRetryBanner({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    return Container(
      padding: EdgeInsets.all(mv.spacing.sm),
      decoration: BoxDecoration(
        color: mv.surfaceCard,
        borderRadius: BorderRadius.circular(mv.radii.md),
        border: Border.all(color: mv.border),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: mv.textMuted, size: 20),
          SizedBox(width: mv.spacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: mv.textSecondary,
                  ),
            ),
          ),
          TextButton(onPressed: onRetry, child: Text(HomeStrings.retryLabel)),
        ],
      ),
    );
  }
}
