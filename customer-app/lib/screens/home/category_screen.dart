import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/cart_provider.dart';
import '../../providers/products_provider.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_error_state.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/product_card.dart';

class CategoryScreen extends ConsumerWidget {
  final int categoryId;
  final String title;

  const CategoryScreen({
    super.key,
    required this.categoryId,
    required this.title,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsByCategoryProvider(categoryId));
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: products.when(
        data: (items) {
          if (items.isEmpty) {
            return const AppEmptyState(
              icon: Icons.category_outlined,
              title: 'No products',
              subtitle: 'Is category me abhi products available nahi hain.',
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.72,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final product = items[index];
              return ProductCard(
                product: product,
                onTap: () => context.go('/product/${product.id}'),
                onAdd: () => ref.read(cartProvider.notifier).add(product),
              );
            },
          );
        },
        loading: () => GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.72,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: 6,
          itemBuilder: (_, __) => const LoadingSkeleton(height: 180),
        ),
        error: (err, _) => AppErrorState(
          title: 'Category load failed',
          subtitle: '$err',
          onRetry: () => ref.invalidate(productsByCategoryProvider(categoryId)),
        ),
      ),
    );
  }
}
