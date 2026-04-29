import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/products_provider.dart';
import '../../widgets/app_error_state.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/product_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final products = ref.watch(featuredProductsProvider);
    final cartCount = ref.watch(cartProvider.select((items) => items.fold<int>(0, (sum, i) => sum + i.quantity)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meatvo'),
        actions: [
          IconButton(
            onPressed: () => context.go('/orders'),
            icon: const Icon(Icons.receipt_long_outlined),
          ),
          IconButton(
            onPressed: () => context.go('/profile'),
            icon: const Icon(Icons.person_outline),
          ),
          Stack(
            children: [
              IconButton(
                onPressed: () => context.go('/cart'),
                icon: const Icon(Icons.shopping_cart_outlined),
              ),
              if (cartCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: CircleAvatar(
                    radius: 8,
                    child: Text('$cartCount', style: const TextStyle(fontSize: 10)),
                  ),
                ),
            ],
          ),
          IconButton(
            onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fresh Meat Delivered Fast', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('30 min delivery • 4.9 rating'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Categories', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          categories.when(
            data: (items) => SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final c = items[index];
                  return ActionChip(
                    label: Text(c.name),
                    onPressed: () => context.go('/products/${c.id}', extra: c.name),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemCount: items.length,
              ),
            ),
            loading: () => const LoadingSkeleton(height: 42),
            error: (err, _) => AppErrorState(
              title: 'Categories not loading',
              subtitle: '$err',
              onRetry: () => ref.invalidate(categoriesProvider),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text('Featured Products', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              TextButton(
                onPressed: () => context.go('/products'),
                child: const Text('See all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          products.when(
            data: (items) => GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
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
            ),
            loading: () => GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.72,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: 4,
              itemBuilder: (_, __) => const LoadingSkeleton(height: 160),
            ),
            error: (err, _) => AppErrorState(
              title: 'Products unavailable',
              subtitle: '$err',
              onRetry: () => ref.invalidate(featuredProductsProvider),
            ),
          ),
        ],
      ),
    );
  }
}
