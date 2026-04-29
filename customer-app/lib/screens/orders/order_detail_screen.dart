import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/orders_provider.dart';
import '../../widgets/app_error_state.dart';
import '../../widgets/loading_skeleton.dart';

class OrderDetailScreen extends ConsumerWidget {
  final int orderId;

  const OrderDetailScreen({
    super.key,
    required this.orderId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));
    return Scaffold(
      appBar: AppBar(title: Text('Order #$orderId')),
      body: orderAsync.when(
        data: (order) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatusStepper(status: order.status),
            const SizedBox(height: 14),
            Text('Total: ₹${order.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Payment: ${order.paymentMode}'),
            Text('Address: ${order.address}'),
            const Divider(height: 24),
            const Text('Items', style: TextStyle(fontWeight: FontWeight.bold)),
            ...order.items.map(
              (item) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(item.name),
                subtitle: Text('${item.quantity} x ${item.unit}'),
                trailing: Text('₹${(item.price * item.quantity).toStringAsFixed(0)}'),
              ),
            ),
            const Divider(height: 24),
            if (order.assignment != null) ...[
              const Text('Delivery Partner', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(order.assignment!.partnerName),
              Text(order.assignment!.partnerPhone),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _callPartner(order.assignment!.partnerPhone),
                    icon: const Icon(Icons.call),
                    label: const Text('Call'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => context.go('/orders/$orderId/tracking'),
                    child: const Text('Track Live'),
                  ),
                ],
              ),
            ] else
              const Text('Partner not assigned yet.'),
          ],
        ),
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            LoadingSkeleton(height: 18),
            SizedBox(height: 8),
            LoadingSkeleton(height: 18),
            SizedBox(height: 8),
            LoadingSkeleton(height: 120),
          ],
        ),
        error: (err, _) => AppErrorState(
          title: 'Order detail unavailable',
          subtitle: '$err',
          onRetry: () => ref.invalidate(orderDetailProvider(orderId)),
        ),
      ),
    );
  }

  Future<void> _callPartner(String phone) async {
    if (phone.isEmpty) return;
    await launchUrl(Uri.parse('tel:$phone'));
  }
}

class _StatusStepper extends StatelessWidget {
  final String status;
  const _StatusStepper({required this.status});

  @override
  Widget build(BuildContext context) {
    const steps = ['PLACED', 'CONFIRMED', 'PACKED', 'OUT_FOR_DELIVERY', 'DELIVERED'];
    final index = steps.indexOf(status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: steps.map((s) {
        final active = index >= steps.indexOf(s);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Icon(active ? Icons.check_circle : Icons.radio_button_unchecked, size: 18),
              const SizedBox(width: 8),
              Text(s.replaceAll('_', ' ')),
            ],
          ),
        );
      }).toList(),
    );
  }
}
