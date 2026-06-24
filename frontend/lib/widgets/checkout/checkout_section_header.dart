import 'package:flutter/material.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';

/// Plain section label for checkout — no numbered badges.
class CheckoutSectionHeader extends StatelessWidget {
  const CheckoutSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    color: mv.textPrimary,
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

/// Thin divider between checkout sections.
class CheckoutSectionDivider extends StatelessWidget {
  const CheckoutSectionDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: mv.spacing.md),
      child: Divider(height: 1, thickness: 1, color: mv.border),
    );
  }
}
