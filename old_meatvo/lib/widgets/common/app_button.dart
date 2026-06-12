import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';

enum AppButtonVariant {
  primary,
  secondary,
  ghost,
  danger,
}

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final bool isFullWidth;
  final IconData? icon;
  final double minHeight;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.isFullWidth = false,
    this.icon,
    this.minHeight = 52,
  });

  const AppButton.primary(
    this.label,
    this.onPressed, {
    super.key,
    this.isLoading = false,
    this.isFullWidth = false,
    this.icon,
    this.minHeight = 52,
  }) : variant = AppButtonVariant.primary;

  const AppButton.secondary(
    this.label,
    this.onPressed, {
    super.key,
    this.isLoading = false,
    this.isFullWidth = false,
    this.icon,
    this.minHeight = 52,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.ghost(
    this.label,
    this.onPressed, {
    super.key,
    this.isLoading = false,
    this.isFullWidth = false,
    this.icon,
    this.minHeight = 52,
  }) : variant = AppButtonVariant.ghost;

  const AppButton.danger(
    this.label,
    this.onPressed, {
    super.key,
    this.isLoading = false,
    this.isFullWidth = false,
    this.icon,
    this.minHeight = 52,
  }) : variant = AppButtonVariant.danger;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading
        ? null
        : onPressed == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onPressed!();
              };

    final child = isLoading
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(_loaderColor),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: AppSpacing.xs),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          );

    final minSize = Size(0, minHeight);

    final button = switch (variant) {
      AppButtonVariant.primary => ElevatedButton(
          onPressed: effectiveOnPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppThemeColors.primary,
            foregroundColor: AppThemeColors.white,
            minimumSize: minSize,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.radiusPill),
            ),
          ),
          child: child,
        ),
      AppButtonVariant.secondary => OutlinedButton(
          onPressed: effectiveOnPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppThemeColors.primary,
            minimumSize: minSize,
            side: const BorderSide(color: AppThemeColors.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.radiusPill),
            ),
          ),
          child: child,
        ),
      AppButtonVariant.ghost => TextButton(
          onPressed: effectiveOnPressed,
          style: TextButton.styleFrom(
            foregroundColor: AppThemeColors.primary,
            minimumSize: minSize,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.radiusPill),
            ),
          ),
          child: child,
        ),
      AppButtonVariant.danger => ElevatedButton(
          onPressed: effectiveOnPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppThemeColors.error,
            foregroundColor: AppThemeColors.white,
            minimumSize: minSize,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.radiusPill),
            ),
          ),
          child: child,
        ),
    };

    if (!isFullWidth) {
      return button;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : double.infinity;
        return SizedBox(width: width, child: button);
      },
    );
  }

  Color get _loaderColor {
    switch (variant) {
      case AppButtonVariant.secondary:
      case AppButtonVariant.ghost:
        return AppThemeColors.primary;
      case AppButtonVariant.primary:
      case AppButtonVariant.danger:
        return AppThemeColors.white;
    }
  }
}
