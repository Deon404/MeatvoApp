import 'package:flutter/material.dart';

import '../../design_system/tokens/meatvo_colors.dart';
import '../../design_system/theme/meatvo_theme_extensions.dart';

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
    _scale = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
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
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: MeatvoColors.black.withValues(alpha: 0.45),
      child: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: mv.spacing.xl),
              padding: EdgeInsets.symmetric(
                horizontal: mv.spacing.xl,
                vertical: mv.spacing.lg,
              ),
              decoration: BoxDecoration(
                color: mv.surfaceCard,
                borderRadius: BorderRadius.circular(mv.radii.xl),
                boxShadow: mv.shadowLg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: mv.freshBadge.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 40,
                      color: mv.freshBadge,
                    ),
                  ),
                  SizedBox(height: mv.spacing.md),
                  Text(
                    'Order placed!',
                    style: textTheme.titleLarge?.copyWith(
                      color: mv.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: mv.spacing.xs),
                  Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: mv.textSecondary,
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
  const CheckoutLoadingOverlay({
    super.key,
    this.message = 'Placing your order…',
    this.subtitle = 'Please stay on this screen',
    this.errorMessage,
    this.onCancel,
  });

  final String message;
  final String subtitle;
  final String? errorMessage;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;
    final hasError = errorMessage != null && errorMessage!.isNotEmpty;

    return Material(
      color: MeatvoColors.black.withValues(alpha: 0.42),
      child: Center(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: mv.spacing.xl),
          padding: EdgeInsets.symmetric(
            horizontal: mv.spacing.xl,
            vertical: mv.spacing.lg + 4,
          ),
          decoration: BoxDecoration(
            color: mv.surfaceCard,
            borderRadius: BorderRadius.circular(mv.radii.xl),
            boxShadow: mv.shadowLg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: hasError
                    ? Icon(Icons.error_outline_rounded, size: 40, color: mv.error)
                    : CircularProgressIndicator(
                        strokeWidth: 3,
                        color: mv.brandPrimary,
                      ),
              ),
              SizedBox(height: mv.spacing.md),
              Text(
                hasError ? 'Could not place order' : message,
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(
                  color: mv.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: mv.spacing.xxs),
              Text(
                hasError ? errorMessage! : subtitle,
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: hasError ? mv.textSecondary : mv.textMuted,
                  height: 1.4,
                ),
              ),
              if (hasError && onCancel != null) ...[
                SizedBox(height: mv.spacing.md),
                TextButton(
                  onPressed: onCancel,
                  child: const Text('Dismiss'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
