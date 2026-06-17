import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/address_model.dart';
import '../../design_system/tokens/meatvo_colors.dart';
import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../services/store_status_service.dart';
import '../../theme/app_theme.dart';
import '../cart/premium_cart_card.dart';
import '../store/store_closed_banner.dart';

class CheckoutDeliverySection extends StatelessWidget {
  const CheckoutDeliverySection({
    super.key,
    required this.selectedAddress,
    required this.onChangeAddress,
    required this.onAddAddress,
    this.isEmptyAddress = false,
    this.isStoreOpen = true,
    this.storeClosedMessage,
  });

  final AddressModel? selectedAddress;
  final VoidCallback onChangeAddress;
  final VoidCallback onAddAddress;
  final bool isEmptyAddress;
  final bool isStoreOpen;
  final String? storeClosedMessage;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isStoreOpen && storeClosedMessage != null) ...[
          StoreClosedBanner(
            status: StoreStatus(
              isOpen: false,
              closedMessage: storeClosedMessage,
            ),
            padding: EdgeInsets.zero,
          ),
          SizedBox(height: mv.spacing.sm),
        ],
        const PremiumCartSectionTitle(title: 'Deliver to'),
        PremiumCartCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isEmptyAddress)
                _EmptyAddressPrompt(onAddTap: onAddAddress)
              else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: MeatvoColors.primaryLight,
                        borderRadius:
                            BorderRadius.circular(AppRadius.radiusMd),
                      ),
                      child: Icon(
                        _iconForLabel(selectedAddress!.label),
                        color: mv.brandPrimary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedAddress!.label.displayName,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            selectedAddress!.displayAddress,
                            style: textTheme.bodyMedium?.copyWith(
                              color: mv.textSecondary,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        onChangeAddress();
                      },
                      child: const Text('Change'),
                    ),
                  ],
                ),
                if (isStoreOpen) ...[
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: mv.spacing.sm),
                    child: Divider(height: 1, color: mv.border),
                  ),
                  const _ExpressDeliveryEtaCard(),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  IconData _iconForLabel(AddressLabel label) {
    return switch (label) {
      AddressLabel.home => Icons.home_rounded,
      AddressLabel.work => Icons.work_rounded,
      AddressLabel.other => Icons.location_on_rounded,
    };
  }
}

class _ExpressDeliveryEtaCard extends StatelessWidget {
  const _ExpressDeliveryEtaCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.access_time, color: Color(0xFF2E7D32), size: 20),
          SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Express Delivery',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              Text(
                'Delivered in ~45-60 minutes',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyAddressPrompt extends StatelessWidget {
  const _EmptyAddressPrompt({required this.onAddTap});

  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onAddTap,
      borderRadius: BorderRadius.circular(mv.radii.md),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: MeatvoColors.surfaceMuted,
              borderRadius: BorderRadius.circular(mv.radii.md),
            ),
            child: Icon(
              Icons.add_location_alt_rounded,
              color: mv.brandPrimary,
            ),
          ),
          SizedBox(width: mv.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add delivery address',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Pin your location for fresh delivery',
                  style: textTheme.bodySmall?.copyWith(
                    color: mv.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: mv.textMuted,
          ),
        ],
      ),
    );
  }
}
