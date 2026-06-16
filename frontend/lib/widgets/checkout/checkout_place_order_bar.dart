import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';

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
  });

  final CheckoutBillBreakdown bill;
  final bool isEnabled;
  final bool isLoading;
  final VoidCallback? onPlaceOrder;
  final String label;

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
    final textTheme = Theme.of(context).textTheme;
    final bill = widget.bill;
    final isFreeDelivery = bill.deliveryCharge == 0;

    return Container(
      decoration: BoxDecoration(
        color: AppThemeColors.surface,
        border: Border(
          top: BorderSide(
            color: AppThemeColors.border.withValues(alpha: 0.6),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: AppThemeColors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
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
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
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
                        valueColor: AppThemeColors.success,
                      ),
                    ],
                    const SizedBox(height: 4),
                    _BillRow(
                      label: 'Delivery fee',
                      value: isFreeDelivery
                          ? 'FREE'
                          : '₹${bill.deliveryCharge.toStringAsFixed(0)}',
                      valueColor:
                          isFreeDelivery ? AppThemeColors.success : null,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Divider(height: 1, color: AppThemeColors.divider),
                  ],
                ),
              ),
              secondChild: const SizedBox.shrink(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _toggleBreakdown,
                      borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Total payable',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: AppThemeColors.textMuted,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  _expanded
                                      ? Icons.keyboard_arrow_down_rounded
                                      : Icons.keyboard_arrow_up_rounded,
                                  size: 16,
                                  color: AppThemeColors.textMuted,
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹${bill.total.toStringAsFixed(0)}',
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 2,
                    child: _PlaceOrderButton(
                      label: widget.label,
                      isEnabled: widget.isEnabled,
                      isLoading: widget.isLoading,
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
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.radiusPill),
          gradient: LinearGradient(
            colors: isEnabled && !isLoading
                ? const [Color(0xFFD4181C), AppThemeColors.primary]
                : [
                    AppThemeColors.textMuted,
                    AppThemeColors.textMuted,
                  ],
          ),
          boxShadow: isEnabled && !isLoading
              ? [
                  BoxShadow(
                    color: AppThemeColors.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
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
            borderRadius: BorderRadius.circular(AppRadius.radiusPill),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppThemeColors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.shopping_bag_outlined,
                          color: AppThemeColors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: textTheme.titleSmall?.copyWith(
                            color: AppThemeColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: AppThemeColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: textTheme.bodySmall?.copyWith(
            color: valueColor ?? AppThemeColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
