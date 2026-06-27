import 'package:flutter/material.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../design_system/tokens/meatvo_colors.dart';
import '../../models/order_model.dart';
import '../../utils/order_display_util.dart';
import '../../utils/order_payment_util.dart';
import '../orders/order_detail_screen.dart';

/// Payment failure screen — calm recovery, single primary action.
class PaymentResultScreen extends StatelessWidget {
  const PaymentResultScreen({
    super.key,
    required this.order,
    this.deliveryAddress,
    this.errorMessage,
    this.errorCode,
    this.onRetry,
  });

  final OrderModel? order;
  final Map<String, dynamic>? deliveryAddress;
  final String? errorMessage;
  final String? errorCode;
  final VoidCallback? onRetry;

  String _resolveErrorMessage(String? code, String? message) {
    final trimmed = message?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }

    switch (code) {
      case 'NETWORK_ERROR':
        return 'Network error. Check your connection and try again.';
      case 'PAYMENT_CANCELLED':
        return 'Payment was cancelled. You can retry when ready.';
      case 'PAYMENT_DECLINED':
        return 'Payment was declined. Try another UPI app or payment method.';
      default:
        return 'Payment could not be completed. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: mv.surfaceWarm,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: mv.spacing.lg,
            vertical: mv.spacing.xl,
          ),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: mv.textMuted,
              ),
              SizedBox(height: mv.spacing.md),
              Text(
                'Payment Failed',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: mv.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: mv.spacing.sm),
              Text(
                _resolveErrorMessage(errorCode, errorMessage),
                style: textTheme.bodyMedium?.copyWith(
                  color: mv.textSecondary,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              if (order != null) ...[
                SizedBox(height: mv.spacing.sm),
                Text(
                  isPaymentFailed(order!)
                      ? 'Order #${formatOrderDisplayId(order!.id)} was cancelled — '
                          'no payment was charged.'
                      : 'Order #${formatOrderDisplayId(order!.id)} · '
                          '₹${order!.finalAmount.toStringAsFixed(0)} — '
                          'payment pending, you can retry',
                  style: textTheme.bodySmall?.copyWith(
                    color: mv.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const Spacer(flex: 3),
              if (onRetry != null)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: onRetry,
                    style: FilledButton.styleFrom(
                      backgroundColor: mv.brandPrimary,
                      foregroundColor: MeatvoColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(mv.radii.md),
                      ),
                    ),
                    child: const Text('Retry Payment'),
                  ),
                ),
              SizedBox(height: mv.spacing.md),
              if (order != null)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            OrderDetailScreen(orderId: order!.id),
                      ),
                    );
                  },
                  child: Text(
                    'View Order',
                    style: textTheme.labelLarge?.copyWith(
                      color: mv.brandPrimary,
                    ),
                  ),
                ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: Text(
                  'Continue Shopping',
                  style: textTheme.labelLarge?.copyWith(
                    color: mv.brandPrimary,
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
