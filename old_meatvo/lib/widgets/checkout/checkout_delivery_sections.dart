import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/address_model.dart';
import '../../models/delivery_slot_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/eta_display_util.dart';
import '../cart/premium_cart_card.dart';

class CheckoutDeliverySection extends StatelessWidget {
  const CheckoutDeliverySection({
    super.key,
    required this.selectedAddress,
    required this.onChangeAddress,
    required this.onAddAddress,
    required this.deliverySlots,
    required this.selectedSlot,
    required this.onSlotSelected,
    this.isEmptyAddress = false,
    this.isLoadingSlots = false,
  });

  final AddressModel? selectedAddress;
  final VoidCallback onChangeAddress;
  final VoidCallback onAddAddress;
  final List<DeliverySlotModel> deliverySlots;
  final DeliverySlotModel? selectedSlot;
  final ValueChanged<DeliverySlotModel> onSlotSelected;
  final bool isEmptyAddress;
  final bool isLoadingSlots;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                        color: AppThemeColors.primaryLight,
                        borderRadius:
                            BorderRadius.circular(AppRadius.radiusMd),
                      ),
                      child: Icon(
                        _iconForLabel(selectedAddress!.label),
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
                            selectedAddress!.label.displayName,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            selectedAddress!.displayAddress,
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppThemeColors.textSecondary,
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
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Divider(height: 1, color: AppThemeColors.divider),
                ),
                Text(
                  'Delivery time',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _CheckoutSlotSelector(
                  slots: deliverySlots,
                  selectedSlot: selectedSlot,
                  onSlotSelected: onSlotSelected,
                  isLoading: isLoadingSlots,
                ),
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

class _CheckoutSlotSelector extends StatelessWidget {
  const _CheckoutSlotSelector({
    required this.slots,
    required this.selectedSlot,
    required this.onSlotSelected,
    required this.isLoading,
  });

  final List<DeliverySlotModel> slots;
  final DeliverySlotModel? selectedSlot;
  final ValueChanged<DeliverySlotModel> onSlotSelected;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 40,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (slots.isEmpty) {
      return Text(
        'No delivery slots available right now.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppThemeColors.textMuted,
            ),
      );
    }

    final grouped = <String, List<DeliverySlotModel>>{};
    for (final slot in slots) {
      grouped.putIfAbsent(slot.dateKey, () => []).add(slot);
    }

    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < sortedKeys.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          _SlotDaySection(
            dateLabel: grouped[sortedKeys[i]]!.first.dateLabel,
            slots: grouped[sortedKeys[i]]!,
            selectedSlot: selectedSlot,
            onSlotSelected: onSlotSelected,
          ),
        ],
      ],
    );
  }
}

class _SlotDaySection extends StatelessWidget {
  const _SlotDaySection({
    required this.dateLabel,
    required this.slots,
    required this.selectedSlot,
    required this.onSlotSelected,
  });

  final String dateLabel;
  final List<DeliverySlotModel> slots;
  final DeliverySlotModel? selectedSlot;
  final ValueChanged<DeliverySlotModel> onSlotSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dateLabel,
          style: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppThemeColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: slots.map((slot) {
            final isSelected = selectedSlot?.id == slot.id &&
                selectedSlot?.dateKey == slot.dateKey;
            final etaLabel = formatSlotEtaDisplay(slot.estimatedEta);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _DeliverySlotChip(
                  slot: slot,
                  isSelected: isSelected,
                  onTap: slot.available
                      ? () {
                          HapticFeedback.lightImpact();
                          onSlotSelected(slot);
                        }
                      : null,
                ),
                if (etaLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    etaLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: etaGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _DeliverySlotChip extends StatelessWidget {
  const _DeliverySlotChip({
    required this.slot,
    required this.isSelected,
    required this.onTap,
  });

  final DeliverySlotModel slot;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isAvailable = slot.available;

    final borderColor = isSelected
        ? AppThemeColors.primary
        : isAvailable
            ? AppThemeColors.border
            : AppThemeColors.border.withValues(alpha: 0.6);

    final textColor = isSelected
        ? AppThemeColors.primary
        : isAvailable
            ? AppThemeColors.textPrimary
            : AppThemeColors.textMuted;

    final backgroundColor = isSelected
        ? AppThemeColors.primaryLight.withValues(alpha: 0.25)
        : isAvailable
            ? AppThemeColors.white
            : AppThemeColors.surface2;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(AppRadius.radiusPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.radiusPill),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.radiusPill),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Text(
            slot.displayLabel,
            style: textTheme.bodySmall?.copyWith(
              color: textColor,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              decoration:
                  isAvailable ? null : TextDecoration.lineThrough,
              decorationColor: AppThemeColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyAddressPrompt extends StatelessWidget {
  const _EmptyAddressPrompt({required this.onAddTap});

  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onAddTap,
      borderRadius: BorderRadius.circular(AppRadius.radiusMd),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppThemeColors.surface2,
              borderRadius: BorderRadius.circular(AppRadius.radiusMd),
            ),
            child: const Icon(
              Icons.add_location_alt_rounded,
              color: AppThemeColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
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
                    color: AppThemeColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppThemeColors.textMuted,
          ),
        ],
      ),
    );
  }
}
