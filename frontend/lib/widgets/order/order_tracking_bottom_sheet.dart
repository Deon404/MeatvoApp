import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../utils/order_display_util.dart';
import '../../utils/order_status_util.dart';
import '../order_status_live_indicator.dart';

/// Draggable bottom sheet for map-first order tracking.
class OrderTrackingBottomSheet extends StatelessWidget {
  const OrderTrackingBottomSheet({
    super.key,
    required this.orderId,
    required this.status,
    required this.detailsContent,
    this.heroCard,
    this.graceBanner,
    this.otpCard,
    this.partnerSection,
    this.trustStrip,
    this.reorderButton,
    this.statusChipLabel,
    this.initialSize = 0.42,
    this.minSize = 0.36,
    this.maxSize = 0.88,
  });

  final String orderId;
  final String status;
  final Widget detailsContent;
  final Widget? heroCard;
  final Widget? graceBanner;
  final Widget? otpCard;
  final Widget? partnerSection;
  final Widget? trustStrip;
  final Widget? reorderButton;
  final String? statusChipLabel;
  final double initialSize;
  final double minSize;
  final double maxSize;

  @override
  Widget build(BuildContext context) {
    final showTrust = shouldShowPartnerSection(status);

    return DraggableScrollableSheet(
      initialChildSize: initialSize,
      minChildSize: minSize,
      maxChildSize: maxSize,
      snap: true,
      snapSizes: [minSize, initialSize, maxSize],
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 20,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: CustomScrollView(
              controller: scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Text(
                              'Order #${formatOrderDisplayId(orderId)}',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            _StatusChip(
                              label: statusChipLabel ??
                                  orderTrackingChipLabelForStatus(status),
                            ),
                          ],
                        ),
                      ),
                      if (heroCard != null) ...[
                        const SizedBox(height: 12),
                        heroCard!,
                      ],
                      if (graceBanner != null) graceBanner!,
                      if (otpCard != null) ...[
                        const SizedBox(height: 8),
                        otpCard!,
                      ],
                      if (partnerSection != null) ...[
                        const SizedBox(height: 12),
                        partnerSection!,
                      ],
                      if (showTrust && trustStrip != null) ...[
                        const SizedBox(height: 10),
                        trustStrip!,
                      ],
                      if (reorderButton != null) ...[
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: reorderButton!,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.keyboard_arrow_up_rounded,
                            size: 18,
                            color: AppColors.textMuted.withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Swipe up for order details',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textMuted.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 1, color: AppColors.border),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'Order details',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: detailsContent,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (label.toLowerCase()) {
      case 'delivered':
        bg = AppColors.success.withValues(alpha: 0.15);
        fg = AppColors.success;
        break;
      case 'cancelled':
        bg = AppColors.error.withValues(alpha: 0.12);
        fg = AppColors.error;
        break;
      default:
        bg = AppColors.primaryLight;
        fg = AppColors.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
