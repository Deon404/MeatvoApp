import 'package:flutter/material.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../design_system/tokens/meatvo_colors.dart';
import '../../models/order_model.dart';
import '../../utils/address_display_util.dart';
import '../../utils/eta_display_util.dart';
import '../../utils/order_display_util.dart';
import '../../utils/responsive_helper.dart';
import 'order_detail_screen.dart';

/// Success screen after order placement — MeatvoTheme warm palette.
class OrderConfirmationScreen extends StatelessWidget {
  const OrderConfirmationScreen({
    super.key,
    required this.order,
    required this.deliveryAddress,
    this.paymentId,
  });

  final OrderModel order;
  final Map<String, dynamic> deliveryAddress;
  final String? paymentId;

  String _formatExpectedDelivery() {
    if (order.estimatedDeliveryTime != null) {
      return formatDeliveryByTime(order.estimatedDeliveryTime!);
    }
    final etaMinutes = order.etaMinutes;
    if (etaMinutes != null && etaMinutes > 0) {
      return formatArrivingInLabel(etaMinutes);
    }
    return 'Within 1 hour';
  }

  String _getOrderNumber() => formatOrderDisplayId(order.id);

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: mv.surfaceWarm,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(mv.spacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: mv.spacing.lg),
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: mv.freshBadge.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 60,
                        color: mv.freshBadge,
                      ),
                    ),
                    SizedBox(height: mv.spacing.md),
                    Text(
                      'Order Placed Successfully!',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: mv.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: mv.spacing.xs),
                    Text(
                      'Your order has been confirmed',
                      style: textTheme.bodyLarge?.copyWith(
                        color: mv.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: mv.spacing.lg),
                    _InfoCard(
                      child: Column(
                        children: [
                          Text(
                            'Order Number',
                            style: textTheme.bodySmall?.copyWith(
                              color: mv.textMuted,
                            ),
                          ),
                          SizedBox(height: mv.spacing.xs),
                          Text(
                            '#${_getOrderNumber()}',
                            style: textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: mv.brandPrimary,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: mv.spacing.md),
                    _InfoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order Summary',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: mv.textPrimary,
                            ),
                          ),
                          SizedBox(height: mv.spacing.sm),
                          ...order.items.map(
                            (item) => Padding(
                              padding: EdgeInsets.only(bottom: mv.spacing.sm),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.productName,
                                          style: textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: mv.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          '${item.quantity} ${item.unit}',
                                          style: textTheme.bodySmall?.copyWith(
                                            color: mv.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '₹${item.totalPrice.toStringAsFixed(0)}',
                                    style: textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: mv.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Divider(height: 24, color: mv.border),
                          _PriceRow(
                            label: 'Subtotal',
                            value:
                                '₹${order.totalAmount.toStringAsFixed(0)}',
                          ),
                          if (order.discountAmount != null &&
                              order.discountAmount! > 0)
                            _PriceRow(
                              label: 'Discount',
                              value:
                                  '-₹${order.discountAmount!.toStringAsFixed(0)}',
                              valueColor: mv.freshBadge,
                            ),
                          if (order.deliveryCharge != null &&
                              order.deliveryCharge! > 0)
                            _PriceRow(
                              label: 'Delivery Charge',
                              value:
                                  '₹${order.deliveryCharge!.toStringAsFixed(0)}',
                            )
                          else
                            _PriceRow(
                              label: 'Delivery Charge',
                              value: 'FREE',
                              valueColor: mv.freshBadge,
                            ),
                          Divider(height: 24, color: mv.border),
                          _PriceRow(
                            label: 'Total Amount',
                            value:
                                '₹${order.finalAmount.toStringAsFixed(0)}',
                            isBold: true,
                            valueColor: mv.brandPrimary,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: mv.spacing.md),
                    _InfoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                size: 20,
                                color: mv.brandPrimary,
                              ),
                              SizedBox(width: mv.spacing.xs),
                              Text(
                                'Delivery Details',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: mv.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: mv.spacing.sm),
                          _DetailRow(
                            icon: Icons.home_rounded,
                            title: formatAddressForDisplay(deliveryAddress),
                          ),
                          SizedBox(height: mv.spacing.sm),
                          _DetailRow(
                            icon: Icons.schedule_rounded,
                            label: 'Expected Delivery',
                            title: _formatExpectedDelivery(),
                          ),
                          SizedBox(height: mv.spacing.sm),
                          _DetailRow(
                            icon: order.paymentMethod == 'cod'
                                ? Icons.payments_outlined
                                : Icons.credit_card_rounded,
                            label: 'Payment Method',
                            title: order.paymentMethod == 'cod'
                                ? 'Cash on Delivery'
                                : 'Online Payment',
                            subtitle: paymentId != null && paymentId!.isNotEmpty
                                ? 'Payment ID: ${paymentId!.substring(0, paymentId!.length > 12 ? 12 : paymentId!.length)}...'
                                : null,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: mv.spacing.lg),
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.all(mv.spacing.md),
              decoration: BoxDecoration(
                color: mv.surfaceCard,
                boxShadow: mv.shadowMd,
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
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
                        icon: const Icon(Icons.shopping_bag_outlined),
                        label: const Text('Track Order'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mv.brandPrimary,
                          foregroundColor: MeatvoColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(mv.radii.md),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: mv.spacing.sm),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: mv.brandPrimary,
                          side: BorderSide(color: mv.brandPrimary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(mv.radii.md),
                          ),
                        ),
                        child: const Text('Continue Shopping'),
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
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(mv.spacing.md),
      decoration: BoxDecoration(
        color: mv.surfaceCard,
        borderRadius: BorderRadius.circular(mv.radii.lg),
        border: Border.all(color: mv.border),
        boxShadow: mv.shadowCard,
      ),
      child: child,
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: mv.spacing.xxs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
              color: mv.textPrimary,
            ),
          ),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
              color: valueColor ?? mv.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.title,
    this.label,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? label;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: mv.textMuted),
        SizedBox(width: mv.spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (label != null)
                Text(
                  label!,
                  style: textTheme.bodySmall?.copyWith(color: mv.textMuted),
                ),
              Text(
                title,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: mv.textPrimary,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: textTheme.bodySmall?.copyWith(color: mv.textMuted),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
