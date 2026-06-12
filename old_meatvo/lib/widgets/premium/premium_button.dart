import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class PremiumButton extends StatefulWidget {
  const PremiumButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expanded = false,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expanded;
  final double height;

  @override
  State<PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<PremiumButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.isLoading;
    final child = AnimatedScale(
      duration: const Duration(milliseconds: 120),
      scale: _pressed && enabled ? 0.98 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.radiusLg),
          gradient: LinearGradient(
            colors: enabled
                ? const [Color(0xFFFF6B6B), AppThemeColors.primary]
                : [AppThemeColors.textMuted, AppThemeColors.textMuted],
          ),
          boxShadow: [
            BoxShadow(
              color: AppThemeColors.primary.withValues(alpha: 0.24),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: SizedBox(
          height: widget.height,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onPressed,
              onHighlightChanged: (value) => setState(() => _pressed = value),
              borderRadius: BorderRadius.circular(AppRadius.radiusLg),
              child: Center(
                child: widget.isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppThemeColors.white,
                          ),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(
                              widget.icon,
                              color: AppThemeColors.white,
                              size: 18,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                          ],
                          Text(
                            widget.label,
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: AppThemeColors.white,
                                ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.expanded) {
      return SizedBox(width: double.infinity, child: child);
    }
    return child;
  }
}
