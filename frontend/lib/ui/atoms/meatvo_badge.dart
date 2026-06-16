import 'package:flutter/material.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';

enum MeatvoBadgeVariant { fresh, discount, stock, popular }

class MeatvoBadge extends StatelessWidget {
  const MeatvoBadge({
    super.key,
    required this.label,
    this.variant = MeatvoBadgeVariant.discount,
  });

  final String label;
  final MeatvoBadgeVariant variant;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final Color bg;
    switch (variant) {
      case MeatvoBadgeVariant.fresh:
        bg = mv.freshBadge;
      case MeatvoBadgeVariant.stock:
        bg = mv.textMuted;
      case MeatvoBadgeVariant.popular:
        bg = mv.brandAccent;
      case MeatvoBadgeVariant.discount:
        bg = mv.brandPrimary;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: mv.spacing.xs,
        vertical: mv.spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(mv.radii.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
      ),
    );
  }
}
