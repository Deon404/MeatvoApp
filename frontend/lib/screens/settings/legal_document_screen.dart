import 'package:flutter/material.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';

/// Shared scaffold for legal / policy document screens.
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.sections,
  });

  final String title;
  final List<LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: mv.surfaceWarm,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: mv.surfaceCard,
        foregroundColor: mv.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(mv.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < sections.length; i++) ...[
              if (i > 0) SizedBox(height: mv.spacing.xl),
              Text(
                sections[i].title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: mv.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: mv.spacing.xs),
              Text(
                sections[i].body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: mv.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class LegalSection {
  const LegalSection({required this.title, required this.body});

  final String title;
  final String body;
}
