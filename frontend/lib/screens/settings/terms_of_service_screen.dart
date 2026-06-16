import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// Terms of Service Screen - displays the app's terms of service
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Terms of Service'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              title: 'Acceptance of Terms',
              body:
                  'By using the Meatvo app, you agree to these Terms of Service. '
                  'If you do not agree, please discontinue use of the app. '
                  'We may update these terms from time to time, and continued use '
                  'after changes constitutes acceptance of the revised terms.',
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Orders & Payments',
              body:
                  'All orders placed through the app are subject to product availability '
                  'and delivery area coverage. Prices displayed at checkout are final. '
                  'Payment must be completed before order confirmation. '
                  'Refunds and cancellations are handled according to our refund policy '
                  'and applicable consumer protection laws.',
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'User Responsibilities',
              body:
                  'You are responsible for providing accurate delivery addresses and contact '
                  'information. You agree to use the app only for lawful purposes and not '
                  'to misuse the service, attempt unauthorised access, or interfere with '
                  'other users\' experience.',
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Contact Us',
              body:
                  'For questions about these terms or any disputes, '
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
