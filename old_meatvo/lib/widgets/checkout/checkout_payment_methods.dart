import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
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
        CheckoutPaymentOption.online => 'UPI, cards via PhonePe',
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
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PremiumCartSectionTitle(title: 'Pay with'),
        PremiumCartCard(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            children: CheckoutPaymentOption.values.map((option) {
              final isSelected = selected == option;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: CheckoutSelectionCard(
                  isSelected: isSelected,
                  onTap: () => onSelected(option),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm + 2,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppThemeColors.surface2,
                          borderRadius:
                              BorderRadius.circular(AppRadius.radiusMd),
                        ),
                        child: Icon(
                          option.icon,
                          color: AppThemeColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
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
                                color: AppThemeColors.textMuted,
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
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Icon(
              Icons.verified_user_outlined,
              size: 14,
              color: AppThemeColors.success.withValues(alpha: 0.9),
            ),
            const SizedBox(width: 4),
            Text(
              'Secured payments via PhonePe',
              style: textTheme.bodySmall?.copyWith(
                color: AppThemeColors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
