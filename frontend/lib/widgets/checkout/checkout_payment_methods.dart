import 'package:flutter/material.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../design_system/tokens/meatvo_colors.dart';
import '../cart/premium_cart_card.dart';
import 'checkout_selection_card.dart';

enum CheckoutPaymentOption { online, cod }

extension CheckoutPaymentOptionX on CheckoutPaymentOption {
  String get backendValue =>
      this == CheckoutPaymentOption.cod ? 'COD' : 'ONLINE';

  String get label => switch (this) {
        CheckoutPaymentOption.online => 'Pay Online',
        CheckoutPaymentOption.cod => 'Cash on Delivery',
      };

  String get subtitle => switch (this) {
        CheckoutPaymentOption.online => 'UPI, cards & wallets via Cashfree',
        CheckoutPaymentOption.cod => 'Pay when your order arrives',
      };

  IconData get icon => switch (this) {
        CheckoutPaymentOption.online => Icons.account_balance_wallet_outlined,
        CheckoutPaymentOption.cod => Icons.payments_outlined,
      };
}

class CheckoutPaymentMethods extends StatelessWidget {
  const CheckoutPaymentMethods({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final CheckoutPaymentOption selected;
  final ValueChanged<CheckoutPaymentOption> onSelected;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PremiumCartSectionTitle(title: 'Pay with'),
        PremiumCartCard(
          padding: EdgeInsets.all(mv.spacing.sm),
          child: Column(
            children: CheckoutPaymentOption.values.map((option) {
              final isSelected = selected == option;
              return Padding(
                padding: EdgeInsets.only(bottom: mv.spacing.xs),
                child: CheckoutSelectionCard(
                  isSelected: isSelected,
                  onTap: () => onSelected(option),
                  padding: EdgeInsets.symmetric(
                    horizontal: mv.spacing.md,
                    vertical: mv.spacing.sm + 2,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: MeatvoColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(mv.radii.md),
                        ),
                        child: Icon(
                          option.icon,
                          color: mv.brandPrimary,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: mv.spacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              option.label,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              option.subtitle,
                              style: textTheme.bodySmall?.copyWith(
                                color: mv.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      CheckoutSelectionIndicator(isSelected: isSelected),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        if (selected == CheckoutPaymentOption.online) ...[
          SizedBox(height: mv.spacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _UpiChip(label: 'GPay'),
              SizedBox(width: mv.spacing.xs),
              _UpiChip(label: 'PhonePe'),
              SizedBox(width: mv.spacing.xs),
              _UpiChip(label: 'Paytm'),
              SizedBox(width: mv.spacing.xs),
              _UpiChip(label: 'UPI'),
            ],
          ),
        ],
        SizedBox(height: mv.spacing.xs),
        Row(
          children: [
            Icon(
              Icons.verified_user_outlined,
              size: 14,
              color: mv.freshBadge.withValues(alpha: 0.9),
            ),
            const SizedBox(width: 4),
            Text(
              'Secured payments',
              style: textTheme.bodySmall?.copyWith(
                color: mv.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _UpiChip extends StatelessWidget {
  const _UpiChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: mv.spacing.sm,
        vertical: mv.spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: mv.surfaceCard,
        borderRadius: BorderRadius.circular(mv.radii.pill),
        border: Border.all(color: mv.border),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          color: mv.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
