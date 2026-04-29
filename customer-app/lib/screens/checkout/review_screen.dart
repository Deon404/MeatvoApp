import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/cart_provider.dart';
import '../../providers/checkout_provider.dart';
import '../../services/checkout_service.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  final _couponController = TextEditingController();
  bool _couponLoading = false;

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _applyCoupon(double subtotal) async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;
    setState(() => _couponLoading = true);
    try {
      final result = await ref.read(checkoutServiceProvider).applyCoupon(
            code: code,
            orderTotal: subtotal,
          );
      ref.read(couponCodeProvider.notifier).state = code;
      ref.read(couponDiscountProvider.notifier).state = result.discount;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Coupon failed: $err')));
      }
    } finally {
      if (mounted) setState(() => _couponLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartProvider);
    final subtotal = cartItems.fold<double>(0, (sum, item) => sum + item.total);
    const deliveryCharge = 30.0;
    final discount = ref.watch(couponDiscountProvider);
    final total = (subtotal + deliveryCharge - discount).clamp(0, double.infinity).toDouble();

    return Scaffold(
      appBar: AppBar(title: const Text('Order Review')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ...cartItems.map(
            (item) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(item.product.name),
              subtitle: Text('${item.weight}g x ${item.quantity}'),
              trailing: Text('₹${item.total.toStringAsFixed(0)}'),
            ),
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _couponController,
                  decoration: const InputDecoration(hintText: 'Coupon code'),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _couponLoading ? null : () => _applyCoupon(subtotal),
                child: Text(_couponLoading ? 'Applying' : 'Apply'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _line('Subtotal', subtotal),
          _line('Delivery', deliveryCharge),
          _line('Discount', -discount),
          const Divider(height: 20),
          _line('Total', total, bold: true),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: cartItems.isEmpty ? null : () => context.go('/checkout/payment'),
            child: const Text('Continue to Payment'),
          ),
        ),
      ),
    );
  }

  Widget _line(String label, double value, {bool bold = false}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontSize: bold ? 18 : 15,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text('₹${value.toStringAsFixed(0)}', style: style),
        ],
      ),
    );
  }
}
