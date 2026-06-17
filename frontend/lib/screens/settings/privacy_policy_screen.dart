import 'package:flutter/material.dart';

import 'legal_document_screen.dart';

/// Privacy Policy Screen - displays the app's privacy policy
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _sections = [
    LegalSection(
      title: 'Data We Collect',
      body:
          'We collect information necessary to provide our meat delivery service, '
          'including your delivery location, phone number, and order history. '
          'Location data is used to confirm delivery availability and route your orders. '
          'Your phone number is used for account verification and order updates.',
    ),
    LegalSection(
      title: 'How We Use Your Data',
      body:
          'Your data is used to fulfil deliveries, send order status notifications, '
          'and improve our app experience. We may analyse anonymised usage patterns '
          'to enhance product recommendations and delivery efficiency. '
          'We do not use your personal data for purposes unrelated to our service.',
    ),
    LegalSection(
      title: 'Data Security',
      body:
          'We store your personal information using encrypted storage and industry-standard '
          'security practices. Access to your data is restricted to authorised personnel only. '
          'We never sell your personal data to third parties.',
    ),
    LegalSection(
      title: 'Contact Us',
      body:
          'If you have questions about this privacy policy or how we handle your data, '
          'please contact us at support@meatvo.in.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentScreen(
      title: 'Privacy Policy',
      sections: _sections,
    );
  }
}
