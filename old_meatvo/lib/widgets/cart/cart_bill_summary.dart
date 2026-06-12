import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'premium_cart_card.dart';

class CartBillSummary extends StatelessWidget {
  const CartBillSummary({
    super.key,
    required this.itemTotal,
    required this.productDiscount,
    required this.couponDiscount,
    required this.deliveryCharge,
    required this.grandTotal,
    required this.itemCount,
    this.isFreeDelivery = false,
  });

  final double itemTotal;
  final double productDiscount;
  final double couponDiscount;
  final double deliveryCharge;
  final double grandTotal;
  final int itemCount;
  final bool isFreeDelivery;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final totalDiscount = couponDiscount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bill Summary',
            style: textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF1A1A1A),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _summaryRow('Item total', '₹${itemTotal.toStringAsFixed(0)}'),
          const SizedBox(height: 8),
          _summaryRow(
            'Delivery',
            isFreeDelivery ? 'FREE' : '₹${deliveryCharge.toStringAsFixed(0)}',
            valueColor: isFreeDelivery ? const Color(0xFF22C55E) : null,
          ),
          if (totalDiscount > 0) ...[
            const SizedBox(height: 8),
            _summaryRow(
              'Discount',
              '-₹${totalDiscount.toStringAsFixed(0)}',
              valueColor: const Color(0xFF22C55E),
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFEEEEEE)),
          ),
          _summaryRow(
            'Total',
            '₹${grandTotal.toStringAsFixed(0)}',
            bold: true,
            valueColor: const Color(0xFFC8102E),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF6B6B6B),
            fontSize: 13,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? const Color(0xFF1A1A1A),
            fontSize: 13,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
