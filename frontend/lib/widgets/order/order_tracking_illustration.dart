import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../core/constants/app_constants.dart';
import '../../utils/order_status_util.dart';
import '../order_status_live_indicator.dart';

/// State-based illustration for pre-delivery tracking (replaces static map).
class OrderTrackingIllustration extends StatefulWidget {
  const OrderTrackingIllustration({
    super.key,
    required this.status,
  });

  final String status;

  @override
  State<OrderTrackingIllustration> createState() =>
      _OrderTrackingIllustrationState();
}

class _OrderTrackingIllustrationState extends State<OrderTrackingIllustration>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String? _lottieAssetForStatus(String status) {
    final s = normalizeOrderStatus(status);
    switch (s) {
      case 'placed':
      case 'pending':
        return 'assets/animations/order_confirmed.json';
      case 'confirmed':
        return 'assets/animations/order_confirmed.json';
      case 'preparing':
      case 'packed':
        return 'assets/animations/order_packing.json';
      case 'assigned':
      case 'picked_up':
        return null;
      case 'delivered':
        return 'assets/animations/order_delivered.json';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final headline = orderTrackingHeadlineForStatus(widget.status);
    final lottieAsset = _lottieAssetForStatus(widget.status);
    final icon = orderTrackingIconForStatus(widget.status);

    return Container(
      color: AppColors.greyLight,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = 1.0 + (_pulseController.value * 0.04);
                  return Transform.scale(scale: scale, child: child);
                },
                child: _buildVisual(lottieAsset, icon),
              ),
              const SizedBox(height: 24),
              Text(
                headline,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _subtitleForStatus(widget.status),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisual(String? lottieAsset, IconData icon) {
    if (lottieAsset != null) {
      return SizedBox(
        width: 180,
        height: 180,
        child: Lottie.asset(
          lottieAsset,
          fit: BoxFit.contain,
          repeat: true,
          errorBuilder: (_, __, ___) => _iconFallback(icon),
        ),
      );
    }
    return _iconFallback(icon);
  }

  Widget _iconFallback(IconData icon) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.1),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 24,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Icon(icon, size: 56, color: AppColors.primary),
    );
  }

  String _subtitleForStatus(String status) {
    final s = normalizeOrderStatus(status);
    switch (s) {
      case 'placed':
      case 'pending':
        return 'We received your order';
      case 'confirmed':
        return 'Your order is confirmed';
      case 'preparing':
        return 'Fresh cuts being packed for you';
      case 'assigned':
        return 'A delivery partner will pick up soon';
      case 'picked_up':
        return 'Order picked up from store';
      case 'delivered':
        return 'Enjoy your fresh order!';
      default:
        return 'Sit back — we will update you shortly';
    }
  }
}
