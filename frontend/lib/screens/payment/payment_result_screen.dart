import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../models/order_model.dart';
import '../../core/constants/app_constants.dart';
import '../../utils/order_display_util.dart';
import '../../utils/responsive_helper.dart';
import '../orders/order_confirmation_screen.dart';
import '../orders/order_detail_screen.dart';

/// Payment Result Screen - Shows payment success/failure status
class PaymentResultScreen extends StatelessWidget {
  final bool isSuccess;
  final OrderModel? order;
  final String? paymentId;
  final String? errorMessage;
  final String? errorCode;
  final VoidCallback? onRetry;
  final Map<String, dynamic>? deliveryAddress;

  const PaymentResultScreen({
    super.key,
    required this.isSuccess,
    this.order,
    this.paymentId,
    this.errorMessage,
    this.errorCode,
    this.onRetry,
    this.deliveryAddress,
  });

  String _getErrorMessage(String? code, String? message) {
    if (code == null && message == null) {
      return 'Payment failed. Please try again.';
    }

    // Map common error codes to user-friendly messages
    switch (code) {
      case 'NETWORK_ERROR':
        return 'Network error. Please check your internet connection and try again.';
      case 'INVALID_CARD':
        return 'Invalid card details. Please check and try again.';
      case 'INSUFFICIENT_FUNDS':
        return 'Insufficient funds. Please use a different payment method.';
      case 'PAYMENT_CANCELLED':
        return 'Payment was cancelled. You can retry the payment.';
      case 'PAYMENT_DECLINED':
        return 'Payment was declined by your bank. Please contact your bank or try a different payment method.';
      default:
        return message ?? 'Payment failed. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Payment Status'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(R.sw(6, context)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: R.sh(5, context)),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSuccess
                      ? AppColors.success.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                ),
                child: Icon(
                  isSuccess ? Icons.check_circle : Icons.error_outline,
                  size: 64,
                  color: isSuccess ? AppColors.success : Colors.red,
                ),
              ),
              SizedBox(height: R.sh(4, context)),
              Text(
                isSuccess ? 'Payment Successful!' : 'Payment Failed',
                style: TextStyle(
                  fontSize: R.fontSize(28, context),
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: R.sh(2, context)),
              Text(
                isSuccess
                    ? 'Your payment has been processed successfully. Your order has been confirmed.'
                    : _getErrorMessage(errorCode, errorMessage),
                style: TextStyle(
                  fontSize: R.fontSize(16, context),
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: R.sh(4, context)),
              if (isSuccess && order != null) ...[
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppColors.divider, width: 1),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(R.sw(5, context)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment Details',
                          style: TextStyle(
                            fontSize: R.fontSize(18, context),
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: R.sh(2, context)),
                        _buildDetailRow(
                          context,
                          'Order Number',
                          '#${formatOrderDisplayId(order!.id)}',
                        ),
                        SizedBox(height: R.sh(1.5, context)),
                        if (paymentId != null) ...[
                          _buildDetailRow(
                            context,
                            'Payment ID',
                            paymentId!,
                          ),
                          SizedBox(height: R.sh(1.5, context)),
                        ],
                        _buildDetailRow(
                          context,
                          'Amount Paid',
                          '₹${order!.finalAmount.toStringAsFixed(2)}',
                        ),
                        SizedBox(height: R.sh(1.5, context)),
                        _buildDetailRow(
                          context,
                          'Payment Method',
                          'Online Payment',
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: R.sh(3, context)),
              ] else if (!isSuccess && order != null) ...[
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Colors.red.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(R.sw(5, context)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                            SizedBox(width: R.sw(2, context)),
                            Text(
                              'Order Status',
                              style: TextStyle(
                                fontSize: R.fontSize(16, context),
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: R.sh(1.5, context)),
                        Text(
                          'Your order has been created but payment is pending. You can retry the payment or contact support.',
                          style: TextStyle(
                            fontSize: R.fontSize(14, context),
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: R.sh(1.5, context)),
                        _buildDetailRow(
                          context,
                          'Order Number',
                          '#${formatOrderDisplayId(order!.id)}',
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: R.sh(3, context)),
              ],
              if (isSuccess && order != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => OrderConfirmationScreen(
                            order: order!,
                            deliveryAddress: deliveryAddress ?? {},
                            paymentId: paymentId,
                          ),
                        ),
                        (route) => route.isFirst,
                      );
                    },
                    icon: const Icon(Icons.check_circle),
                    label: Text(
                      'View Order Details',
                      style: TextStyle(fontSize: R.fontSize(15, context)),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      minimumSize: Size(
                        0,
                        math.max(44.0, R.sh(5.5, context)),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: R.sh(1.5, context)),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: Text(
                    'Continue Shopping',
                    style: TextStyle(fontSize: R.fontSize(14, context)),
                  ),
                ),
              ] else if (!isSuccess) ...[
                if (onRetry != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: Text(
                        'Retry Payment',
                        style: TextStyle(fontSize: R.fontSize(15, context)),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: Size(
                          0,
                          math.max(44.0, R.sh(5.5, context)),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: R.sh(1.5, context)),
                ],
                if (order != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                OrderDetailScreen(orderId: order!.id),
                          ),
                        );
                      },
                      icon: const Icon(Icons.receipt_long),
                      label: Text(
                        'View Order',
                        style: TextStyle(fontSize: R.fontSize(15, context)),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        minimumSize: Size(
                          0,
                          math.max(44.0, R.sh(5.5, context)),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: R.sh(1.5, context)),
                ],
                TextButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: Text(
                    'Go to Home',
                    style: TextStyle(fontSize: R.fontSize(14, context)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: R.fontSize(14, context),
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: R.fontSize(14, context),
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

