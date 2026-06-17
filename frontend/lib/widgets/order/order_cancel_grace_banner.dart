import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../utils/order_status_util.dart';

/// Countdown banner for free cancel within 60 seconds of order placement.
class OrderCancelGraceBanner extends StatefulWidget {
  const OrderCancelGraceBanner({
    super.key,
    required this.createdAt,
    required this.status,
    required this.onCancel,
    this.isCancelling = false,
  });

  final DateTime? createdAt;
  final String status;
  final VoidCallback onCancel;
  final bool isCancelling;

  @override
  State<OrderCancelGraceBanner> createState() => _OrderCancelGraceBannerState();
}

class _OrderCancelGraceBannerState extends State<OrderCancelGraceBanner> {
  Timer? _timer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    final left = cancelGraceSecondsRemaining(widget.createdAt, widget.status);
    setState(() => _secondsLeft = left);
    if (left <= 0) _timer?.cancel();
  }

  @override
  void didUpdateWidget(covariant OrderCancelGraceBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status ||
        oldWidget.createdAt != widget.createdAt) {
      _tick();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!canCancelWithGrace(widget.createdAt, widget.status) ||
        _secondsLeft <= 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined, size: 20, color: AppColors.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Cancel free for $_secondsLeft s',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            TextButton(
              onPressed: widget.isCancelling ? null : widget.onCancel,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: widget.isCancelling
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
