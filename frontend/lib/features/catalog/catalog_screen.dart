import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../models/product_variant_model.dart';
import '../../screens/cart/cart_screen.dart';
import '../../screens/product/product_detail_screen.dart';
import '../../utils/app_transitions.dart';
import '../../widgets/cart/floating_cart_bar.dart';
import '../../ui/organisms/meatvo_product_card.dart';
import '../../ui/organisms/product_card_adapter.dart';
import '../../ui/shells/offline_state_view.dart';
import '../../widgets/common/empty_state.dart';
import '../../ui/shells/meatvo_layout.dart';
import '../../widgets/skeletons/product_card_skeleton.dart';
import '../connectivity/connectivity_provider.dart';
import 'catalog_provider.dart';
import 'catalog_state.dart';
import 'catalog_viewmodel.dart';
import 'widgets/catalog_filter_sheet.dart';
import 'widgets/catalog_search_header.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({
    super.key,
    this.initialCategory,
    this.initialCategoryId,
    this.showBackButton = false,
  });

  final String? initialCategory;
  final int? initialCategoryId;
  final bool showBackButton;

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = catalogViewModelProvider((
      categoryName: widget.initialCategory,
      categoryId: widget.initialCategoryId,
    ));
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final mv = context.meatvo;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardHeight = MeatvoProductCard.gridCardHeight(screenWidth);
    final products = state.filteredProducts;
    final tabBottomPad = widget.showBackButton
        ? MeatvoLayout.catalogScrollBottomInset(context)
        : MeatvoLayout.browsingScrollBottomInset(context);

    // NOTE: previous build() debug-spam logger removed — it printed on
    // every catalog rebuild (10+ times/second during scroll) which made
    // production-style debugging impossible. Errors are still surfaced
    // via CatalogState.errorMessage on the UI itself.

    ref.listen(isOfflineProvider, (prev, next) {
      final wasOffline = prev?.value ?? false;
      final offline = next.value ?? false;
      if (wasOffline && !offline) notifier.load(refresh: true);
    });

    return Scaffold(
      backgroundColor: mv.surfaceWarm,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(CatalogSearchHeader.kToolbarHeight),
        child: Material(
          color: mv.surfaceCard,
          elevation: 0,
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: CatalogSearchHeader.kToolbarHeight,
              child: CatalogSearchHeader(
                controller: _searchController,
                onChanged: notifier.setSearchQuery,
                showBack: widget.showBackButton,
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            color: mv.brandPrimary,
            onRefresh: () => notifier.load(refresh: true),
            child: _buildBody(
              context: context,
              state: state,
              notifier: notifier,
              mv: mv,
              cardHeight: cardHeight,
              products: products,
              tabBottomPad: tabBottomPad,
            ),
          ),
          if (widget.showBackButton)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.paddingOf(context).bottom +
                  MeatvoLayout.floatingCartBottomGap,
              child: FloatingCartBar(
                onViewCartTapped: _openCart,
              ),
            ),
        ],
      ),
    );
  }

  void _openCart() {
    context.pushSlideRight(const CartScreen());
  }

  /// Single source of truth for the body. Returns one of:
  ///   • shimmer skeleton (loading + no cached products)
  ///   • offline retry view (network error + no cached products)
  ///   • catalog grid with chips/sort row (products present)
  ///   • friendly empty state (admin has zero products in this category)
  ///
  /// The previous implementation packed all of these into one `slivers: [...]`
  /// list using collection-if + spread. On some Android devices the spread
  /// combined with `SliverFillRemaining` rendered with zero extent on first
  /// frame → a fully blank scaffold body (the screenshot the user reported).
  /// Splitting it into a single concrete tree per state removes that risk.
  Widget _buildBody({
    required BuildContext context,
    required CatalogState state,
    required CatalogViewModel notifier,
    required MeatvoThemeData mv,
    required double cardHeight,
    required List<ProductWithVariants> products,
    required double tabBottomPad,
  }) {
    // 1. Loading — only when we truly have nothing cached.
    if (state.isLoading && state.allProducts.isEmpty) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.all(mv.spacing.md),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: mv.spacing.sm,
                crossAxisSpacing: mv.spacing.sm,
                mainAxisExtent: cardHeight,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, __) => const ProductCardSkeleton(),
                childCount: 4,
              ),
            ),
          ),
        ],
      );
    }

    // 2. Hard error with no cached products — retry view.
    if (state.errorMessage != null && state.allProducts.isEmpty) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: OfflineStateView(
              onRetry: () => notifier.load(refresh: true),
              isRetrying: state.isRefreshing,
            ),
          ),
        ],
      );
    }

    // 3. Backend returned an empty product set — friendly empty state
    //    rendered as a flat widget (NOT a sliver) so the layout cannot
    //    collapse to zero height. The user previously saw a blank body
    //    here because SliverFillRemaining inside a spread `else ...[]`
    //    occasionally rendered with extent=0 on first build.
    if (state.allProducts.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          SizedBox(height: mv.spacing.xl),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: mv.spacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 64,
                    color: mv.textMuted,
                  ),
                  SizedBox(height: mv.spacing.md),
                  Text(
                    'No products here yet',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: mv.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  SizedBox(height: mv.spacing.sm),
                  Text(
                    'We are adding fresh items soon. Try another category or check back later.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: mv.textSecondary,
                        ),
                  ),
                  SizedBox(height: mv.spacing.lg),
                  ElevatedButton.icon(
                    onPressed: () => notifier.load(refresh: true),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Try again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mv.brandPrimary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // 4. We have products. Build chips + sort row + grid (or filter-empty).
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        if (state.categories.isNotEmpty)
          SliverToBoxAdapter(
            // Horizontal scrolling chips. Important:
            //   • Do NOT wrap each chip in `Center` — inside a horizontal
            //     ListView every item gets UNBOUNDED width, and `Center`
            //     tries to expand to fill it → "BoxConstraints forces an
            //     infinite width" crash that cascades into a fully blank
            //     screen. Wrap each chip in a vertically centering
            //     `Align(widthFactor: 1.0)` instead, which sizes to its
            //     child on the cross axis.
            //   • Height bumped from 44 → 56 because FilterChip's default
            //     tap target (~48px) was overflowing by 2px and printing
            //     RenderFlex overflow warnings on every build.
            child: SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(
                  horizontal: mv.spacing.md,
                  vertical: mv.spacing.xs,
                ),
                itemCount: state.categories.length,
                separatorBuilder: (_, __) => SizedBox(width: mv.spacing.xs),
                itemBuilder: (context, index) {
                  final cat = state.categories[index];
                  final selected = cat.name.toLowerCase() ==
                      state.selectedCategory.toLowerCase();
                  final isInactive = !cat.isActive;
                  // Each chip is wrapped in a vertically-centering `Center`
                  // with `widthFactor: 1.0` + `heightFactor: 1.0` so:
                  //   • The chip sizes to its OWN intrinsic width
                  //     (a horizontal ListView gives unbounded width to
                  //     every item — a plain `Center` would try to fill
                  //     that infinity and throw the classic
                  //     "BoxConstraints forces an infinite width" crash).
                  //   • The chip is vertically centered inside the 56px
                  //     row, removing the 2px FilterChip overflow that
                  //     previously logged a RenderFlex warning every
                  //     build.
                  return Center(
                    widthFactor: 1.0,
                    heightFactor: 1.0,
                    child: FilterChip(
                      label: Text(
                        isInactive ? '${cat.name} (Coming Soon)' : cat.name,
                      ),
                      selected: selected,
                      onSelected: (_) => notifier.setCategory(cat.name),
                      selectedColor: const Color(0xFFC8102E),
                      backgroundColor: Colors.white,
                      side: selected
                          ? BorderSide.none
                          : const BorderSide(
                              color: Color(0xFFEEEEEE),
                              width: 1,
                            ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      labelStyle: TextStyle(
                        color: selected
                            ? Colors.white
                            : isInactive
                                ? mv.textMuted
                                : const Color(0xFF6B6B6B),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: mv.spacing.sm,
                        vertical: 0,
                      ),
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      showCheckmark: false,
                    ),
                  );
                },
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              mv.spacing.md,
              mv.spacing.sm,
              mv.spacing.md,
              mv.spacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${products.length} items',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: mv.textSecondary,
                        ),
                  ),
                ),
                Flexible(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final sort = await CatalogFilterSheet.show(
                        context,
                        selectedSort: state.selectedSort,
                      );
                      if (sort != null) notifier.setSort(sort);
                    },
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: Text(state.selectedSort == 'All'
                        ? 'Sort & filter'
                        : state.selectedSort),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: mv.brandPrimary,
                      side: BorderSide(color: mv.border),
                      padding: EdgeInsets.symmetric(
                        horizontal: mv.spacing.sm,
                        vertical: mv.spacing.xs,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (products.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(mv.spacing.xl),
              child: EmptyStateWidget.search(
                fullScreen: false,
                buttonLabel: state.searchQuery.isNotEmpty ||
                        state.selectedSort != 'All'
                    ? 'Clear filters'
                    : null,
                onAction: state.searchQuery.isNotEmpty ||
                        state.selectedSort != 'All'
                    ? () {
                        _searchController.clear();
                        notifier.setSearchQuery('');
                        notifier.setSort('All');
                      }
                    : null,
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              mv.spacing.md,
              mv.spacing.xs,
              mv.spacing.md,
              tabBottomPad,
            ),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: mv.spacing.sm,
                crossAxisSpacing: mv.spacing.sm,
                mainAxisExtent: cardHeight,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final product = products[index];
                  final id = product.product.id;
                  final qty = state.cart
                          .findItemByProductId(id)
                          ?.quantity
                          .round() ??
                      0;
                  final busy = state.busyProductIds.contains(id);
                  final canAdd = ProductCardAdapter.canAdd(product);

                  return MeatvoProductCard(
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
                    layout: MeatvoProductCardLayout.grid,
                    onTap: () => _openProduct(product),
                    onAdd: canAdd
                        ? () => notifier.changeCartQuantity(
                              product,
                              qty == 0 ? 1 : qty + 1,
                            )
                        : null,
                    onIncrement: canAdd
                        ? () => notifier.changeCartQuantity(
                              product,
                              qty + 1,
                            )
                        : null,
                    onDecrement: qty > 0
                        ? () => notifier.changeCartQuantity(
                              product,
                              qty - 1,
                            )
                        : null,
                  );
                },
                childCount: products.length,
              ),
            ),
          ),
      ],
    );
  }

  void _openProduct(ProductWithVariants product) {
    context.pushScale(
      ProductDetailScreen(productId: product.product.id),
    );
  }
}
