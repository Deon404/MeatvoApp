import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../models/product_variant_model.dart';
import '../../providers/wishlist_provider.dart';
import '../../screens/product/product_detail_screen.dart';
import '../../ui/organisms/meatvo_product_card.dart';
import '../../ui/organisms/product_card_adapter.dart';
import '../../providers/store_settings_provider.dart';
import '../../ui/organisms/product_card_bindings.dart';
import '../../utils/ordering_gate.dart';
import '../../widgets/store/store_closed_banner.dart';
import '../../utils/app_transitions.dart';
import '../../utils/responsive_helper.dart';
import '../../viewmodels/home_provider.dart';
import '../../widgets/common/error_state.dart';
import '../../widgets/empty_states/empty_state_widget.dart';
import '../../widgets/skeletons/product_card_skeleton.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    R.init(context);
    final mv = context.meatvo;
    final wishlistIds = ref.watch(wishlistProvider);
    final productsAsync = ref.watch(wishlistProductsProvider);
    final count = wishlistIds.length;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: mv.surfaceWarm,
      appBar: AppBar(
        title: Text(count > 0 ? 'My Wishlist ($count)' : 'My Wishlist'),
        backgroundColor: mv.surfaceCard,
        foregroundColor: mv.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: wishlistIds.isEmpty
            ? EmptyStateWidget(
                icon: Icons.favorite_border,
                title: 'No items saved',
                description:
                    'Save your favourite cuts here for quick access later.',
                actionLabel: 'Browse Products',
                onAction: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                iconColor: mv.brandPrimary,
              )
            : productsAsync.when(
                loading: () => const _WishlistLoadingGrid(),
                error: (_, __) => ErrorStateWidget(
                  title: 'Could not load wishlist',
                  message: 'Check your connection and try again.',
                  onRetry: () => ref.invalidate(wishlistProductsProvider),
                  fullScreen: false,
                  icon: Icons.favorite_border,
                  iconColor: mv.brandPrimary,
                ),
                data: (products) => _WishlistGrid(
                  mv: mv,
                  products: products,
                  onOpenProduct: (productId) => _openProduct(context, productId),
                ),
              ),
      ),
    );
  }

  Future<void> _openProduct(BuildContext context, String productId) async {
    await context.pushScale(ProductDetailScreen(productId: productId));
  }
}

class _WishlistLoadingGrid extends StatelessWidget {
  const _WishlistLoadingGrid();

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final cardHeight =
        MeatvoProductCard.gridCardHeight(MediaQuery.sizeOf(context).width);

    return GridView.builder(
      padding: EdgeInsets.all(mv.spacing.md),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: mv.spacing.md,
        crossAxisSpacing: mv.spacing.md,
        mainAxisExtent: cardHeight,
      ),
      itemCount: 4,
      itemBuilder: (_, __) => const ProductCardSkeleton(),
    );
  }
}

class _WishlistGrid extends ConsumerWidget {
  const _WishlistGrid({
    required this.mv,
    required this.products,
    required this.onOpenProduct,
  });

  final MeatvoThemeData mv;
  final List<ProductWithVariants> products;
  final Future<void> Function(String productId) onOpenProduct;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (products.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.favorite_border,
        title: 'No items saved',
        description: 'Some saved items may no longer be available.',
        actionLabel: 'Browse Products',
        onAction: () {
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
        iconColor: mv.brandPrimary,
      );
    }

    final homeState = ref.watch(homeViewModelProvider);
    final storeStatus = ref.watch(storeSettingsSyncProvider);
    final cart = homeState.cart;
    final busyProductIds = homeState.busyProductIds;
    final changeQty = ref.read(homeViewModelProvider.notifier).changeCartQuantity;
    final cardHeight =
        MeatvoProductCard.gridCardHeight(MediaQuery.sizeOf(context).width);

    return Column(
      children: [
        StoreClosedBanner(status: storeStatus),
        Expanded(
          child: GridView.builder(
      padding: EdgeInsets.all(mv.spacing.md),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: mv.spacing.md,
        crossAxisSpacing: mv.spacing.md,
        mainAxisExtent: cardHeight,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final item = products[index];
        final productId = item.product.id;
        final qty = cart.findItemByProductId(productId)?.quantity.round() ?? 0;
        final busy = busyProductIds.contains(productId);
        final bindings = ProductCardBindings.forProduct(
          storeStatus: storeStatus,
          product: item,
          cart: cart,
          onQuantityChange: (p, next) async {
            await OrderingGate.guardQuantityChange(
              context,
              ref,
              currentQuantity: qty,
              nextQuantity: next,
              action: () => changeQty(p, next),
            );
          },
        );

        return MeatvoProductCard(
          product: item.product,
          displayPrice: ProductCardAdapter.displayPrice(item),
          displayUnit: ProductCardAdapter.displayUnit(item),
          originalPrice: ProductCardAdapter.originalPrice(item),
          discountPercent: ProductCardAdapter.discountPercent(item),
          quantity: qty,
          isBusy: busy,
          inStock: bindings.inStock,
          orderingPaused: bindings.orderingPaused,
          layout: MeatvoProductCardLayout.grid,
          onTap: () => onOpenProduct(productId),
          onAdd: bindings.onAdd,
          onIncrement: bindings.onIncrement,
          onDecrement: bindings.onDecrement,
        );
      },
          ),
        ),
      ],
    );
  }
}
