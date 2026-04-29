import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/cart_provider.dart';
import '../../providers/products_provider.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final int productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  int? _selectedWeight;

  @override
  Widget build(BuildContext context) {
    final asyncProduct = ref.watch(productDetailProvider(widget.productId));
    return Scaffold(
      appBar: AppBar(title: const Text('Product Detail')),
      body: asyncProduct.when(
        data: (product) {
          _selectedWeight ??= product.weightVariants.isNotEmpty ? product.weightVariants.first : 500;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SizedBox(
                height: 220,
                child: product.imageUrl.isEmpty
                    ? Container(
                        color: Colors.grey.shade100,
                        child: const Icon(Icons.fastfood, size: 48),
                      )
                    : Image.network(product.imageUrl, fit: BoxFit.cover),
              ),
              const SizedBox(height: 12),
              Text(product.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('₹${product.price.toStringAsFixed(0)}'),
              const SizedBox(height: 12),
              Text(product.description),
              const SizedBox(height: 16),
              const Text('Select Weight', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: (product.weightVariants.isEmpty ? [500] : product.weightVariants)
                    .map(
                      (w) => ChoiceChip(
                        label: Text('$w g'),
                        selected: _selectedWeight == w,
                        onSelected: (_) => setState(() => _selectedWeight = w),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  ref.read(cartProvider.notifier).add(product, weight: _selectedWeight);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to cart')));
                },
                child: const Text('Add To Cart'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
