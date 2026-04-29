import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/cart_provider.dart';
import '../../providers/checkout_provider.dart';
import '../../services/checkout_service.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  bool _placing = false;

  Future<void> _placeOrder() async {
    final selectedAddress = ref.read(selectedAddressProvider);
    final method = ref.read(paymentMethodProvider);
    final couponCode = ref.read(couponCodeProvider);

    if (selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select address first')),
      );
      context.go('/checkout/address');
      return;
    }

    setState(() => _placing = true);
    try {
      final order = await ref.read(checkoutServiceProvider).placeOrder(
            addressId: selectedAddress.id,
            paymentMethod: method,
            couponCode: couponCode,
          );

      if (method == 'UPI') {
        final url = await ref.read(checkoutServiceProvider).initiatePayment(order.orderId);
        if (url != null && url.isNotEmpty) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        }
      }

      ref.read(cartProvider.notifier).clear();
      ref.read(couponDiscountProvider.notifier).state = 0;
      ref.read(couponCodeProvider.notifier).state = '';
      if (mounted) context.go('/checkout/success', extra: order.orderId);
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order placement failed: $err')),
        );
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final method = ref.watch(paymentMethodProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Choose payment method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: method,
            onChanged: (v) => ref.read(paymentMethodProvider.notifier).state = v ?? 'COD',
            child: const Column(
              children: [
                RadioListTile<String>(
                  value: 'UPI',
                  title: Text('PhonePe UPI'),
                ),
                RadioListTile<String>(
                  value: 'COD',
                  title: Text('Cash on Delivery'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'UPI select karoge to payment app open hogi. COD pe order direct place hoga.',
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _placing ? null : _placeOrder,
            child: Text(_placing ? 'Placing order...' : 'Place Order'),
          ),
        ),
      ),
    );
  }
}
