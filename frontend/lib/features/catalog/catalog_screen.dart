import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/meatvo_swipe_tabs.dart';
import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../models/category_model.dart';
import '../../models/product_variant_model.dart';
import '../../screens/cart/cart_screen.dart';
import '../../screens/product/product_detail_screen.dart';
import '../../utils/app_transitions.dart';
import '../../widgets/cart/floating_cart_bar.dart';
import '../../ui/organisms/meatvo_product_card.dart';
import '../../ui/organisms/product_card_adapter.dart';
import '../../providers/store_settings_provider.dart';
import '../../ui/organisms/product_card_bindings.dart';
import '../../utils/ordering_gate.dart';
import '../../widgets/store/store_closed_banner.dart';
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

class _CatalogScreenState extends ConsumerState<CatalogScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  TabController? _tabController;
  MeatvoSwipeTabsHelper? _tabHelper;
  DateTime? _categorySwitchAt;
  Timer? _shimmerTimer;

  static const _minCategoryShimmer = Duration(seconds: 2);
  static const _comingSoonRedirectDelay = Duration(seconds: 4);

  static const _defaultCategories = [
    CategoryModel(id: 'chicken', name: 'Chicken'),
    CategoryModel(id: 'eggs', name: 'Eggs'),
    CategoryModel(id: 'fish', name: 'Fish', isActive: false),
    CategoryModel(id: 'mutton', name: 'Mutton', isActive: false),
  ];

  List<CategoryModel> _effectiveCategories(CatalogState state) {
    if (state.categories.isNotEmpty) return state.categories;
    return _defaultCategories;
  }

  MeatvoTabItem _tabItemForCategory(CategoryModel category) {
    final available = CatalogViewModel.isCategoryAvailable(category);
    return MeatvoTabItem(
      label: available ? category.name : '${category.name} (Soon)',
      enabled: true,
    );
  }

  void _handleCategoryRedirect(
    String? targetCategory,
    List<CategoryModel> categories,
  ) {
    if (targetCategory == null || _tabController == null) return;
    final index = categories.indexWhere(
      (cat) => cat.name.toLowerCase() == targetCategory.toLowerCase(),
    );
    if (index < 0) return;
    _tabController!.animateTo(index);
    _tabHelper?.lastReportedIndex = index;
    _beginCategorySwitch();
  }

  @override
  void dispose() {
    _shimmerTimer?.cancel();
    _disposeTabController();
    _searchController.dispose();
    super.dispose();
  }

  void _beginCategorySwitch() {
    _categorySwitchAt = DateTime.now();
    _shimmerTimer?.cancel();
    _shimmerTimer = Timer(_minCategoryShimmer, () {
      if (mounted) setState(() {});
    });
  }

  bool _shouldShowCategoryShimmer(CatalogState state, bool isSelected) {
    if (!isSelected) return false;
    if (state.isRefreshing || state.isLoading) return true;
    if (_categorySwitchAt == null) return false;
    return DateTime.now().difference(_categorySwitchAt!) < _minCategoryShimmer;
  }

  Widget _buildCategoryShimmer({
    required MeatvoThemeData mv,
    required double cardHeight,
    required CatalogViewModel notifier,
  }) {
    return RefreshIndicator(
      color: mv.brandPrimary,
      onRefresh: () => notifier.load(refresh: true),
      child: CustomScrollView(
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
      ),
    );
  }

  void _disposeTabController() {
    if (_tabController != null) {
      _tabController!.removeListener(_tabHelper?.handleTabChange ?? () {});
      _tabController!.dispose();
      _tabController = null;
      _tabHelper = null;
    }
  }

  void _syncTabController({
    required List<CategoryModel> categories,
    required String selectedCategory,
    required CatalogViewModel notifier,
  }) {
    if (categories.isEmpty) {
      _disposeTabController();
      return;
    }

    final selectedIndex = categories.indexWhere(
      (cat) => cat.name.toLowerCase() == selectedCategory.toLowerCase(),
    );
    final initialIndex = selectedIndex >= 0 ? selectedIndex : 0;

    if (_tabController == null || _tabController!.length != categories.length) {
      _disposeTabController();
      _tabController = TabController(
        length: categories.length,
        vsync: this,
        initialIndex: initialIndex,
      );
      _tabHelper = MeatvoSwipeTabsHelper(
        tabs: categories.map(_tabItemForCategory).toList(),
        controller: _tabController!,
        snapBackFromDisabled: false,
        onIndexChanged: (index) {
          if (index < 0 || index >= categories.length) return;
          _beginCategorySwitch();
          notifier.setCategory(categories[index].name);
        },
      );
      _tabHelper!.lastReportedIndex = initialIndex;
      _tabController!.addListener(_tabHelper!.handleTabChange);
      return;
    }
    if (_tabController!.index != initialIndex &&
        !_tabController!.indexIsChanging) {
      _tabController!.animateTo(initialIndex);
      _tabHelper?.lastReportedIndex = initialIndex;
    }
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
    final tabBottomPad = widget.showBackButton
        ? MeatvoLayout.catalogScrollBottomInset(context)
        : MeatvoLayout.browsingScrollBottomInset(context);

    ref.listen(isOfflineProvider, (prev, next) {
      final wasOffline = prev?.value ?? false;
      final offline = next.value ?? false;
      if (wasOffline && !offline) notifier.load(refresh: true);
    });

    ref.listen(provider, (prev, next) {
      if (prev?.searchQuery != next.searchQuery &&
          next.searchQuery.isEmpty &&
          _searchController.text.isNotEmpty) {
        _searchController.clear();
      }
    });

    if (state.categories.isNotEmpty) {
      if (_tabController == null ||
          _tabController!.length != state.categories.length) {
        _syncTabController(
          categories: state.categories,
          selectedCategory: state.selectedCategory,
          notifier: notifier,
        );
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _syncTabController(
            categories: state.categories,
            selectedCategory: state.selectedCategory,
            notifier: notifier,
          );
        });
      }
    } else if (_tabController == null) {
      _syncTabController(
        categories: _defaultCategories,
        selectedCategory: state.selectedCategory,
        notifier: notifier,
      );
    }

    final categories = _effectiveCategories(state);

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
          _buildBody(
            context: context,
            state: state,
            notifier: notifier,
            mv: mv,
            cardHeight: cardHeight,
            tabBottomPad: tabBottomPad,
            categories: categories,
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

  Widget _buildBody({
    required BuildContext context,
    required CatalogState state,
    required CatalogViewModel notifier,
    required MeatvoThemeData mv,
    required double cardHeight,
    required double tabBottomPad,
    required List<CategoryModel> categories,
  }) {
    if (state.isLoading && state.allProducts.isEmpty && state.categories.isEmpty) {
      return _buildSwipeCatalog(
        context: context,
        state: state,
        notifier: notifier,
        mv: mv,
        cardHeight: cardHeight,
        tabBottomPad: tabBottomPad,
        categories: categories,
        showLoading: true,
      );
    }

    if (state.errorMessage != null && state.allProducts.isEmpty) {
      return _buildSwipeCatalog(
        context: context,
        state: state,
        notifier: notifier,
        mv: mv,
        cardHeight: cardHeight,
        tabBottomPad: tabBottomPad,
        categories: categories,
        showError: true,
      );
    }

    return _buildSwipeCatalog(
      context: context,
      state: state,
      notifier: notifier,
      mv: mv,
      cardHeight: cardHeight,
      tabBottomPad: tabBottomPad,
      categories: categories,
    );
  }

  Widget _buildSwipeCatalog({
    required BuildContext context,
    required CatalogState state,
    required CatalogViewModel notifier,
    required MeatvoThemeData mv,
    required double cardHeight,
    required double tabBottomPad,
    required List<CategoryModel> categories,
    bool showLoading = false,
    bool showError = false,
  }) {
    if (_tabController == null) {
      return RefreshIndicator(
        color: mv.brandPrimary,
        onRefresh: () => notifier.load(refresh: true),
        child: CustomScrollView(
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
        ),
      );
    }

    return MeatvoSwipeTabs(
      controller: _tabController!,
      isScrollable: true,
      allowDisabledTabs: true,
      tabs: categories.map(_tabItemForCategory).toList(),
      children: [
        for (final category in categories)
          _buildCategoryPage(
            context: context,
            category: category,
            state: state,
            notifier: notifier,
            mv: mv,
            cardHeight: cardHeight,
            tabBottomPad: tabBottomPad,
            categories: categories,
            showLoading: showLoading,
            showError: showError,
          ),
      ],
    );
  }

  Widget _buildCategoryPage({
    required BuildContext context,
    required CategoryModel category,
    required CatalogState state,
    required CatalogViewModel notifier,
    required MeatvoThemeData mv,
    required double cardHeight,
    required double tabBottomPad,
    required List<CategoryModel> categories,
    bool showLoading = false,
    bool showError = false,
  }) {
    final isSelected = category.name.toLowerCase() ==
        state.selectedCategory.toLowerCase();
    final isSearchActive = state.searchQuery.isNotEmpty;
    final metadataUnavailable = !CatalogViewModel.isCategoryAvailable(category);

    if (isSearchActive && isSelected) {
      return _buildSearchResultsPage(
        context: context,
        state: state,
        notifier: notifier,
        mv: mv,
        cardHeight: cardHeight,
        tabBottomPad: tabBottomPad,
        showError: showError,
      );
    }

    if (metadataUnavailable) {
      return _ComingSoonRedirectPage(
        category: category,
        notifier: notifier,
        mv: mv,
        categories: categories,
        isSelected: isSelected,
        onRedirect: _handleCategoryRedirect,
      );
    }

    if (showError && isSelected) {
      return RefreshIndicator(
        color: mv.brandPrimary,
        onRefresh: () => notifier.load(refresh: true),
        child: CustomScrollView(
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
        ),
      );
    }

    if (_shouldShowCategoryShimmer(state, isSelected)) {
      return _buildCategoryShimmer(
        mv: mv,
        cardHeight: cardHeight,
        notifier: notifier,
      );
    }

    if (!isSelected) {
      return const SizedBox.shrink();
    }

    final products = state.filteredProducts;

    if (products.isEmpty &&
        state.searchQuery.isEmpty &&
        state.selectedSort == 'All' &&
        !state.isRefreshing &&
        !state.isLoading) {
      return _ComingSoonRedirectPage(
        category: category,
        notifier: notifier,
        mv: mv,
        categories: categories,
        isSelected: true,
        onRedirect: _handleCategoryRedirect,
      );
    }

    return RefreshIndicator(
      color: mv.brandPrimary,
      onRefresh: () => notifier.load(refresh: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: StoreClosedBanner(
              status: ref.watch(storeSettingsSyncProvider),
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
                    return _buildProductCard(
                      product: product,
                      state: state,
                      notifier: notifier,
                    );
                  },
                  childCount: products.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openProduct(ProductWithVariants product) {
    context.pushScale(
      ProductDetailScreen(productId: product.product.id),
    );
  }

  Widget _buildSearchResultsPage({
    required BuildContext context,
    required CatalogState state,
    required CatalogViewModel notifier,
    required MeatvoThemeData mv,
    required double cardHeight,
    required double tabBottomPad,
    required bool showError,
  }) {
    if (showError) {
      return RefreshIndicator(
        color: mv.brandPrimary,
        onRefresh: () => notifier.load(refresh: true),
        child: CustomScrollView(
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
        ),
      );
    }

    if (_shouldShowCategoryShimmer(state, true)) {
      return _buildCategoryShimmer(
        mv: mv,
        cardHeight: cardHeight,
        notifier: notifier,
      );
    }

    final products = state.filteredProducts;

    return RefreshIndicator(
      color: mv.brandPrimary,
      onRefresh: () => notifier.load(refresh: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: StoreClosedBanner(
              status: ref.watch(storeSettingsSyncProvider),
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
                      products.isEmpty
                          ? 'No results across all categories'
                          : '${products.length} results across all categories',
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
                  buttonLabel: 'Clear search',
                  onAction: () {
                    _searchController.clear();
                    notifier.setSearchQuery('');
                    notifier.setSort('All');
                  },
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
                    return _buildProductCard(
                      product: product,
                      state: state,
                      notifier: notifier,
                    );
                  },
                  childCount: products.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductCard({
    required ProductWithVariants product,
    required CatalogState state,
    required CatalogViewModel notifier,
  }) {
    final storeStatus = ref.watch(storeSettingsSyncProvider);
    final id = product.product.id;
    final qty =
        state.cart.findItemByProductId(id)?.quantity.round() ?? 0;
    final busy = state.busyProductIds.contains(id);

    Future<void> guardedChange(int nextQuantity) async {
      await OrderingGate.guardQuantityChange(
        context,
        ref,
        currentQuantity: qty,
        nextQuantity: nextQuantity,
        action: () => notifier.changeCartQuantity(product, nextQuantity),
      );
    }

    final bindings = ProductCardBindings.forProduct(
      storeStatus: storeStatus,
      product: product,
      cart: state.cart,
      onQuantityChange: (p, next) => guardedChange(next),
    );

    return MeatvoProductCard(
      product: product.product.copyWith(
        unit: ProductCardAdapter.displayUnit(product),
      ),
      displayPrice: ProductCardAdapter.displayPrice(product),
      displayUnit: ProductCardAdapter.displayUnit(product),
      originalPrice: ProductCardAdapter.originalPrice(product),
      discountPercent: ProductCardAdapter.discountPercent(product),
      quantity: qty,
      isBusy: busy,
      inStock: bindings.inStock,
      orderingPaused: bindings.orderingPaused,
      layout: MeatvoProductCardLayout.grid,
      onTap: () => _openProduct(product),
      onAdd: bindings.onAdd,
      onIncrement: bindings.onIncrement,
      onDecrement: bindings.onDecrement,
    );
  }
}

class _ComingSoonRedirectPage extends StatefulWidget {
  const _ComingSoonRedirectPage({
    required this.category,
    required this.notifier,
    required this.mv,
    required this.categories,
    required this.isSelected,
    required this.onRedirect,
  });

  final CategoryModel category;
  final CatalogViewModel notifier;
  final MeatvoThemeData mv;
  final List<CategoryModel> categories;
  final bool isSelected;
  final void Function(String?, List<CategoryModel>) onRedirect;

  @override
  State<_ComingSoonRedirectPage> createState() =>
      _ComingSoonRedirectPageState();
}

class _ComingSoonRedirectPageState extends State<_ComingSoonRedirectPage> {
  Timer? _redirectTimer;

  @override
  void initState() {
    super.initState();
    if (widget.isSelected) {
      _startRedirectTimer();
    }
  }

  @override
  void didUpdateWidget(_ComingSoonRedirectPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isSelected) {
      _redirectTimer?.cancel();
      _redirectTimer = null;
      return;
    }
    if (!oldWidget.isSelected && widget.isSelected) {
      _startRedirectTimer();
    }
  }

  void _startRedirectTimer() {
    _redirectTimer?.cancel();
    _redirectTimer = Timer(_CatalogScreenState._comingSoonRedirectDelay, () {
      if (!mounted || !widget.isSelected) return;
      final target = widget.notifier.redirectToFirstAvailableCategory();
      widget.onRedirect(target, widget.categories);
    });
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: widget.mv.brandPrimary,
      onRefresh: () => widget.notifier.load(refresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          SizedBox(height: widget.mv.spacing.xl),
          EmptyStateWidget.comingSoon(
            categoryName: widget.category.name,
          ),
        ],
      ),
    );
  }
}
