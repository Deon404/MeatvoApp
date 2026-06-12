import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/address_model.dart';
import '../../theme/app_theme.dart';
import 'premium_cart_card.dart';

class CartDeliveryAddressCard extends StatelessWidget {
  const CartDeliveryAddressCard({
    super.key,
    required this.selectedAddress,
    required this.onChangeTap,
    this.deliveryEstimateText,
  });

  final AddressModel? selectedAddress;
  final VoidCallback onChangeTap;
  final String? deliveryEstimateText;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Capture once to a local — enables Dart smart-cast so the rest of the
    // method can use `address.label.displayName` without the `!` operator.
    // That removes a class of crashes when `selectedAddress` flips to null
    // between the initial build and a downstream rebuild (e.g. address
    // deleted from another tab).
    final address = selectedAddress;
    final hasAddress = address != null;
    final estimate = deliveryEstimateText;
    final hasEstimate = estimate != null && estimate.isNotEmpty;

    return PremiumCartCard(
      onTap: onChangeTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppThemeColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: AppThemeColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivery address',
                      style: textTheme.labelLarge?.copyWith(
                        color: AppThemeColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasAddress
                          ? address.label.displayName
                          : 'Add where we should deliver',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppThemeColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onChangeTap();
                },
                child: Text(hasAddress ? 'Change' : 'Add'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            hasAddress
                ? address.displayAddress
                : 'Tap to add your home or office address for fresh delivery.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(
              color: AppThemeColors.textSecondary,
              height: 1.45,
            ),
          ),
          if (hasEstimate) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 18,
                  color: AppThemeColors.primary.withValues(alpha: 0.9),
                ),
                const SizedBox(width: AppSpacing.xs),
                // Expanded keeps the long delivery estimate text bounded
                // inside the Row — without it, the Text would request
                // intrinsic width and overflow on narrow phones.
                Expanded(
                  child: Text(
                    estimate,
                    style: textTheme.labelLarge?.copyWith(
                      color: AppThemeColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
