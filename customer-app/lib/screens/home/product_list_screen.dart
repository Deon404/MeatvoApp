import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/cart_provider.dart';
import '../../providers/products_provider.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_error_state.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/product_card.dart';

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  String _query = '';
  int _page = 1;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(
      pagedProductsProvider(
        ProductListQuery(search: _query, page: _page),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('All Products')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Search products',
                suffixIcon: IconButton(
                  onPressed: () => setState(() {
                    _query = _controller.text.trim();
                    _page = 1;
                  }),
                  icon: const Icon(Icons.search),
                ),
              ),
              onSubmitted: (_) => setState(() {
                _query = _controller.text.trim();
                _page = 1;
              }),
            ),
          ),
          Expanded(
            child: products.when(
              data: (result) {
                final items = result.products;
                if (items.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.search_off,
                    title: 'No matching products',
                    subtitle: 'Try a different search keyword.',
                    actionLabel: 'Clear search',
                    onAction: () => setState(() {
                      _controller.clear();
                      _query = '';
                      _page = 1;
                    }),
                  );
                }
                return Column(
                  children: [
                    Expanded(
                      child: GridView.builder(
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
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                      child: Row(
                        children: [
                          OutlinedButton(
                            onPressed: _page > 1 ? () => setState(() => _page -= 1) : null,
                            child: const Text('Prev'),
                          ),
                          Expanded(
                            child: Center(
                              child: Text('Page ${result.page} / ${result.pages}'),
                            ),
                          ),
                          OutlinedButton(
                            onPressed: _page < result.pages ? () => setState(() => _page += 1) : null,
                            child: const Text('Next'),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                title: 'Products load failed',
                subtitle: '$err',
                onRetry: () => ref.invalidate(
                  pagedProductsProvider(ProductListQuery(search: _query, page: _page)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
