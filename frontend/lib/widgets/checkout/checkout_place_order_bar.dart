import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/tokens/meatvo_colors.dart';
import '../../design_system/theme/meatvo_theme_extensions.dart';
import 'checkout_payment_types.dart';

class CheckoutBillBreakdown {
  const CheckoutBillBreakdown({
    required this.total,
  });

  final double total;
}

class CheckoutPlaceOrderBar extends StatelessWidget {
  const CheckoutPlaceOrderBar({
    super.key,
    required this.bill,
    required this.isEnabled,
    required this.isLoading,
    required this.onPlaceOrder,
    required this.onPayViaTap,
    this.selectedPayment,
  });

  final CheckoutBillBreakdown bill;
  final bool isEnabled;
  final bool isLoading;
  final VoidCallback? onPlaceOrder;
  final VoidCallback? onPayViaTap;
  final CheckoutPaymentOption? selectedPayment;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;
    final canInteract = isEnabled && !isLoading;

    return Container(
      decoration: BoxDecoration(
        color: mv.surfaceCard,
        border: Border(
          top: BorderSide(color: mv.border.withValues(alpha: 0.6)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            mv.spacing.md,
            mv.spacing.sm,
            mv.spacing.md,
            mv.spacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                flex: 32,
                child: _PayViaPill(
                  selectedPayment: selectedPayment,
                  onTap: canInteract ? onPayViaTap : null,
                ),
              ),
              SizedBox(width: mv.spacing.sm),
              Expanded(
                flex: 68,
                child: _PlaceOrderCta(
                  total: bill.total,
                  isEnabled: canInteract,
                  isLoading: isLoading,
                  onTap: onPlaceOrder,
                  textTheme: textTheme,
                  isOnlinePayment:
                      selectedPayment == CheckoutPaymentOption.online,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PayViaPill extends StatelessWidget {
  const _PayViaPill({
    required this.selectedPayment,
    required this.onTap,
  });

  final CheckoutPaymentOption? selectedPayment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;
    final methodLabel = selectedPayment?.footerLabel ?? '—';

    return Material(
      color: MeatvoColors.surfaceMuted,
      borderRadius: BorderRadius.circular(mv.radii.md),
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap!();
              },
        borderRadius: BorderRadius.circular(mv.radii.md),
        child: Container(
          height: 52,
          padding: EdgeInsets.symmetric(horizontal: mv.spacing.sm),
          alignment: Alignment.centerLeft,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PAY VIA',
                style: textTheme.labelSmall?.copyWith(
                  color: mv.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                methodLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: mv.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceOrderCta extends StatelessWidget {
  const _PlaceOrderCta({
    required this.total,
    required this.isEnabled,
    required this.isLoading,
    required this.onTap,
    required this.textTheme,
    required this.isOnlinePayment,
  });

  final double total;
  final bool isEnabled;
  final bool isLoading;
  final VoidCallback? onTap;
  final TextTheme textTheme;
  final bool isOnlinePayment;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final bgColor = isEnabled && !isLoading ? mv.brandPrimary : mv.textMuted;

    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(mv.radii.md),
          color: bgColor,
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
            borderRadius: BorderRadius.circular(mv.radii.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: isLoading
                  ? Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: MeatvoColors.white,
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '₹${total.toStringAsFixed(total.truncateToDouble() == total ? 0 : 1)}',
                                style: textTheme.titleSmall?.copyWith(
                                  color: MeatvoColors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'TOTAL',
                                style: textTheme.labelSmall?.copyWith(
                                  color: MeatvoColors.white.withValues(alpha: 0.85),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isOnlinePayment ? 'Pay' : 'Place Order',
                              style: textTheme.titleSmall?.copyWith(
                                color: MeatvoColors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: MeatvoColors.white,
                              size: 18,
                            ),
                          ],
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
