import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../design_system/tokens/meatvo_spacing.dart';

/// Honest placeholder when backend feature is not yet available.
class ComingSoonPanel extends StatelessWidget {
  final String title;
  final String message;

  const ComingSoonPanel({
    super.key,
    required this.title,
    this.message = 'We are building this feature. Check back soon!',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MeatvoSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction_rounded,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: MeatvoSpacing.md),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: MeatvoSpacing.sm),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
