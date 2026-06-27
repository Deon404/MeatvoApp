import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design_system/theme/meatvo_theme_extensions.dart';
import '../../../models/cart_model.dart';
import '../../../models/product_variant_model.dart';
import '../../../services/store_status_service.dart';
import '../../../ui/organisms/meatvo_product_card.dart';
import '../../../ui/organisms/product_card_adapter.dart';
import '../../../ui/organisms/product_card_bindings.dart';
import '../../../widgets/skeletons/product_card_skeleton.dart';

/// Product section with horizontal scrolling unified MeatvoProductCard rails.
class HomeProductSection extends StatelessWidget {
  const HomeProductSection({
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
    required this.storeStatus,
  });

  static const double _kRailCardWidth = 160;

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
  final StoreStatus storeStatus;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final error = errorMessage;
    final railHeight =
        MeatvoProductCard.carouselCardHeight(_kRailCardWidth, context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                products.isEmpty ? title : '$title (${products.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onViewAll();
                },
                child: Text(
                  'See All',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (isLoading && products.isEmpty)
          SizedBox(
            height: railHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, __) => const SizedBox(
                width: _kRailCardWidth,
                child: ProductCardSkeleton(),
              ),
            ),
          )
        else if (error != null && products.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _SectionRetryBanner(message: error, onRetry: onRetry),
          )
        else if (products.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Nothing here yet',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: mv.textMuted,
                  ),
            ),
          )
        else
          SizedBox(
            height: railHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final product = products[index];
                final productId = product.product.id;
                final qty =
                    cart.findItemByProductId(productId)?.quantity.round() ?? 0;
                final busy = busyProductIds.contains(productId);
                final bindings = ProductCardBindings.forProduct(
                  storeStatus: storeStatus,
                  product: product,
                  cart: cart,
                  onQuantityChange: onQuantityChange,
                );

                return SizedBox(
                  width: _kRailCardWidth,
                  child: MeatvoProductCard(
                    product: product.product,
                    displayPrice: ProductCardAdapter.displayPrice(product),
                    displayUnit: ProductCardAdapter.displayUnit(product),
                    originalPrice: ProductCardAdapter.originalPrice(product),
                    discountPercent: ProductCardAdapter.discountPercent(product),
                    quantity: qty,
                    isBusy: busy,
                    inStock: bindings.inStock,
                    orderingPaused: bindings.orderingPaused,
                    layout: MeatvoProductCardLayout.carousel,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onProductTap(product);
                    },
                    onAdd: bindings.onAdd,
                    onIncrement: bindings.onIncrement,
                    onDecrement: bindings.onDecrement,
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 16),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: mv.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: mv.border),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: mv.textMuted, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: mv.textSecondary,
                  ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
