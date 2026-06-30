import 'package:flutter/material.dart';
import '../../design_system/theme/meatvo_theme_extensions.dart';

class FaqItem {
  final String question;
  final String answer;
  const FaqItem({required this.question, required this.answer});
}

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static const List<FaqItem> _faqs = [
    FaqItem(
      question: 'Is the meat halal certified?',
      answer: 'Yes, all meat sold on Meatvo is sourced from '
          'halal-certified suppliers and processed following '
          'halal guidelines.',
    ),
    FaqItem(
      question: 'How fresh is the meat?',
      answer: 'All products are packed fresh on the day of '
          'delivery. We do not store pre-cut meat for more '
          'than 2 days.',
    ),
    FaqItem(
      question: 'What are your delivery hours?',
      answer: 'We deliver from 8:00 AM to 10:00 PM, 7 days a week.',
    ),
    FaqItem(
      question: 'What is your refund policy?',
      answer: 'If you are not satisfied with the quality of your '
          'order, contact us within 24 hours of delivery for a '
          'refund or replacement.',
    ),
    FaqItem(
      question: 'How do I track my order?',
      answer: 'Go to My Orders and tap on the active order to '
          'see live tracking, rider details, and delivery OTP.',
    ),
    FaqItem(
      question: 'Can I cancel my order?',
      answer: 'Yes, orders can be cancelled within 60 seconds of '
          'placing them, or before the order is packed, from the '
          'order details screen.',
    ),
    FaqItem(
      question: 'What payment methods do you accept?',
      answer: 'We accept UPI, cards, net banking via Cashfree, '
          'and Cash on Delivery (COD).',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    return Scaffold(
      backgroundColor: mv.surfaceWarm,
      appBar: AppBar(
        title: const Text('FAQ'),
        backgroundColor: mv.surfaceCard,
        elevation: 0,
      ),
      body: ListView.separated(
        padding: EdgeInsets.all(mv.spacing.md),
        itemCount: _faqs.length,
        separatorBuilder: (_, __) => SizedBox(height: mv.spacing.xs),
        itemBuilder: (context, index) {
          final faq = _faqs[index];
          return Container(
            decoration: BoxDecoration(
              color: mv.surfaceCard,
              borderRadius: BorderRadius.circular(mv.radii.md),
              border: Border.all(color: mv.border),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
              ),
              child: ExpansionTile(
                title: Text(
                  faq.question,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: mv.textPrimary,
                  ),
                ),
                childrenPadding: EdgeInsets.fromLTRB(
                  mv.spacing.md, 0, mv.spacing.md, mv.spacing.md,
                ),
                expandedAlignment: Alignment.centerLeft,
                children: [
                  Text(
                    faq.answer,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: mv.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
