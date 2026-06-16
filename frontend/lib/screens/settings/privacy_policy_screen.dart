import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// Privacy Policy Screen - displays the app's privacy policy
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              title: 'Data We Collect',
              body:
                  'We collect information necessary to provide our meat delivery service, '
                  'including your delivery location, phone number, and order history. '
                  'Location data is used to confirm delivery availability and route your orders. '
                  'Your phone number is used for account verification and order updates.',
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'How We Use Your Data',
              body:
                  'Your data is used to fulfil deliveries, send order status notifications, '
                  'and improve our app experience. We may analyse anonymised usage patterns '
                  'to enhance product recommendations and delivery efficiency. '
                  'We do not use your personal data for purposes unrelated to our service.',
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Data Security',
              body:
                  'We store your personal information using encrypted storage and industry-standard '
                  'security practices. Access to your data is restricted to authorised personnel only. '
                  'We never sell your personal data to third parties.',
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Contact Us',
              body:
                  'If you have questions about this privacy policy or how we handle your data, '
                  'please contact us at support@meatvo.in.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required String body}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.h3),
        const SizedBox(height: 8),
        Text(
          body,
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
