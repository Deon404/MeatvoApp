import 'package:flutter/material.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';
import 'checkout_section_header.dart';

class CheckoutOrderSummary extends StatelessWidget {
  const CheckoutOrderSummary({
    super.key,
    required this.subtotal,
    required this.discount,
    required this.deliveryCharge,
    required this.total,
    required this.itemCount,
    this.couponCode,
  });

  final double subtotal;
  final double discount;
  final double deliveryCharge;
  final double total;
  final int itemCount;
  final String? couponCode;

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
          decoration: BoxDecoration(
            color: mv.surfaceCard,
            borderRadius: BorderRadius.circular(mv.radii.md),
            border: Border.all(color: mv.border),
          ),
          padding: EdgeInsets.all(mv.spacing.md),
          child: Column(
            children: [
              _BillRow(
                label:
                    'Item total ($itemCount ${itemCount == 1 ? 'item' : 'items'})',
                value: '₹${subtotal.toStringAsFixed(0)}',
              ),
              if (discount > 0) ...[
                SizedBox(height: mv.spacing.xxs),
                _BillRow(
                  label:
                      couponCode != null ? 'Coupon ($couponCode)' : 'Discount',
                  value: '-₹${discount.toStringAsFixed(0)}',
                  valueColor: mv.freshBadge,
                ),
              ],
              SizedBox(height: mv.spacing.xxs),
              _BillRow(
                label: 'Delivery fee',
                value: isFreeDelivery
                    ? 'FREE'
                    : '₹${deliveryCharge.toStringAsFixed(0)}',
                valueColor: isFreeDelivery ? mv.freshBadge : null,
                emphasizeValue: isFreeDelivery,
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: mv.spacing.sm),
                child: Divider(height: 1, color: mv.border),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'To pay',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '₹${total.toStringAsFixed(0)}',
                    style: textTheme.titleLarge?.copyWith(
                      color: mv.brandPrimary,
                      fontWeight: FontWeight.w800,
                    ),
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

class _BillRow extends StatelessWidget {
  const _BillRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasizeValue = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasizeValue;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: textTheme.bodyMedium?.copyWith(color: mv.textSecondary),
        ),
        Text(
          value,
          style: (emphasizeValue ? textTheme.labelLarge : textTheme.bodyMedium)
              ?.copyWith(
            color: valueColor ?? mv.textPrimary,
            fontWeight: emphasizeValue ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
