import 'package:flutter/material.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../design_system/tokens/meatvo_colors.dart';
import '../../models/order_model.dart';
import '../../utils/order_display_util.dart';
import '../orders/order_detail_screen.dart';

/// Payment failure screen — warm MeatvoTheme, retry re-opens Cashfree checkout.
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

  String _getErrorMessage(String? code, String? message) {
    switch (code) {
      case 'NETWORK_ERROR':
        return 'Network error. Check your connection and try again.';
      case 'PAYMENT_CANCELLED':
        return 'Payment was cancelled. You can retry when ready.';
      case 'PAYMENT_DECLINED':
        return 'Payment was declined. Try another UPI app or payment method.';
      default:
        return message ?? 'Payment could not be completed. Please try again.';
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
        child: SingleChildScrollView(
          padding: EdgeInsets.all(mv.spacing.lg),
          child: Column(
            children: [
              SizedBox(height: mv.spacing.xl),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: MeatvoColors.error.withValues(alpha: 0.1),
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 52,
                  color: MeatvoColors.error,
                ),
              ),
              SizedBox(height: mv.spacing.lg),
              Text(
                'Payment Failed',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: mv.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: mv.spacing.sm),
              Text(
                _getErrorMessage(errorCode, errorMessage),
                style: textTheme.bodyLarge?.copyWith(
                  color: mv.textSecondary,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              if (order != null) ...[
                SizedBox(height: mv.spacing.lg),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(mv.spacing.md),
                  decoration: BoxDecoration(
                    color: mv.surfaceCard,
                    borderRadius: BorderRadius.circular(mv.radii.lg),
                    border: Border.all(
                      color: MeatvoColors.error.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order saved — payment pending',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: mv.textPrimary,
                        ),
                      ),
                      SizedBox(height: mv.spacing.xs),
                      Text(
                        'Your order is on hold until payment completes. '
                        'Retry now or pay later from My Orders.',
                        style: textTheme.bodySmall?.copyWith(
                          color: mv.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: mv.spacing.sm),
                      _DetailLine(
                        label: 'Order',
                        value: '#${formatOrderDisplayId(order!.id)}',
                      ),
                      _DetailLine(
                        label: 'Amount',
                        value: '₹${order!.finalAmount.toStringAsFixed(0)}',
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: mv.spacing.xl),
              if (onRetry != null)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry Payment'),
                    style: FilledButton.styleFrom(
                      backgroundColor: mv.brandPrimary,
                      foregroundColor: MeatvoColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(mv.radii.md),
                      ),
                    ),
                  ),
                ),
              if (order != null) ...[
                SizedBox(height: mv.spacing.sm),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              OrderDetailScreen(orderId: order!.id),
                        ),
                      );
                    },
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('View Order'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: mv.brandPrimary,
                      side: BorderSide(color: mv.brandPrimary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(mv.radii.md),
                      ),
                    ),
                  ),
                ),
              ],
              SizedBox(height: mv.spacing.sm),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(top: mv.spacing.xxs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(color: mv.textMuted),
          ),
          Text(
            value,
            style: textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: mv.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
