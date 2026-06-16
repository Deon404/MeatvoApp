import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Numbered section header for checkout steps.
class CheckoutSectionHeader extends StatelessWidget {
  const CheckoutSectionHeader({
    super.key,
    required this.step,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final int step;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppThemeColors.primaryLight,
              borderRadius: BorderRadius.circular(AppRadius.radiusSm),
            ),
            alignment: Alignment.center,
            child: Text(
              '$step',
              style: textTheme.labelLarge?.copyWith(
                color: AppThemeColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    color: AppThemeColors.textPrimary,
                    letterSpacing: -0.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppThemeColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
