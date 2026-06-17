import 'package:flutter/material.dart';

import '../../design_system/tokens/meatvo_colors.dart';
import '../../design_system/theme/meatvo_theme_extensions.dart';

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
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: mv.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: MeatvoColors.primaryLight,
              borderRadius: BorderRadius.circular(mv.radii.sm),
            ),
            alignment: Alignment.center,
            child: Text(
              '$step',
              style: textTheme.labelLarge?.copyWith(
                color: mv.brandPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: mv.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    color: mv.textPrimary,
                    letterSpacing: -0.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: textTheme.bodySmall?.copyWith(color: mv.textMuted),
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
