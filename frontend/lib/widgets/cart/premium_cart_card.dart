import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Shared premium surface for cart sections.
class PremiumCartCard extends StatelessWidget {
  const PremiumCartCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.margin,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppThemeColors.white,
        borderRadius: BorderRadius.circular(AppRadius.radiusXl),
        border: Border.all(
          color: AppThemeColors.border.withValues(alpha: 0.85),
        ),
        boxShadow: AppShadows.card,
      ),
      child: child,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.radiusXl),
        child: card,
      ),
    );
  }
}

class PremiumCartSectionTitle extends StatelessWidget {
  const PremiumCartSectionTitle({
    super.key,
    required this.title,
    this.trailing,
  });

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Smart-cast local — `trailing!` bang removed.
    final trailingWidget = trailing;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleMedium?.copyWith(
                color: AppThemeColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (trailingWidget != null) trailingWidget,
        ],
      ),
    );
  }
}
