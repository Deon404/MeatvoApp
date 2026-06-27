import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../utils/eta_display_util.dart';
import '../../utils/order_status_util.dart';
import '../order_status_live_indicator.dart';
import 'order_tracking_help_button.dart';

/// Brand-primary status bar for map-first order tracking.
class OrderTrackingHeader extends StatelessWidget {
  const OrderTrackingHeader({
    super.key,
    required this.status,
    required this.onBack,
    required this.onRefresh,
    this.riderName,
    this.etaMinutes,
    this.distanceText,
    this.deliveredAt,
    this.isRefreshing = false,
    this.awaitingPayment = false,
  });

  final String status;
  final String? riderName;
  final int? etaMinutes;
  final String? distanceText;
  final DateTime? deliveredAt;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final bool isRefreshing;
  final bool awaitingPayment;

  String get _subtitle {
    if (awaitingPayment) {
      return 'Complete payment to confirm your order';
    }
    final s = normalizeOrderStatus(status);
    if (s == 'delivered') {
      if (deliveredAt != null) {
        return 'Delivered ${DateFormat('d MMM, h:mm a').format(deliveredAt!)}';
      }
      return 'Thank you for ordering';
    }
    if (isOrderCancelled(status)) return 'This order was cancelled';

    final parts = <String>[];
    final arriving = formatArrivingInLabel(etaMinutes);
    if (arriving.isNotEmpty) {
      parts.add(arriving);
    } else if (etaMinutes != null && etaMinutes! > 0) {
      parts.add('Arriving in $etaMinutes min');
    }
    if (distanceText != null && distanceText!.trim().isNotEmpty) {
      parts.add(distanceText!.trim());
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final headline = awaitingPayment
        ? 'Payment pending'
        : orderTrackingHeadlineForStatus(status, riderName: riderName);
    final subtitle = _subtitle;
    final imagePath = orderTrackingImageForStatus(status);
    final fallbackIcon = orderTrackingIconForStatus(status);

    return Material(
      color: AppColors.primary,
      elevation: 4,
      shadowColor: Colors.black26,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.white),
                tooltip: 'Back',
              ),
              Image.asset(
                imagePath,
                width: 52,
                height: 52,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                cacheWidth: 156,
                cacheHeight: 156,
                errorBuilder: (_, __, ___) => Icon(
                  fallbackIcon,
                  size: 36,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppColors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const OrderTrackingHelpButton(),
              IconButton(
                onPressed: isRefreshing ? null : onRefresh,
                icon: isRefreshing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, color: AppColors.white),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
