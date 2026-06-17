import 'package:flutter/material.dart';

import 'legal_document_screen.dart';

/// Terms of Service Screen - displays the app's terms of service
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  static const _sections = [
    LegalSection(
      title: 'Acceptance of Terms',
      body:
          'By using the Meatvo app, you agree to these Terms of Service. '
          'If you do not agree, please discontinue use of the app. '
          'We may update these terms from time to time, and continued use '
          'after changes constitutes acceptance of the revised terms.',
    ),
    LegalSection(
      title: 'Orders & Payments',
      body:
          'All orders placed through the app are subject to product availability '
          'and delivery area coverage. Prices displayed at checkout are final. '
          'Payment must be completed before order confirmation. '
          'Refunds and cancellations are handled according to our refund policy '
          'and applicable consumer protection laws.',
    ),
    LegalSection(
      title: 'User Responsibilities',
      body:
          'You are responsible for providing accurate delivery addresses and contact '
          'information. You agree to use the app only for lawful purposes and not '
          'to misuse the service, attempt unauthorised access, or interfere with '
          'other users\' experience.',
    ),
    LegalSection(
      title: 'Contact Us',
      body:
          'For questions about these terms or any disputes, '
          'please contact us at support@meatvo.in.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentScreen(
      title: 'Terms of Service',
      sections: _sections,
    );
  }
}
