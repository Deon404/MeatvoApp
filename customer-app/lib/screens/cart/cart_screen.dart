import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/cart_item_model.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/app_empty_state.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('My Cart')),
      body: cartItems.isEmpty
          ? AppEmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Cart is empty',
              subtitle: 'Products add karke checkout continue karo.',
              actionLabel: 'Browse products',
              onAction: () => context.go('/products'),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    itemCount: cartItems.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      return ListTile(
                        title: Text(item.product.name),
                        subtitle: Text('${item.weight}g • ₹${item.product.price.toStringAsFixed(0)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => notifier.updateQuantity(item.product, item.weight, item.quantity - 1),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text('${item.quantity}'),
                            IconButton(
                              onPressed: () => notifier.updateQuantity(item.product, item.weight, item.quantity + 1),
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                            IconButton(
                              onPressed: () => _removeWithUndo(context, ref, item),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Total: ₹${notifier.total.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      FilledButton(
                        onPressed: () => context.go('/checkout/address'),
                        child: const Text('Checkout'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _removeWithUndo(BuildContext context, WidgetRef ref, CartItemModel item) {
    final notifier = ref.read(cartProvider.notifier);
    notifier.remove(item.product, item.weight);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.product.name} removed'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            notifier.add(
              item.product,
              quantity: item.quantity,
              weight: item.weight,
            );
          },
        ),
      ),
    );
  }
}
