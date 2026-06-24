import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/tokens/meatvo_colors.dart';
import '../../design_system/theme/meatvo_theme_extensions.dart';

class CheckoutBillBreakdown {
  const CheckoutBillBreakdown({
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
}

class CheckoutPlaceOrderBar extends StatefulWidget {
  const CheckoutPlaceOrderBar({
    super.key,
    required this.bill,
    required this.isEnabled,
    required this.isLoading,
    required this.onPlaceOrder,
    this.label = 'Place Order',
    this.showBreakdownSpinner = false,
  });

  final CheckoutBillBreakdown bill;
  final bool isEnabled;
  final bool isLoading;
  final VoidCallback? onPlaceOrder;
  final String label;
  final bool showBreakdownSpinner;

  @override
  State<CheckoutPlaceOrderBar> createState() => _CheckoutPlaceOrderBarState();
}

class _CheckoutPlaceOrderBarState extends State<CheckoutPlaceOrderBar> {
  bool _expanded = false;

  void _toggleBreakdown() {
    HapticFeedback.lightImpact();
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;
    final bill = widget.bill;
    final isFreeDelivery = bill.deliveryCharge == 0;

    return Container(
      decoration: BoxDecoration(
        color: mv.surfaceCard,
        border: Border(
          top: BorderSide(color: mv.border.withValues(alpha: 0.6)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              crossFadeState: _expanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Padding(
                padding: EdgeInsets.fromLTRB(
                  mv.spacing.md,
                  mv.spacing.sm,
                  mv.spacing.md,
                  0,
                ),
                child: Column(
                  children: [
                    _BillRow(
                      label: 'Item total (${bill.itemCount})',
                      value: '₹${bill.subtotal.toStringAsFixed(0)}',
                    ),
                    if (bill.discount > 0) ...[
                      const SizedBox(height: 4),
                      _BillRow(
                        label: 'Discount',
                        value: '-₹${bill.discount.toStringAsFixed(0)}',
                        valueColor: mv.freshBadge,
                      ),
                    ],
                    const SizedBox(height: 4),
                    _BillRow(
                      label: 'Delivery fee',
                      value: isFreeDelivery
                          ? 'FREE'
                          : '₹${bill.deliveryCharge.toStringAsFixed(0)}',
                      valueColor: isFreeDelivery ? mv.freshBadge : null,
                    ),
                    SizedBox(height: mv.spacing.xs),
                    Divider(height: 1, color: mv.border),
                  ],
                ),
              ),
              secondChild: const SizedBox.shrink(),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                mv.spacing.md,
                mv.spacing.sm,
                mv.spacing.md,
                mv.spacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _toggleBreakdown,
                      borderRadius: BorderRadius.circular(mv.radii.md),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Total',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: mv.textMuted,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  _expanded
                                      ? Icons.keyboard_arrow_down_rounded
                                      : Icons.keyboard_arrow_up_rounded,
                                  size: 16,
                                  color: mv.textMuted,
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹${bill.total.toStringAsFixed(0)}',
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: mv.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: mv.spacing.md),
                  Expanded(
                    flex: 2,
                    child: _PlaceOrderButton(
                      label: widget.label,
                      isEnabled: widget.isEnabled,
                      isLoading:
                          widget.isLoading && widget.showBreakdownSpinner,
                      onTap: widget.onPlaceOrder,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceOrderButton extends StatelessWidget {
  const _PlaceOrderButton({
    required this.label,
    required this.isEnabled,
    required this.isLoading,
    required this.onTap,
  });

  final String label;
  final bool isEnabled;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(mv.radii.pill),
          color: isEnabled && !isLoading ? mv.brandPrimary : mv.textMuted,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isEnabled && !isLoading && onTap != null
                ? () {
                    HapticFeedback.mediumImpact();
                    onTap!();
                  }
                : null,
            borderRadius: BorderRadius.circular(mv.radii.pill),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: MeatvoColors.white,
                      ),
                    )
                  : Text(
                      label,
                      style: textTheme.titleSmall?.copyWith(
                        color: MeatvoColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
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

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(color: mv.textSecondary),
        ),
        Text(
          value,
          style: textTheme.bodySmall?.copyWith(
            color: valueColor ?? mv.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
