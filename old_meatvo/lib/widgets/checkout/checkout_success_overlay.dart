import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Brief success overlay shown before navigating to confirmation.
class CheckoutSuccessOverlay extends StatefulWidget {
  const CheckoutSuccessOverlay({
    super.key,
    required this.message,
    this.onComplete,
  });

  final String message;
  final VoidCallback? onComplete;

  @override
  State<CheckoutSuccessOverlay> createState() => _CheckoutSuccessOverlayState();
}

class _CheckoutSuccessOverlayState extends State<CheckoutSuccessOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.5, curve: Curves.easeOut),
    );
    _controller.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) widget.onComplete?.call();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: AppThemeColors.black.withValues(alpha: 0.45),
      child: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.lg,
              ),
              decoration: BoxDecoration(
                color: AppThemeColors.white,
                borderRadius: BorderRadius.circular(AppRadius.radiusXl),
                boxShadow: AppShadows.elevated,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppThemeColors.success.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 40,
                      color: AppThemeColors.success,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Order placed!',
                    style: textTheme.titleLarge?.copyWith(
                      color: AppThemeColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppThemeColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline loading overlay for the checkout screen body.
class CheckoutLoadingOverlay extends StatelessWidget {
  const CheckoutLoadingOverlay({super.key, this.message = 'Placing your order…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: AppThemeColors.black.withValues(alpha: 0.35),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: AppThemeColors.white,
            borderRadius: BorderRadius.circular(AppRadius.radiusXl),
            boxShadow: AppShadows.elevated,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppThemeColors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                message,
                style: textTheme.titleSmall?.copyWith(
                  color: AppThemeColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
