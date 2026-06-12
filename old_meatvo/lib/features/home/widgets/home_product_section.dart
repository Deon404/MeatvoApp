import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';

import '../../../design_system/theme/meatvo_theme_extensions.dart';
import '../../../design_system/tokens/meatvo_colors.dart';
import '../../../models/cart_model.dart';
import '../../../models/product_variant_model.dart';
import '../../../ui/organisms/product_card_adapter.dart';

/// Product section with horizontal scrolling 160px cards.
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

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final error = errorMessage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
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
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, __) => const _ProductCardSkeleton(),
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
            height: 200,
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
                final canAdd = ProductCardAdapter.canAdd(product);

                return _ProductCard(
                  product: product,
                  quantity: qty,
                  isBusy: busy,
                  inStock: canAdd,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onProductTap(product);
                  },
                  onAdd: canAdd
                      ? () => onQuantityChange(product, qty == 0 ? 1 : qty + 1)
                      : null,
                );
              },
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.quantity,
    required this.isBusy,
    required this.inStock,
    required this.onTap,
    this.onAdd,
  });

  final ProductWithVariants product;
  final int quantity;
  final bool isBusy;
  final bool inStock;
  final VoidCallback onTap;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final displayPrice = ProductCardAdapter.displayPrice(product);
    final displayUnit = ProductCardAdapter.displayUnit(product);
    final imageUrl = product.product.imageUrl ?? '';
    final hasImage = imageUrl.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 100,
                width: double.infinity,
                child: hasImage
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: Colors.grey.shade100,
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.grey.shade100,
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.grey.shade400,
                            size: 40,
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.grey.shade100,
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.grey.shade400,
                          size: 40,
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayUnit,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₹$displayPrice',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.red.shade600,
                        ),
                      ),
                      if (onAdd != null && !isBusy)
                        GestureDetector(
                          onTap: onAdd,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.red.shade600,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        )
                      else if (isBusy)
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.red.shade600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCardSkeleton extends StatelessWidget {
  const _ProductCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    return Shimmer.fromColors(
      baseColor: MeatvoColors.surfaceMuted,
      highlightColor: mv.surfaceCard,
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 100,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 12,
                    width: 120,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 10,
                    width: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 14,
                    width: 60,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
