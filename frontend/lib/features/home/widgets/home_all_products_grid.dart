import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../design_system/theme/meatvo_theme_extensions.dart';
import '../../../design_system/tokens/meatvo_colors.dart';
import '../../../models/cart_model.dart';
import '../../../models/product_variant_model.dart';
import '../../../services/store_status_service.dart';
import '../../../ui/organisms/meatvo_product_card.dart';
import '../../../ui/organisms/product_card_adapter.dart';
import '../../../ui/organisms/product_card_bindings.dart';
import '../../../utils/responsive_helper.dart';

class HomeAllProductsGrid extends StatelessWidget {
  const HomeAllProductsGrid({
    super.key,
    required this.products,
    required this.cart,
    required this.busyProductIds,
    required this.isLoading,
    this.errorMessage,
    required this.onRetry,
    required this.onProductTap,
    required this.onQuantityChange,
    required this.storeStatus,
  });

  final List<ProductWithVariants> products;
  final CartModel cart;
  final Set<String> busyProductIds;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;
  final ValueChanged<ProductWithVariants> onProductTap;
  final Future<void> Function(ProductWithVariants product, int nextQuantity)
      onQuantityChange;
  final StoreStatus storeStatus;

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final mv = context.meatvo;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardHeight = ProductCardAdapter.gridCardHeight(screenWidth, context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Shop All Products',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              if (!isLoading && products.isNotEmpty)
                Text(
                  '${products.length} items',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),
        ),
        if (isLoading && products.isEmpty)
          _LoadingGrid(cardHeight: cardHeight)
        else if (errorMessage != null && products.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _RetryBanner(message: errorMessage!, onRetry: onRetry),
          )
        else if (products.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No products available right now',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: mv.textMuted,
                  ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: cardHeight,
              ),
              itemCount: products.length,
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

                return MeatvoProductCard(
                  product: product.product,
                  displayPrice: ProductCardAdapter.displayPrice(product),
                  displayUnit: ProductCardAdapter.displayUnit(product),
                  originalPrice: ProductCardAdapter.originalPrice(product),
                  discountPercent: ProductCardAdapter.discountPercent(product),
                  quantity: qty,
                  isBusy: busy,
                  inStock: bindings.inStock,
                  orderingPaused: bindings.orderingPaused,
                  layout: MeatvoProductCardLayout.grid,
                  onTap: () => onProductTap(product),
                  onAdd: bindings.onAdd,
                  onIncrement: bindings.onIncrement,
                  onDecrement: bindings.onDecrement,
                );
              },
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _LoadingGrid extends StatelessWidget {
  const _LoadingGrid({required this.cardHeight});

  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: cardHeight,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: MeatvoColors.surfaceMuted,
          highlightColor: mv.surfaceCard,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
          ),
        ),
      ),
    );
  }
}

class _RetryBanner extends StatelessWidget {
  const _RetryBanner({
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
