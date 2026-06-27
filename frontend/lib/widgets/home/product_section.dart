import 'package:flutter/material.dart';

import '../../constants/home_strings.dart';
import '../../models/cart_model.dart';
import '../../models/product_variant_model.dart';
import '../common/empty_state.dart';
import '../../ui/organisms/product_card_adapter.dart';
import '../common/product_card.dart';
import '../common/shimmer_loader.dart';
import 'home_inline_state_card.dart';
import 'home_layout.dart';
import 'home_section_header.dart';

enum ProductSectionLayout {
  carousel,
  grid,
}

/// =============================================================================
/// DEPRECATED — `ProductSection` is the legacy home-rail builder.
/// =============================================================================
///
/// The active home flow now composes:
///   • `features/home/widgets/product_carousel_section.dart` (MeatvoProductCard)
///   • `features/home/widgets/fresh_eggs_section.dart`        (MeatvoProductCard)
///
/// This widget kept the old `ProductCard` (legacy) which is itself
/// deprecated. No live screen calls this section anymore. We retain
/// the file only so old imports compile while consumers migrate.
@Deprecated(
  'Replaced by ProductCarouselSection + MeatvoProductCard. '
  'This section still renders the deprecated legacy ProductCard and '
  'should not be used in any customer-facing screen.',
)
// ignore_for_file: deprecated_member_use_from_same_package
class ProductSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String emptyTitle;
  final String emptyMessage;
  final String emptyActionLabel;
  final List<ProductWithVariants> products;
  final CartModel? cart;
  final Set<String> busyProductIds;
  final bool isLoading;
  final bool showPopularBadge;
  final String? errorMessage;
  final VoidCallback? onViewAll;
  final VoidCallback? onRetry;
  final VoidCallback? onEmptyAction;
  final ValueChanged<ProductWithVariants>? onProductTap;
  final Future<void> Function(ProductWithVariants product, int nextQuantity)?
      onQuantityChange;
  final ProductSectionLayout layout;
  final double gridChildAspectRatio;
  final bool showViewAll;
  final bool hideWhenEmpty;

  const ProductSection({
    super.key,
    required this.title,
    this.subtitle,
    this.emptyTitle = '',
    this.emptyMessage = '',
    this.emptyActionLabel = '',
    required this.products,
    this.cart,
    this.busyProductIds = const {},
    this.isLoading = false,
    this.showPopularBadge = false,
    this.errorMessage,
    this.onViewAll,
    this.onRetry,
    this.onEmptyAction,
    this.onProductTap,
    this.onQuantityChange,
    this.layout = ProductSectionLayout.carousel,
    this.gridChildAspectRatio = 0.65,
    this.showViewAll = true,
    this.hideWhenEmpty = false,
  });

  /// Browse-only section (pehle [ProductListSection]).
  factory ProductSection.browse({
    Key? key,
    required String title,
    required List<ProductWithVariants> products,
    String? subtitle,
    ProductSectionLayout layout = ProductSectionLayout.carousel,
    double gridChildAspectRatio = 0.65,
    bool showViewAll = false,
    VoidCallback? onViewAll,
    ValueChanged<ProductWithVariants>? onProductTap,
  }) {
    return ProductSection(
      key: key,
      title: title,
      subtitle: subtitle,
      products: products,
      layout: layout,
      gridChildAspectRatio: gridChildAspectRatio,
      showViewAll: showViewAll,
      onViewAll: onViewAll,
      onProductTap: onProductTap,
      hideWhenEmpty: true,
    );
  }

  /// Cart-integrated featured / popular section.
  factory ProductSection.withCart({
    Key? key,
    required String title,
    required String emptyTitle,
    required String emptyMessage,
    required String emptyActionLabel,
    required List<ProductWithVariants> products,
    required CartModel cart,
    required Set<String> busyProductIds,
    required bool isLoading,
    required bool showPopularBadge,
    required String? errorMessage,
    required VoidCallback onViewAll,
    required VoidCallback onRetry,
    required VoidCallback onEmptyAction,
    required ValueChanged<ProductWithVariants> onProductTap,
    required Future<void> Function(ProductWithVariants product, int nextQuantity)
        onQuantityChange,
  }) {
    return ProductSection(
      key: key,
      title: title,
      emptyTitle: emptyTitle,
      emptyMessage: emptyMessage,
      emptyActionLabel: emptyActionLabel,
      products: products,
      cart: cart,
      busyProductIds: busyProductIds,
      isLoading: isLoading,
      showPopularBadge: showPopularBadge,
      errorMessage: errorMessage,
      onViewAll: onViewAll,
      onRetry: onRetry,
      onEmptyAction: onEmptyAction,
      onProductTap: onProductTap,
      onQuantityChange: onQuantityChange,
      layout: ProductSectionLayout.carousel,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (hideWhenEmpty && !isLoading && products.isEmpty) {
      return const SizedBox.shrink();
    }

    // Local non-null copies — smart-cast lets us drop the `!` bangs.
    final error = errorMessage;
    final retry = onRetry;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitleRow(
          title: title,
          subtitle: subtitle,
          showViewAll: showViewAll && onViewAll != null,
          onViewAll: onViewAll,
        ),
        const SizedBox(height: 12),
        if (isLoading && products.isEmpty)
          _LoadingStrip(layout: layout)
        else if (error != null && products.isEmpty && retry != null)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: HomeLayout.horizontalPadding,
            ),
            child: HomeInlineStateCard(
              icon: Icons.wifi_off_rounded,
              title: HomeStrings.connectionLostTitle,
              message: error,
              actionLabel: HomeStrings.retryLabel,
              onAction: retry,
            ),
          )
        else if (products.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: HomeLayout.horizontalPadding,
            ),
            child: EmptyStateWidget(
              title: emptyTitle.isNotEmpty ? emptyTitle : 'Nothing here',
              message: emptyMessage.isNotEmpty
                  ? emptyMessage
                  : 'Check back soon',
              buttonLabel:
                  emptyActionLabel.isNotEmpty ? emptyActionLabel : null,
              onAction: onEmptyAction,
              fullScreen: false,
            ),
          )
        else if (layout == ProductSectionLayout.carousel)
          _ProductCarousel(
            products: products,
            cart: cart,
            busyProductIds: busyProductIds,
            showPopularBadge: showPopularBadge,
            onProductTap: onProductTap,
            onQuantityChange: onQuantityChange,
          )
        else
          _ProductGrid(
            products: products,
            gridChildAspectRatio: gridChildAspectRatio,
            onProductTap: onProductTap,
          ),
      ],
    );
  }
}

class _SectionTitleRow extends StatelessWidget {
  const _SectionTitleRow({
    required this.title,
    this.subtitle,
    required this.showViewAll,
    this.onViewAll,
  });

  final String title;
  final String? subtitle;
  final bool showViewAll;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    if (sub == null || sub.isEmpty) {
      return HomeSectionHeader(
        title: title,
        actionLabel: showViewAll ? HomeStrings.viewAllLabel : null,
        onAction: onViewAll,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: HomeLayout.sectionTitleStyle,
                ),
                const SizedBox(height: 4),
                Text(
                  sub,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (showViewAll && onViewAll != null)
            TextButton(
              onPressed: onViewAll,
              child: const Text(HomeStrings.viewAllLabel),
            ),
        ],
      ),
    );
  }
}

class _LoadingStrip extends StatelessWidget {
  const _LoadingStrip({required this.layout});

  final ProductSectionLayout layout;

  @override
  Widget build(BuildContext context) {
    if (layout == ProductSectionLayout.grid) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ShimmerLoader.productGrid(count: 4),
      );
    }
    return SizedBox(
      height: HomeLayout.featuredListHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: HomeLayout.horizontalPadding),
        itemCount: 3,
        separatorBuilder: (_, __) =>
            const SizedBox(width: HomeLayout.categorySpacing),
        itemBuilder: (_, __) => const SizedBox(
          width: HomeLayout.featuredCardWidth,
          child: ShimmerLoader.productCard(),
        ),
      ),
    );
  }
}

class _ProductCarousel extends StatelessWidget {
  const _ProductCarousel({
    required this.products,
    required this.cart,
    required this.busyProductIds,
    required this.showPopularBadge,
    this.onProductTap,
    this.onQuantityChange,
  });

  final List<ProductWithVariants> products;
  final CartModel? cart;
  final Set<String> busyProductIds;
  final bool showPopularBadge;
  final ValueChanged<ProductWithVariants>? onProductTap;
  final Future<void> Function(ProductWithVariants product, int nextQuantity)?
      onQuantityChange;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: HomeLayout.featuredListHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: HomeLayout.horizontalPadding,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          final cartItem = cart?.findItemByProductId(product.product.id);
          final quantity = cartItem?.quantity.round() ?? 0;
          final isBusy = busyProductIds.contains(product.product.id);

          return Padding(
            padding: EdgeInsets.only(
              right: index < products.length - 1
                  ? HomeLayout.categorySpacing
                  : 0,
            ),
            child: SizedBox(
              width: HomeLayout.featuredCardWidth,
              height: HomeLayout.featuredListHeight,
              child: ProductCard(
                product: product.product.copyWith(
                  unit: _productUnit(product),
                ),
                layout: ProductCardLayout.vertical,
                displayPrice: _displayPrice(product),
                originalPrice: _originalPrice(product),
                discountPercent: product.product.discount,
                displayUnit: _productUnit(product),
                isPopular: showPopularBadge,
                isAdding: isBusy,
                showWishlist: onQuantityChange == null,
                quantity: quantity,
                onTap: onProductTap != null ? () => onProductTap!(product) : null,
                onAdd: onQuantityChange != null && _canAdd(product)
                    ? () => onQuantityChange!(
                          product,
                          quantity == 0 ? 1 : quantity + 1,
                        )
                    : null,
                onIncrement: onQuantityChange != null && _canAdd(product)
                    ? () => onQuantityChange!(product, quantity + 1)
                    : null,
                onDecrement: onQuantityChange != null && quantity > 0
                    ? () => onQuantityChange!(product, quantity - 1)
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({
    required this.products,
    required this.gridChildAspectRatio,
    this.onProductTap,
  });

  final List<ProductWithVariants> products;
  final double gridChildAspectRatio;
  final ValueChanged<ProductWithVariants>? onProductTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: gridChildAspectRatio,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return ProductCard(
          product: product.product,
          layout: ProductCardLayout.vertical,
          showWishlist: true,
          onTap: onProductTap != null ? () => onProductTap!(product) : null,
        );
      },
    );
  }
}

ProductVariantModel? _preferredVariant(ProductWithVariants product) {
  if (product.availableVariants.isNotEmpty) {
    return product.availableVariants.first;
  }
  if (product.variants.isNotEmpty) return product.variants.first;
  return null;
}

bool _canAdd(ProductWithVariants product) {
  final variant = _preferredVariant(product);
  if (!product.product.isAvailable) return false;
  if (variant != null) return variant.isAvailable && variant.stock > 0;
  return (product.product.stock ?? 1) > 0;
}

String _productUnit(ProductWithVariants product) {
  return ProductCardAdapter.displayUnit(product);
}

double _displayPrice(ProductWithVariants product) {
  return _preferredVariant(product)?.price ?? product.product.finalPrice;
}

double? _originalPrice(ProductWithVariants product) {
  final currentPrice = _displayPrice(product);
  final discount = product.product.discount;
  if (discount != null && discount > 0 && discount < 100) {
    return currentPrice / (1 - (discount / 100));
  }
  return product.product.price > currentPrice ? product.product.price : null;
}
