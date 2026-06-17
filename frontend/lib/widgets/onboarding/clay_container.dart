import 'package:flutter/material.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../design_system/tokens/meatvo_colors.dart';
import '../../design_system/tokens/meatvo_radii.dart';
import '../../design_system/tokens/meatvo_shadows.dart';

/// Embossed clay card — dual shadow on warm surface.
class ClayContainer extends StatelessWidget {
  const ClayContainer({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.color,
    this.inset = false,
    this.width,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final Color? color;
  final bool inset;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final radius = borderRadius ?? MeatvoRadii.xl;

    return Container(
      width: width,
      padding: padding ?? EdgeInsets.all(mv.spacing.lg),
      decoration: BoxDecoration(
        color: color ?? MeatvoColors.surfaceCard,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: inset ? MeatvoShadows.clayInset : MeatvoShadows.clay,
      ),
      child: child,
    );
  }
}

/// Circular clay inset for hero icons on onboarding pages.
class ClayIconWell extends StatelessWidget {
  const ClayIconWell({
    super.key,
    required this.icon,
    this.size = 120,
    this.iconSize = 52,
    this.iconColor,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final tint = iconColor ?? mv.brandPrimary;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: MeatvoColors.primaryLight,
        boxShadow: MeatvoShadows.clayInset,
      ),
      child: Center(
        child: Icon(
          icon,
          size: iconSize,
          color: tint,
        ),
      ),
    );
  }
}

/// Small clay pill for page indicators.
class ClayPageDot extends StatelessWidget {
  const ClayPageDot({
    super.key,
    required this.isActive,
    this.activeColor,
  });

  final bool isActive;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final color = activeColor ?? mv.brandPrimary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 28 : 10,
      height: 10,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(MeatvoRadii.pill),
        color: isActive ? color : MeatvoColors.surfaceMuted,
        boxShadow: isActive ? null : MeatvoShadows.clayInset,
      ),
    );
  }
}
