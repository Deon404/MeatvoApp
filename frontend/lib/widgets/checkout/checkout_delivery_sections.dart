import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/address_model.dart';
import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../services/store_status_service.dart';
import '../store/store_closed_banner.dart';
import 'checkout_section_header.dart';

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
        CheckoutSectionHeader(
          title: 'Deliver to',
          trailing: !isEmptyAddress
              ? TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onChangeAddress();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: mv.brandPrimary,
                    padding: EdgeInsets.symmetric(horizontal: mv.spacing.sm),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Change'),
                )
              : null,
        ),
        if (isEmptyAddress)
          _EmptyAddressPrompt(onAddTap: onAddAddress)
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _iconForLabel(selectedAddress!.label),
                    color: mv.brandPrimary,
                    size: 18,
                  ),
                  SizedBox(width: mv.spacing.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              selectedAddress!.label.displayName,
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (selectedAddress!.isDefault) ...[
                              SizedBox(width: mv.spacing.xs),
                              Text(
                                '· Default',
                                style: textTheme.bodySmall?.copyWith(
                                  color: mv.freshBadge,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selectedAddress!.displayAddress,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: mv.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isStoreOpen) ...[
                    SizedBox(width: mv.spacing.xs),
                    _ExpressDeliveryChip(),
                  ],
                ],
              ),
            ],
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

class _ExpressDeliveryChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: mv.spacing.xs,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: mv.freshBadge.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(mv.radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, color: mv.freshBadge, size: 12),
          const SizedBox(width: 3),
          Text(
            '~45–60 min',
            style: textTheme.labelSmall?.copyWith(
              color: mv.freshBadge,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
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
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: mv.spacing.xs),
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
