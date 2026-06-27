import 'package:flutter/material.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';
import 'checkout_section_header.dart';

class CheckoutCancellationPolicy extends StatefulWidget {
  const CheckoutCancellationPolicy({super.key});

  static const _shortPolicy =
      'Orders can be cancelled before dispatch from My Orders or by contacting '
      'Meatvo support. Once your fresh meat order is out for delivery, '
      'cancellation may not be possible due to the perishable nature of products.';

  static const _fullPolicy =
      'Orders can be cancelled before dispatch from My Orders or by contacting '
      'Meatvo support via WhatsApp or email.\n\n'
      'Once your fresh meat order is packed or out for delivery, cancellation '
      'may not be possible due to the perishable nature of our products.\n\n'
      'Refunds for eligible cancellations are processed within 5–7 business days '
      'to your original payment method. For Cash on Delivery orders, refunds are '
      'issued as store credit or bank transfer after verification.\n\n'
      'For help, reach us at support@meatvo.in or via the Help section in the app.';

  @override
  State<CheckoutCancellationPolicy> createState() =>
      _CheckoutCancellationPolicyState();
}

class _CheckoutCancellationPolicyState extends State<CheckoutCancellationPolicy> {
  bool _expanded = false;

  void _showFullPolicy() {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: mv.surfaceCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(
          mv.spacing.lg,
          mv.spacing.md,
          mv.spacing.lg,
          mv.spacing.lg + MediaQuery.paddingOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: mv.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: mv.spacing.md),
            Text(
              'Cancellation policy',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: mv.textPrimary,
              ),
            ),
            SizedBox(height: mv.spacing.sm),
            Text(
              CheckoutCancellationPolicy._fullPolicy,
              style: textTheme.bodyMedium?.copyWith(
                color: mv.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CheckoutSectionHeader(title: 'Cancellation policy'),
        Text(
          _expanded
              ? CheckoutCancellationPolicy._fullPolicy
              : CheckoutCancellationPolicy._shortPolicy,
          style: textTheme.bodySmall?.copyWith(
            color: mv.textSecondary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () {
            if (_expanded) {
              _showFullPolicy();
            } else {
              setState(() => _expanded = true);
            }
          },
          child: Text(
            'Read more',
            style: textTheme.bodySmall?.copyWith(
              color: mv.textMuted,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
              decorationColor: mv.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}
