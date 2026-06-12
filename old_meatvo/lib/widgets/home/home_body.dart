import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/home_strings.dart';
import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../features/connectivity/connectivity_provider.dart';
import '../../features/home/widgets/home_category_row.dart';
import '../../features/home/widgets/home_search_bar.dart';
import '../../features/home/widgets/home_product_section.dart';
import '../../features/home/widgets/hero_banner_carousel.dart';
import '../../features/home/widgets/home_brand_footer.dart';
import '../../models/banner_model.dart';
import '../../models/home_category_item.dart';
import '../../models/product_variant_model.dart';
import '../../ui/shells/offline_state_view.dart';
import '../../viewmodels/home_state.dart';
import '../../widgets/error_states/error_state_widget.dart';
import '../../screens/search/search_screen.dart';

class HomeBody extends ConsumerWidget {
  const HomeBody({
    super.key,
    required this.state,
    required this.onOpenCategories,
    required this.onOpenCategory,
    required this.onRetryHome,
    required this.onRetryCategories,
    required this.onRetryFeatured,
    required this.onRetryPopular,
    required this.onBannerTap,
    required this.onProductTap,
    required this.onQuantityChange,
    required this.bottomPadding,
  });

  final HomeState state;
  final VoidCallback onOpenCategories;
  final ValueChanged<HomeCategoryItem> onOpenCategory;
  final VoidCallback onRetryHome;
  final VoidCallback onRetryCategories;
  final VoidCallback onRetryFeatured;
  final VoidCallback onRetryPopular;
  final ValueChanged<BannerModel> onBannerTap;
  final ValueChanged<ProductWithVariants> onProductTap;
  final Future<void> Function(ProductWithVariants product, int nextQuantity)
      onQuantityChange;
  final double bottomPadding;

  static bool showsSameProducts(
    List<ProductWithVariants> featured,
    List<ProductWithVariants> popular,
  ) {
    if (featured.isEmpty || popular.isEmpty) return false;
    final featuredIds = featured.map((p) => p.product.id).toSet();
    final popularIds = popular.map((p) => p.product.id).toSet();
    return featuredIds.length == popularIds.length &&
        featuredIds.containsAll(popularIds);
  }

  /// Resolve the canonical Eggs category from API (so we ship its real
  /// numeric id to the catalog filter) and fall back to a name-only item
  /// when the admin hasn't published an Eggs category yet.
  static HomeCategoryItem _findEggsCategory(List<HomeCategoryItem> categories) {
    for (final category in categories) {
      if (category.name.toLowerCase().contains('egg')) return category;
    }
    return const HomeCategoryItem(id: 'eggs', name: 'Eggs');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mv = context.meatvo;
    final isOffline = ref.watch(isOfflineProvider).value ?? false;
    const oroshiBannerHeight = 150.0;
    final hidePopular = showsSameProducts(
      state.featuredProducts,
      state.bestSellingProducts,
    );

    if (state.pageError != null && !state.hasContent) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: isOffline
            ? OfflineStateView(
                onRetry: onRetryHome,
                isRetrying: state.isInitialLoading || state.isRefreshing,
              )
            : ErrorStateWidget(
                title: 'Unable to load content',
                message: 'Something went wrong. Please try again.',
                onRetry: onRetryHome,
              ),
      );
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: HomeSearchBar(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SearchScreen(),
                ),
              );
            },
          ),
        ),
        SliverToBoxAdapter(
          child: HeroBannerCarousel(
            banners: state.banners,
            isLoading: state.isBannerLoading,
            onBannerTap: onBannerTap,
            maxHeight: oroshiBannerHeight,
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: mv.spacing.md)),
        SliverToBoxAdapter(
          child: HomeCategoryRow(
            categories: state.categories,
            isLoading: state.isCategoriesLoading,
            onViewAll: onOpenCategories,
            onCategoryTap: onOpenCategory,
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: mv.spacing.md)),
        SliverToBoxAdapter(
          child: HomeProductSection(
            title: 'Best Sellers',
            products: state.bestSellingProducts,
            cart: state.cart,
            busyProductIds: state.busyProductIds,
            isLoading: state.isBestSellersLoading,
            errorMessage: state.bestSellersError,
            onViewAll: onOpenCategories,
            onRetry: onRetryPopular,
            onProductTap: onProductTap,
            onQuantityChange: onQuantityChange,
          ),
        ),
        if (!hidePopular)
          SliverToBoxAdapter(
            child: HomeProductSection(
              title: 'Fresh Today',
              products: state.featuredProducts,
              cart: state.cart,
              busyProductIds: state.busyProductIds,
              isLoading: state.isFeaturedLoading,
              errorMessage: state.featuredError,
              onViewAll: onOpenCategories,
              onRetry: onRetryFeatured,
              onProductTap: onProductTap,
              onQuantityChange: onQuantityChange,
            ),
          ),
        const SliverToBoxAdapter(
          child: HomeBrandFooter(),
        ),
        SliverPadding(padding: EdgeInsets.only(bottom: bottomPadding)),
      ],
    );
  }
}
