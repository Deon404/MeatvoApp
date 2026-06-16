import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../cart/premium_cart_card.dart';
import 'checkout_section_header.dart';

class CheckoutOrderSummary extends StatelessWidget {
  const CheckoutOrderSummary({
    super.key,
    required this.subtotal,
    required this.discount,
    required this.deliveryCharge,
    required this.total,
    required this.itemCount,
  });

  final double subtotal;
  final double discount;
  final double deliveryCharge;
  final double total;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isFreeDelivery = deliveryCharge == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckoutSectionHeader(
          step: 4,
          title: 'Order summary',
          subtitle:
              '$itemCount ${itemCount == 1 ? 'item' : 'items'} in your cart',
        ),
        PremiumCartCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BillRow(
                label: 'Item total',
                value: '₹${subtotal.toStringAsFixed(0)}',
              ),
              if (discount > 0) ...[
                const SizedBox(height: AppSpacing.xs),
                _BillRow(
                  label: 'Discount',
                  value: '-₹${discount.toStringAsFixed(0)}',
                  valueColor: AppThemeColors.success,
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              _BillRow(
                label: 'Delivery fee',
                value: isFreeDelivery ? 'FREE' : '₹${deliveryCharge.toStringAsFixed(0)}',
                valueColor: isFreeDelivery ? AppThemeColors.success : null,
                emphasizeValue: isFreeDelivery,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Divider(height: 1, color: AppThemeColors.divider),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppThemeColors.surface2,
                  borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                ),
                // Grand-total row: Expanded label + min-width trailing
                // AnimatedSwitcher. Spacer + variable-width Switcher used
                // to trigger relayout loops on the cart→checkout flow.
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Grand total',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(
                          color: AppThemeColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 112),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 240),
                          switchInCurve: Curves.easeOutCubic,
                          layoutBuilder: (currentChild, previousChildren) {
                            return Stack(
                              alignment: Alignment.centerRight,
                              children: [
                                ...previousChildren,
                                if (currentChild != null) currentChild,
                              ],
                            );
                          },
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.08, 0),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: Text(
                            '₹${total.toStringAsFixed(0)}',
                            key: ValueKey<double>(total),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            textAlign: TextAlign.right,
                            style: textTheme.headlineSmall?.copyWith(
                              color: AppThemeColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: textTheme.bodyMedium?.copyWith(
            color: AppThemeColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: (emphasizeValue ? textTheme.labelLarge : textTheme.bodyMedium)
              ?.copyWith(
            color: valueColor ?? AppThemeColors.textPrimary,
            fontWeight: emphasizeValue ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
