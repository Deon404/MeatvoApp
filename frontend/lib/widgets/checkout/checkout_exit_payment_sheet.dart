import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/tokens/meatvo_colors.dart';
import '../../design_system/theme/meatvo_theme_extensions.dart';

/// Exit confirmation when user tries to leave during payment.
class CheckoutExitPaymentSheet extends StatelessWidget {
  const CheckoutExitPaymentSheet({
    super.key,
    this.title = 'Are you sure you want to exit?',
    this.subtitle =
        'Your order is saved. You can complete payment from My Orders.',
    this.continueLabel = 'Continue to payment',
    this.exitLabel = 'Yes, exit',
  });

  final String title;
  final String subtitle;
  final String continueLabel;
  final String exitLabel;

  /// Returns `true` if user chose to exit.
  static Future<bool?> show(
    BuildContext context, {
    String? title,
    String? subtitle,
    String? continueLabel,
    String? exitLabel,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CheckoutExitPaymentSheet(
        title: title ?? 'Are you sure you want to exit?',
        subtitle: subtitle ??
            'Your order is saved. You can complete payment from My Orders.',
        continueLabel: continueLabel ?? 'Continue to payment',
        exitLabel: exitLabel ?? 'Yes, exit',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: mv.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        mv.spacing.lg,
        mv.spacing.xl,
        mv.spacing.lg,
        mv.spacing.lg + bottomPad,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.logout_rounded, size: 48, color: mv.textMuted),
          SizedBox(height: mv.spacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: mv.textPrimary,
            ),
          ),
          SizedBox(height: mv.spacing.sm),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: mv.textSecondary,
              height: 1.45,
            ),
          ),
          SizedBox(height: mv.spacing.lg),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context, false);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: mv.textPrimary,
                side: BorderSide(color: mv.textPrimary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(mv.radii.md),
                ),
              ),
              child: Text(
                continueLabel,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(height: mv.spacing.sm),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: MeatvoColors.brandPrimaryDark,
                foregroundColor: MeatvoColors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(mv.radii.md),
                ),
              ),
              child: Text(
                exitLabel,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: MeatvoColors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
