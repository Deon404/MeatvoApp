import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../features/connectivity/connectivity_provider.dart';
import '../../features/home/widgets/home_category_row.dart';
import '../../features/home/widgets/home_search_bar.dart';
import '../../features/home/widgets/home_product_section.dart';
import '../../features/home/widgets/hero_banner_carousel.dart';
import '../../features/home/widgets/home_all_products_grid.dart';
import '../../features/home/widgets/home_brand_footer.dart';
import '../../models/banner_model.dart';
import '../../models/home_category_item.dart';
import '../../models/product_variant_model.dart';
import '../../ui/shells/offline_state_view.dart';
import '../../widgets/active_flow/active_flow_shell.dart';
import '../../widgets/location/unserviceable_location_view.dart';
import '../../viewmodels/home_state.dart';
import '../../widgets/error_states/error_state_widget.dart';
import '../../widgets/skeletons/home_content_skeleton.dart';
import '../../screens/search/search_screen.dart';
import '../../providers/store_settings_provider.dart';
import '../../utils/ordering_gate.dart';
import '../../widgets/store/store_closed_banner.dart';

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
    required this.onRetryAllProducts,
    required this.onBannerTap,
    required this.onProductTap,
    required this.onQuantityChange,
    required this.bottomPadding,
    this.onChangeLocation,
  });

  final HomeState state;
  final VoidCallback onOpenCategories;
  final ValueChanged<HomeCategoryItem> onOpenCategory;
  final VoidCallback onRetryHome;
  final VoidCallback onRetryCategories;
  final VoidCallback onRetryFeatured;
  final VoidCallback onRetryPopular;
  final VoidCallback onRetryAllProducts;
  final ValueChanged<BannerModel> onBannerTap;
  final ValueChanged<ProductWithVariants> onProductTap;
  final Future<void> Function(ProductWithVariants product, int nextQuantity)
      onQuantityChange;
  final double bottomPadding;
  final VoidCallback? onChangeLocation;

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mv = context.meatvo;
    final isOffline = ref.watch(isOfflineProvider).value ?? false;
    final storeStatus = ref.watch(storeSettingsSyncProvider);
    const oroshiBannerHeight = 150.0;
    final hidePopular = showsSameProducts(
      state.featuredProducts,
      state.bestSellingProducts,
    );
    final categorySections = state.categoryProductSections;
    final showCategorySections = categorySections.isNotEmpty;
    final showLoadingSections =
        state.isAllProductsLoading && state.allProducts.isEmpty;

    if (state.defaultAddress != null && state.isDeliveryServiceable == false) {
      return UnserviceableLocationView(
        onChangeLocation: onChangeLocation ?? () {},
      );
    }

    if (state.isInitialLoading && !state.hasContent) {
      return const SliverFillRemaining(
        hasScrollBody: true,
        child: HomeContentSkeleton(),
      );
    }

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

    Future<void> guardedQuantityChange(
      ProductWithVariants product,
      int nextQuantity,
    ) async {
      final current = state.cart
              .findItemByProductId(product.product.id)
              ?.quantity
              .round() ??
          0;
      await OrderingGate.guardQuantityChange(
        context,
        ref,
        currentQuantity: current,
        nextQuantity: nextQuantity,
        action: () => onQuantityChange(product, nextQuantity),
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
        SliverToBoxAdapter(child: StoreClosedBanner(status: storeStatus)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: ActiveFlowHeroCard(
              eyebrow: state.defaultAddress == null
                  ? 'Start with your location'
                  : (state.isDeliveryServiceable == false
                      ? 'Update delivery pin'
                      : 'Fresh delivery window open'),
              title: state.cart.totalQuantity > 0
                  ? '${state.cart.totalQuantity.round()} items ready in your cart'
                  : 'Fresh cuts, fast checkout, zero guesswork',
              subtitle: state.defaultAddress == null
                  ? 'Set your delivery pin to unlock live availability, pricing, and the fastest slot.'
                  : state.cart.totalQuantity > 0
                      ? 'Jump back into checkout or keep building the basket from today\'s best sellers.'
                      : 'Browse today\'s hero offers, quick categories, and the freshest cuts without leaving this page.',
              metrics: [
                ActiveFlowMetricPill(
                  label: 'Delivery',
                  value: state.defaultAddress == null
                      ? 'Select address'
                      : (state.isDeliveryServiceable == false
                          ? 'Check area'
                          : 'Serviceable'),
                  icon: Icons.location_on_outlined,
                  inverted: true,
                ),
                ActiveFlowMetricPill(
                  label: 'Cart',
                  value: state.cart.totalQuantity > 0
                      ? '${state.cart.totalQuantity.round()} items'
                      : 'Empty for now',
                  icon: Icons.shopping_bag_outlined,
                  inverted: true,
                ),
                ActiveFlowMetricPill(
                  label: 'Store',
                  value: storeStatus.isAcceptingOrders
                      ? 'Accepting orders'
                      : 'Opens soon',
                  icon: storeStatus.isAcceptingOrders
                      ? Icons.bolt_rounded
                      : Icons.schedule_rounded,
                  inverted: true,
                ),
              ],
            ),
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
        if (showLoadingSections) ...[
          SliverToBoxAdapter(
            child: HomeProductSection(
              title: 'Best Sellers',
              products: const [],
              cart: state.cart,
              busyProductIds: state.busyProductIds,
              isLoading: true,
              onViewAll: onOpenCategories,
              onRetry: onRetryAllProducts,
              onProductTap: onProductTap,
              onQuantityChange: guardedQuantityChange,
              storeStatus: storeStatus,
            ),
          ),
          SliverToBoxAdapter(
            child: HomeAllProductsGrid(
              products: const [],
              cart: state.cart,
              busyProductIds: state.busyProductIds,
              isLoading: true,
              onRetry: onRetryAllProducts,
              onProductTap: onProductTap,
              onQuantityChange: guardedQuantityChange,
              storeStatus: storeStatus,
            ),
          ),
        ] else ...[
          if (state.bestSellingProducts.isNotEmpty)
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
                onQuantityChange: guardedQuantityChange,
                storeStatus: storeStatus,
              ),
            ),
          if (!hidePopular && state.featuredProducts.isNotEmpty)
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
                onQuantityChange: guardedQuantityChange,
                storeStatus: storeStatus,
              ),
            ),
          if (showCategorySections)
            ...categorySections.map(
              (section) => SliverToBoxAdapter(
                child: HomeProductSection(
                  title: section.category.name,
                  products: section.products,
                  cart: state.cart,
                  busyProductIds: state.busyProductIds,
                  isLoading: false,
                  onViewAll: () => onOpenCategory(section.category),
                  onRetry: onRetryAllProducts,
                  onProductTap: onProductTap,
                  onQuantityChange: guardedQuantityChange,
                storeStatus: storeStatus,
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: HomeAllProductsGrid(
              products: state.allProducts,
              cart: state.cart,
              busyProductIds: state.busyProductIds,
              isLoading: state.isAllProductsLoading,
              errorMessage: state.allProductsError,
              onRetry: onRetryAllProducts,
              onProductTap: onProductTap,
              onQuantityChange: guardedQuantityChange,
              storeStatus: storeStatus,
            ),
          ),
        ],
        const SliverToBoxAdapter(
          child: HomeBrandFooter(
            align: CrossAxisAlignment.center,
            textAlign: TextAlign.center,
          ),
        ),
        SliverPadding(padding: EdgeInsets.only(bottom: bottomPadding)),
      ],
    );
  }
}
