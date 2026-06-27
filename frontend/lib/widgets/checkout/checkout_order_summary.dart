import 'package:flutter/material.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';
import 'checkout_section_header.dart';

class CheckoutOrderSummary extends StatelessWidget {
  const CheckoutOrderSummary({
    super.key,
    required this.subtotal,
    required this.productDiscount,
    required this.couponDiscount,
    required this.deliveryCharge,
    required this.total,
  });

  final double subtotal;
  final double productDiscount;
  final double couponDiscount;
  final double deliveryCharge;
  final double total;

  static const _discountGreen = Color(0xFF2D6A4F);
  static const _dividerColor = Color(0xFFE5E7EB);

  double get _discountedSubtotal =>
      (subtotal - productDiscount).clamp(0, double.infinity);

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;
    final isFreeDelivery = deliveryCharge == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CheckoutSectionHeader(title: 'Bill details'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _SubtotalRow(
                originalSubtotal: subtotal,
                discountedSubtotal: _discountedSubtotal,
                hasProductDiscount: productDiscount > 0,
              ),
              _BillRow(
                label: 'Delivery charge',
                value: isFreeDelivery
                    ? 'FREE'
                    : '₹${deliveryCharge.toStringAsFixed(0)}',
                valueColor: isFreeDelivery ? _discountGreen : null,
              ),
              _BillRow(
                label: 'Handling charge',
                value: '₹0',
              ),
              _BillRow(
                label: 'Convenience charge',
                value: '₹0',
              ),
              if (couponDiscount > 0)
                _BillRow(
                  label: 'Coupon discount',
                  value: '- ₹${couponDiscount.toStringAsFixed(0)}',
                  valueColor: _discountGreen,
                ),
              const Divider(height: 24, color: _dividerColor),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total amount',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: mv.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${total.toStringAsFixed(total.truncateToDouble() == total ? 0 : 1)}',
                        style: textTheme.titleMedium?.copyWith(
                          color: mv.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '(incl. of taxes)',
                        style: textTheme.labelSmall?.copyWith(
                          color: mv.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubtotalRow extends StatelessWidget {
  const _SubtotalRow({
    required this.originalSubtotal,
    required this.discountedSubtotal,
    required this.hasProductDiscount,
  });

  final double originalSubtotal;
  final double discountedSubtotal;
  final bool hasProductDiscount;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Subtotal',
            style: textTheme.bodyMedium?.copyWith(color: mv.textSecondary),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasProductDiscount) ...[
                Text(
                  '₹${originalSubtotal.toStringAsFixed(0)}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: mv.textMuted,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: mv.textMuted,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                '₹${(hasProductDiscount ? discountedSubtotal : originalSubtotal).toStringAsFixed(0)}',
                style: textTheme.bodyMedium?.copyWith(
                  color: mv.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(color: mv.textSecondary),
          ),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              color: valueColor ?? mv.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
