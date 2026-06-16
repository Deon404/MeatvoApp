import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/widgets/product_card.dart';
import '../../models/product_variant_model.dart';
import '../../providers/wishlist_provider.dart';
import '../../screens/product/product_detail_screen.dart';
import '../../utils/app_transitions.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/empty_states/empty_state_widget.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    R.init(context);
    final wishlistIds = ref.watch(wishlistProvider);
    final productsAsync = ref.watch(wishlistProductsProvider);
    final count = wishlistIds.length;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(count > 0 ? 'My Wishlist ($count)' : 'My Wishlist'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: wishlistIds.isEmpty
            ? EmptyStateWidget(
                icon: Icons.favorite_border,
                title: 'No items saved',
                description: 'Save your favourite cuts here for quick access later.',
                actionLabel: 'Browse Products',
                onAction: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                iconColor: AppColors.primary,
              )
            : productsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => _WishlistGrid(
                  products: const [],
                  onRemove: (productId) => _removeFromWishlist(context, ref, productId),
                  onOpenProduct: (productId) => _openProduct(context, productId),
                ),
                data: (products) => _WishlistGrid(
                  products: products,
                  onRemove: (productId) => _removeFromWishlist(context, ref, productId),
                  onOpenProduct: (productId) => _openProduct(context, productId),
                ),
              ),
      ),
    );
  }

  void _removeFromWishlist(
    BuildContext context,
    WidgetRef ref,
    String productId,
  ) {
    ref.read(wishlistProvider.notifier).remove(productId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Removed'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _openProduct(BuildContext context, String productId) async {
    await context.pushScale(ProductDetailScreen(productId: productId));
  }
}

class _WishlistGrid extends StatelessWidget {
  const _WishlistGrid({
    required this.products,
    required this.onRemove,
    required this.onOpenProduct,
  });

  final List<ProductWithVariants> products;
  final void Function(String productId) onRemove;
  final Future<void> Function(String productId) onOpenProduct;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.favorite_border,
        title: 'No items saved',
        description: 'Some saved items may no longer be available.',
        actionLabel: 'Browse Products',
        onAction: () {
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
        iconColor: AppColors.primary,
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.72,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final item = products[index];
        final product = item.product;
        final productId = product.id;

        return ProductCard(
          name: product.name,
          weight: item.getDisplayUnit(),
          price: item.getPriceDisplayText(),
          imageUrl: product.primaryImageUrl,
          showWishlistHeart: true,
          isWishlisted: true,
          onWishlistTap: () => onRemove(productId),
          onTap: () => onOpenProduct(productId),
        );
      },
    );
  }
}
