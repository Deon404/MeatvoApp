import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';

import '../../constants/home_strings.dart';
import '../../models/banner_model.dart';
import '../../models/cart_model.dart';
import '../../models/home_category_item.dart';
import '../../models/product_variant_model.dart';
import '../../theme/app_theme.dart';
import '../../ui/organisms/product_card_adapter.dart';
import '../../widgets/common/banner_image_shimmer.dart';
import 'premium_product_card.dart';

class PremiumBannerCarousel extends StatelessWidget {
  const PremiumBannerCarousel({
    super.key,
    required this.banners,
    required this.onTap,
  });

  final List<BannerModel> banners;
  final ValueChanged<BannerModel> onTap;

  @override
  Widget build(BuildContext context) {
    return CarouselSlider.builder(
      itemCount: banners.length,
      itemBuilder: (_, index, __) => InkWell(
        onTap: () => onTap(banners[index]),
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.radiusLg),
          child: Stack(
            fit: StackFit.expand,
            children: [
              BannerImageWithShimmer(
                imageUrl: banners[index].imageUrl,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.circular(AppRadius.radiusLg),
              ),
              Container(color: Colors.black.withValues(alpha: 0.26)),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      banners[index].title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: AppThemeColors.white,
                          ),
                    ),
                    // Local smart-cast on the optional subtitle — was
                    // `banners[index].subtitle!`, which threw if the
                    // banner list was refreshed mid-frame and the
                    // subtitle field flipped to null.
                    Builder(builder: (_) {
                      final sub = banners[index].subtitle;
                      if (sub == null || sub.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        sub,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppThemeColors.white
                                  .withValues(alpha: 0.9),
                            ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      options: CarouselOptions(
        height: 184,
        viewportFraction: 0.92,
        autoPlay: true,
        enlargeCenterPage: true,
      ),
    );
  }
}

class PremiumHomeSectionHeader extends StatelessWidget {
  const PremiumHomeSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onActionTap,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    // Smart-cast locals so the `actionLabel!` / `onActionTap!` bangs
    // disappear. Public final fields on a StatelessWidget cannot be
    // promoted because they are technically getters; the locals make
    // it explicit and safe.
    final label = actionLabel;
    final action = onActionTap;
    final showAction = label != null && label.isNotEmpty && action != null;

    return Row(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (showAction)
          TextButton(onPressed: action, child: Text(label)),
      ],
    );
  }
}

class PremiumCategoryGrid extends StatelessWidget {
  const PremiumCategoryGrid({
    super.key,
    required this.categories,
    required this.onTap,
    required this.onViewAll,
  });

  final List<HomeCategoryItem> categories;
  final ValueChanged<String> onTap;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return PremiumErrorCard(
        message: HomeStrings.noCategoriesMessage,
        onRetry: onViewAll,
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.92,
      ),
      itemCount: categories.length,
      itemBuilder: (_, index) {
        final category = categories[index];
        return InkWell(
          onTap: () => onTap(category.name),
          borderRadius: BorderRadius.circular(AppRadius.radiusLg),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.radiusLg),
              gradient: LinearGradient(
                colors: _categoryColors(category.name),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_categoryIcon(category.name), color: AppThemeColors.white),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  category.name,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppThemeColors.white,
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _categoryIcon(String name) {
    switch (name.toLowerCase()) {
      case 'chicken':
        return Icons.set_meal_rounded;
      case 'fish':
        return Icons.phishing_rounded;
      case 'eggs':
        return Icons.egg_alt_rounded;
      case 'mutton':
        return Icons.restaurant_rounded;
      default:
        return Icons.grid_view_rounded;
    }
  }

  List<Color> _categoryColors(String name) {
    switch (name.toLowerCase()) {
      case 'chicken':
        return const [Color(0xFFFF7B54), Color(0xFFFF4D6D)];
      case 'fish':
        return const [Color(0xFF2D9CDB), Color(0xFF6C63FF)];
      case 'eggs':
        return const [Color(0xFFFFC145), Color(0xFFFF8A00)];
      default:
        return const [Color(0xFF7B61FF), Color(0xFF5A3FFF)];
    }
  }
}

class PremiumProductRail extends StatelessWidget {
  const PremiumProductRail({
    super.key,
    required this.products,
    required this.cart,
    required this.busyProductIds,
    required this.onProductTap,
    required this.onQuantityChange,
    this.highlightLabel,
    this.emptyMessage = HomeStrings.noRecommendationsMessage,
  });

  final List<ProductWithVariants> products;
  final CartModel cart;
  final Set<String> busyProductIds;
  final Future<void> Function(ProductWithVariants product) onProductTap;
  final Future<void> Function(ProductWithVariants product, int qty)
      onQuantityChange;
  final String? highlightLabel;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return PremiumErrorCard(message: emptyMessage, onRetry: () {});
    }
    final listHeight = ProductCardAdapter.carouselHeight(
      MediaQuery.sizeOf(context).width,
    );
    return SizedBox(
      height: listHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, index) {
          final product = products[index];
          final cartItem = cart.findItemByProductId(product.product.id);
          return PremiumProductCard(
            product: product,
            quantity: cartItem?.quantity.round() ?? 0,
            isBusy: busyProductIds.contains(product.product.id),
            highlightLabel: highlightLabel,
            onTap: () => onProductTap(product),
            onQuantityChange: (qty) => onQuantityChange(product, qty),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemCount: products.length,
      ),
    );
  }
}

class PremiumDealCard extends StatelessWidget {
  const PremiumDealCard({super.key, required this.timeLeft});

  final Duration timeLeft;

  @override
  Widget build(BuildContext context) {
    String two(int value) => value.toString().padLeft(2, '0');
    final safe = timeLeft.isNegative ? Duration.zero : timeLeft;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF8A00), Color(0xFFFF4D6D)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppThemeColors.primary.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.flash_on_rounded, color: AppThemeColors.white),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Live deals end in ${two(safe.inHours)}:${two(safe.inMinutes.remainder(60))}:${two(safe.inSeconds.remainder(60))}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppThemeColors.white,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class PremiumErrorCard extends StatelessWidget {
  const PremiumErrorCard({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppThemeColors.darkSurface
            : AppThemeColors.white,
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        border: Border.all(color: AppThemeColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Something went wrong', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          TextButton(onPressed: onRetry, child: const Text(HomeStrings.retryLabel)),
        ],
      ),
    );
  }
}
