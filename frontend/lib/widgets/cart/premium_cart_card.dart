import 'package:flutter/material.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';
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
    final mv = context.meatvo;
    final card = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: mv.surfaceCard,
        borderRadius: BorderRadius.circular(mv.radii.xl),
        border: Border.all(color: mv.border.withValues(alpha: 0.85)),
        boxShadow: mv.shadowCard,
      ),
      child: child,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(mv.radii.xl),
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
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;
    final trailingWidget = trailing;

    return Padding(
      padding: EdgeInsets.only(bottom: mv.spacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleMedium?.copyWith(
                color: mv.textPrimary,
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
