import 'package:flutter/material.dart';

import 'legal_document_screen.dart';

/// Refunds Policy Screen - displays the app's refund and cancellation policy.
class RefundsPolicyScreen extends StatelessWidget {
  const RefundsPolicyScreen({super.key});

  static const _sections = [
    LegalSection(
      title: 'Cancellation Window',
      body:
          'You may cancel an order before it enters preparation at no charge. '
          'Once preparation has started, cancellation may not be available or '
          'may be subject to a partial charge depending on order status.',
    ),
    LegalSection(
      title: 'Refund Processing',
      body:
          'Refunds for eligible cancellations are processed within 5–7 business days '
          'to your original payment method. For Cash on Delivery orders, refunds are '
          'issued to your Meatvo wallet or via bank transfer where applicable.',
    ),
    LegalSection(
      title: 'Non-Refundable Cases',
      body:
          'Orders that have been delivered, perishable items that have left our facility, '
          'or orders cancelled after dispatch may not qualify for a full refund. '
          'Quality issues should be reported within 24 hours of delivery for review.',
    ),
    LegalSection(
      title: 'Contact Us',
      body:
          'For refund requests or questions about this policy, '
          'please contact us at support@meatvo.in.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentScreen(
      title: 'Refunds Policy',
      sections: _sections,
    );
  }
}
