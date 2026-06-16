import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../models/order_model.dart';
import '../../core/constants/app_constants.dart';
import '../../utils/order_display_util.dart';
import '../../utils/responsive_helper.dart';
import '../../screens/orders/order_detail_screen.dart';
import 'package:intl/intl.dart';

/// Order Confirmation Screen - Shows success message and order details after order placement
class OrderConfirmationScreen extends StatelessWidget {
  final OrderModel order;
  final String deliverySlot;
  final Map<String, dynamic> deliveryAddress;
  final String? paymentId;

  const OrderConfirmationScreen({
    super.key,
    required this.order,
    required this.deliverySlot,
    required this.deliveryAddress,
    this.paymentId,
  });

  String _formatDeliverySlot(String slot) {
    try {
      final dateTime = DateTime.parse(slot);
      final formatter = DateFormat('MMM dd, yyyy • hh:mm a');
      return formatter.format(dateTime);
    } catch (e) {
      return slot;
    }
  }

  String _formatDeliveryAddress(Map<String, dynamic> address) {
    final line1 = address['address_line1'] as String? ?? '';
    final line2 = address['address_line2'] as String? ?? '';
    final city = address['city'] as String? ?? '';
    final state = address['state'] as String? ?? '';
    final pincode = address['pincode'] as String? ?? '';

    final parts = <String>[];
    if (line1.isNotEmpty) parts.add(line1);
    if (line2.isNotEmpty) parts.add(line2);
    if (city.isNotEmpty) parts.add(city);
    if (state.isNotEmpty) parts.add(state);
    if (pincode.isNotEmpty) parts.add(pincode);

    return parts.join(', ');
  }

  String _getOrderNumber() => formatOrderDisplayId(order.id);

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(R.sw(6, context)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: R.sh(4, context)),
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        size: 60,
                        color: AppColors.success,
                      ),
                    ),
                    SizedBox(height: R.sh(3, context)),
                    Text(
                      'Order Placed Successfully!',
                      style: TextStyle(
                        fontSize: R.fontSize(24, context),
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: R.sh(1, context)),
                    Text(
                      'Your order has been confirmed',
                      style: TextStyle(
                        fontSize: R.fontSize(16, context),
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: R.sh(4, context)),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.divider, width: 1),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(R.sw(5, context)),
                        child: Column(
                          children: [
                            Text(
                              'Order Number',
                              style: TextStyle(
                                fontSize: R.fontSize(14, context),
                                color: AppColors.textSecondary,
                              ),
                            ),
                            SizedBox(height: R.sh(1, context)),
                            Text(
                              '#${_getOrderNumber()}',
                              style: TextStyle(
                                fontSize: R.fontSize(28, context),
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: R.sh(3, context)),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.divider, width: 1),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(R.sw(4, context)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order Summary',
                              style: TextStyle(
                                fontSize: R.fontSize(18, context),
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: R.sh(2, context)),
                            ...order.items.map((item) => Padding(
                                  padding:
                                      EdgeInsets.only(bottom: R.sh(1.5, context)),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.productName,
                                              style: TextStyle(
                                                fontSize: R.fontSize(14, context),
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            SizedBox(height: R.sh(0.5, context)),
                                            Text(
                                              '${item.quantity} ${item.unit}',
                                              style: TextStyle(
                                                fontSize: R.fontSize(12, context),
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '₹${item.totalPrice.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: R.fontSize(14, context),
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                            const Divider(height: 24),
                            _buildPriceRow(context, 'Subtotal',
                                '₹${order.totalAmount.toStringAsFixed(0)}'),
                            if (order.discountAmount != null &&
                                order.discountAmount! > 0)
                              _buildPriceRow(
                                context,
                                'Discount',
                                '-₹${order.discountAmount!.toStringAsFixed(0)}',
                                color: AppColors.success,
                              ),
                            if (order.deliveryCharge != null &&
                                order.deliveryCharge! > 0)
                              _buildPriceRow(
                                context,
                                'Delivery Charge',
                                '₹${order.deliveryCharge!.toStringAsFixed(0)}',
                              )
                            else
                              _buildPriceRow(
                                context,
                                'Delivery Charge',
                                'FREE',
                                color: AppColors.success,
                              ),
                            const Divider(height: 24),
                            _buildPriceRow(
                              context,
                              'Total Amount',
                              '₹${order.finalAmount.toStringAsFixed(0)}',
                              isBold: true,
                              fontSize: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: R.sh(3, context)),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.divider, width: 1),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(R.sw(4, context)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 20,
                                  color: AppColors.primary,
                                ),
                                SizedBox(width: R.sw(2, context)),
                                Text(
                                  'Delivery Details',
                                  style: TextStyle(
                                    fontSize: R.fontSize(18, context),
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: R.sh(2, context)),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.home,
                                  size: 18,
                                  color: AppColors.textSecondary,
                                ),
                                SizedBox(width: R.sw(2, context)),
                                Expanded(
                                  child: Text(
                                    _formatDeliveryAddress(deliveryAddress),
                                    style: TextStyle(
                                      fontSize: R.fontSize(14, context),
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: R.sh(2, context)),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  size: 18,
                                  color: AppColors.textSecondary,
                                ),
                                SizedBox(width: R.sw(2, context)),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Expected Delivery',
                                        style: TextStyle(
                                          fontSize: R.fontSize(12, context),
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      SizedBox(height: R.sh(0.5, context)),
                                      Text(
                                        _formatDeliverySlot(deliverySlot),
                                        style: TextStyle(
                                          fontSize: R.fontSize(14, context),
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: R.sh(2, context)),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  order.paymentMethod == 'cod'
                                      ? Icons.money
                                      : Icons.payment,
                                  size: 18,
                                  color: AppColors.textSecondary,
                                ),
                                SizedBox(width: R.sw(2, context)),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Payment Method',
                                        style: TextStyle(
                                          fontSize: R.fontSize(12, context),
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      SizedBox(height: R.sh(0.5, context)),
                                      Text(
                                        order.paymentMethod == 'cod'
                                            ? 'Cash on Delivery'
                                            : 'Online Payment',
                                        style: TextStyle(
                                          fontSize: R.fontSize(14, context),
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      if (paymentId != null &&
                                          paymentId!.isNotEmpty) ...[
                                        SizedBox(height: R.sh(0.5, context)),
                                        Text(
                                          'Payment ID: ${paymentId!.substring(0, paymentId!.length > 12 ? 12 : paymentId!.length)}...',
                                          style: TextStyle(
                                            fontSize: R.fontSize(11, context),
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: R.sh(4, context)),
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.all(R.sw(6, context)),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                bottom: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => OrderDetailScreen(
                                orderId: order.id,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.shopping_bag),
                        label: Text(
                          'View Order',
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
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: R.sh(1.5, context)),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          minimumSize: Size(
                            0,
                            math.max(44.0, R.sh(5.5, context)),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Continue Shopping',
                          style: TextStyle(fontSize: R.fontSize(15, context)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(
    BuildContext context,
    String label,
    String value, {
    Color? color,
    bool isBold = false,
    double fontSize = 14,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: R.sh(0.5, context)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: R.fontSize(fontSize, context),
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: R.fontSize(fontSize, context),
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

