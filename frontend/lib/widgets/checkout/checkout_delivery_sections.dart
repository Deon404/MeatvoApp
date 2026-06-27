import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/address_model.dart';
import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../services/store_status_service.dart';
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

  static const _addressHighlight = Color(0xFFFFF4E6);
  static const _addressBorder = Color(0xFFFFE8B3);

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
        if (isEmptyAddress)
          _EmptyAddressPrompt(onAddTap: onAddAddress)
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _addressHighlight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _addressBorder, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Delivering to ${selectedAddress!.label.displayName}',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: mv.textPrimary,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onChangeAddress();
                      },
                      child: Text(
                        'Change',
                        style: textTheme.labelLarge?.copyWith(
                          color: mv.brandPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  selectedAddress!.displayAddress,
                  style: textTheme.bodySmall?.copyWith(
                    color: mv.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
      ],
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
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CheckoutDeliverySection._addressHighlight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CheckoutDeliverySection._addressBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.add_location_alt_rounded, color: mv.brandPrimary, size: 20),
            SizedBox(width: mv.spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add delivery address',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: mv.brandPrimary,
                    ),
                  ),
                  Text(
                    'Pin your location on the map',
                    style: textTheme.bodySmall?.copyWith(color: mv.textMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: mv.brandPrimary, size: 20),
          ],
        ),
      ),
    );
  }
}
