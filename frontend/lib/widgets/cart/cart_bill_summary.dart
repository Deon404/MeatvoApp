import 'package:flutter/material.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';

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
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;
    final totalDiscount = couponDiscount;

    return Container(
      padding: EdgeInsets.all(mv.spacing.md),
      decoration: BoxDecoration(
        color: mv.surfaceCard,
        borderRadius: BorderRadius.circular(mv.radii.lg),
        boxShadow: mv.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bill Summary',
            style: textTheme.bodyLarge?.copyWith(
              color: mv.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: mv.spacing.sm),
          _summaryRow(context, 'Item total', '₹${itemTotal.toStringAsFixed(0)}'),
          SizedBox(height: mv.spacing.xs),
          _summaryRow(
            context,
            'Delivery',
            isFreeDelivery ? 'FREE' : '₹${deliveryCharge.toStringAsFixed(0)}',
            valueColor: isFreeDelivery ? mv.freshBadge : null,
          ),
          if (totalDiscount > 0) ...[
            SizedBox(height: mv.spacing.xs),
            _summaryRow(
              context,
              'Discount',
              '-₹${totalDiscount.toStringAsFixed(0)}',
              valueColor: mv.freshBadge,
            ),
          ],
          Padding(
            padding: EdgeInsets.symmetric(vertical: mv.spacing.sm),
            child: Divider(height: 1, color: mv.border),
          ),
          _summaryRow(
            context,
            'Total',
            '₹${grandTotal.toStringAsFixed(0)}',
            bold: true,
            valueColor: mv.brandPrimary,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    BuildContext context,
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
  }) {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: mv.textSecondary,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: textTheme.bodySmall?.copyWith(
            color: valueColor ?? mv.textPrimary,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
