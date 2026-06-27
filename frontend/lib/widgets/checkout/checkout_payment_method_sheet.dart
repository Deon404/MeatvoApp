import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/tokens/meatvo_colors.dart';
import '../../design_system/theme/meatvo_theme_extensions.dart';
import 'checkout_payment_types.dart';

/// Bottom sheet — choose Online (UPI/cards) or Cash on Delivery.
class CheckoutPaymentMethodSheet extends StatelessWidget {
  const CheckoutPaymentMethodSheet({super.key});

  static Future<CheckoutPaymentOption?> show(BuildContext context) {
    return showModalBottomSheet<CheckoutPaymentOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CheckoutPaymentMethodSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 28),
          child: Container(
            decoration: BoxDecoration(
              color: mv.surfaceCard,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.fromLTRB(
              mv.spacing.lg,
              mv.spacing.lg,
              mv.spacing.lg,
              mv.spacing.lg + bottomPad,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SectionLabel(label: 'PAY USING UPI APPS'),
                SizedBox(height: mv.spacing.md),
                _PaymentCard(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Pay online via UPI, Cards or Netbanking',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context, CheckoutPaymentOption.online);
                  },
                ),
                SizedBox(height: mv.spacing.lg),
                _SectionLabel(label: 'PAY ON DELIVERY'),
                SizedBox(height: mv.spacing.md),
                _PaymentCard(
                  icon: Icons.currency_rupee_rounded,
                  title: 'Cash on Delivery',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context, CheckoutPaymentOption.cod);
                  },
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 0,
          child: _FloatingCloseButton(
            onTap: () => Navigator.pop(context),
          ),
        ),
      ],
    );
  }
}

class _FloatingCloseButton extends StatelessWidget {
  const _FloatingCloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 36,
          height: 36,
          child: Icon(Icons.close_rounded, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(child: Divider(color: mv.border, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: mv.textMuted,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              fontSize: 11,
            ),
          ),
        ),
        Expanded(child: Divider(color: mv.border, height: 1)),
      ],
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: MeatvoColors.surfaceMuted,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: mv.textPrimary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: mv.textPrimary,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: mv.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
