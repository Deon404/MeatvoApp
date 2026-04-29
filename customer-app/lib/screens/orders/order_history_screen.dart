import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/orders_provider.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_error_state.dart';
import '../../widgets/loading_skeleton.dart';

class OrderHistoryScreen extends ConsumerWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider);
    final page = ref.watch(ordersPageProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(ordersProvider),
        child: ordersAsync.when(
          data: (result) {
            if (result.orders.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  AppEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No orders yet',
                    subtitle: 'Products browse karke first order place karo.',
                    actionLabel: 'Shop now',
                    onAction: () => context.go('/home'),
                  ),
                ],
              );
            }
            return ListView(
              children: [
                ...result.orders.map(
                  (order) => ListTile(
                    title: Text('Order #${order.id}'),
                    subtitle: Text('${order.status} • ₹${order.totalAmount.toStringAsFixed(0)}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/orders/${order.id}'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      OutlinedButton(
                        onPressed: page > 1
                            ? () => ref.read(ordersPageProvider.notifier).state = page - 1
                            : null,
                        child: const Text('Prev'),
                      ),
                      Expanded(
                        child: Center(child: Text('Page ${result.page}/${result.pages}')),
                      ),
                      OutlinedButton(
                        onPressed: page < result.pages
                            ? () => ref.read(ordersPageProvider.notifier).state = page + 1
                            : null,
                        child: const Text('Next'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              LoadingSkeleton(height: 70),
              SizedBox(height: 10),
              LoadingSkeleton(height: 70),
              SizedBox(height: 10),
              LoadingSkeleton(height: 70),
            ],
          ),
          error: (err, _) => AppErrorState(
            title: 'Orders load failed',
            subtitle: '$err',
            onRetry: () => ref.invalidate(ordersProvider),
          ),
        ),
      ),
    );
  }
}
