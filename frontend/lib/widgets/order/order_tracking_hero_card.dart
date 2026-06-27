import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../utils/address_display_util.dart';
import '../../utils/eta_display_util.dart';
import '../../utils/order_status_util.dart';

/// Hero card: address, ETA countdown, progress bar, delivery type chip.
class OrderTrackingHeroCard extends StatelessWidget {
  const OrderTrackingHeroCard({
    super.key,
    required this.status,
    required this.deliveryAddress,
    this.etaMinutes,
    this.estimatedDeliveryTime,
    this.deliverySlotLabel,
    this.progressFraction,
    this.awaitingPayment = false,
  });

  final String status;
  final String? deliveryAddress;
  final int? etaMinutes;
  final DateTime? estimatedDeliveryTime;
  final String? deliverySlotLabel;
  final double? progressFraction;
  final bool awaitingPayment;

  @override
  Widget build(BuildContext context) {
    final s = normalizeOrderStatus(status);
    final isTerminal = s == 'delivered' || isOrderCancelled(status);
    final showEta = !awaitingPayment &&
        !isTerminal &&
        (formatArrivingInLabel(etaMinutes).isNotEmpty ||
            estimatedDeliveryTime != null);
    final fraction = progressFraction ?? trackingProgressFraction(status);
    final arrivingLabel = formatArrivingInLabel(etaMinutes);
    final byTime = estimatedDeliveryTime != null
        ? formatDeliveryByTime(estimatedDeliveryTime!)
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (awaitingPayment) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.payment_rounded,
                    size: 22,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Payment not completed',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Your order is saved. Complete payment to start preparation.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (showEta) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.access_time_filled_rounded,
                    size: 22,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (arrivingLabel.isNotEmpty)
                          Text(
                            arrivingLabel,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        if (byTime != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Arriving $byTime',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _DeliveryTypeChip(slotLabel: deliverySlotLabel),
                ],
              ),
              const SizedBox(height: 14),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    formatAddressForDisplay(deliveryAddress),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            if (!isTerminal && !awaitingPayment) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: fraction.clamp(0.05, 1.0),
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceMuted,
                  color: AppColors.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DeliveryTypeChip extends StatelessWidget {
  const _DeliveryTypeChip({this.slotLabel});

  final String? slotLabel;

  @override
  Widget build(BuildContext context) {
    final isScheduled = slotLabel != null && slotLabel!.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isScheduled
            ? AppColors.info.withValues(alpha: 0.12)
            : AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isScheduled ? slotLabel! : 'Express',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isScheduled ? AppColors.info : AppColors.success,
        ),
      ),
    );
  }
}
