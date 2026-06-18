import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../design_system/tokens/meatvo_colors.dart';

/// Inline checkout section with brand CTA, placed below bill summary in cart scroll.
class CartFloatingCheckout extends StatelessWidget {
  const CartFloatingCheckout({
    super.key,
    required this.total,
    required this.onCheckout,
    this.isLoading = false,
  });

  final double total;
  final VoidCallback? onCheckout;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;
    final buttonEnabled = !isLoading && onCheckout != null;

    return Container(
      padding: EdgeInsets.all(mv.spacing.md),
      decoration: BoxDecoration(
        color: mv.surfaceCard,
        borderRadius: BorderRadius.circular(mv.radii.lg),
        boxShadow: mv.shadowMd,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'To pay',
                style: textTheme.bodySmall?.copyWith(color: mv.textSecondary),
              ),
              Text(
                '₹${total.toStringAsFixed(0)}',
                style: textTheme.titleMedium?.copyWith(
                  color: mv.brandPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: mv.spacing.xs),
          SizedBox(
            height: 54,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: buttonEnabled
                  ? () {
                      HapticFeedback.mediumImpact();
                      onCheckout?.call();
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: mv.brandPrimary,
                foregroundColor: MeatvoColors.white,
                disabledBackgroundColor: MeatvoColors.surfaceMuted,
                disabledForegroundColor: mv.textMuted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(mv.radii.md),
                ),
                elevation: 0,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: MeatvoColors.white,
                      ),
                    )
                  : Text(
                      'Proceed to Checkout',
                      style: textTheme.titleSmall?.copyWith(
                        color: MeatvoColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
