import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/tokens/meatvo_durations.dart';
import '../../theme/app_theme.dart';

/// Modern selectable card used across checkout sections.
class CheckoutSelectionCard extends StatelessWidget {
  const CheckoutSelectionCard({
    super.key,
    required this.isSelected,
    required this.onTap,
    required this.child,
    this.enabled = true,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  final bool isSelected;
  final VoidCallback? onTap;
  final Widget child;
  final bool enabled;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: MeatvoDurations.normal,
      curve: MeatvoDurations.curve,
      decoration: BoxDecoration(
        color: AppThemeColors.white,
        borderRadius: BorderRadius.circular(AppRadius.radiusXl),
        border: Border.all(
          color: isSelected
              ? AppThemeColors.primary
              : AppThemeColors.border.withValues(alpha: 0.7),
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppThemeColors.primary.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled && onTap != null
              ? () {
                  HapticFeedback.lightImpact();
                  onTap!();
                }
              : null,
          borderRadius: BorderRadius.circular(AppRadius.radiusXl),
          child: Opacity(
            opacity: enabled ? 1 : 0.55,
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Radio-style indicator for selection cards.
class CheckoutSelectionIndicator extends StatelessWidget {
  const CheckoutSelectionIndicator({
    super.key,
    required this.isSelected,
  });

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: MeatvoDurations.fast,
      curve: MeatvoDurations.curve,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? AppThemeColors.primary : AppThemeColors.textMuted,
          width: 2,
        ),
        color: isSelected ? AppThemeColors.primary : AppThemeColors.white,
      ),
      child: isSelected
          ? const Icon(
              Icons.check_rounded,
              size: 14,
              color: AppThemeColors.white,
            )
          : null,
    );
  }
}
