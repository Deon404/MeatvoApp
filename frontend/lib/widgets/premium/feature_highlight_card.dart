import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';

class FeatureHighlightCard extends StatefulWidget {
  const FeatureHighlightCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback? onTap;
  final bool compact;

  @override
  State<FeatureHighlightCard> createState() => _FeatureHighlightCardState();
}

class _FeatureHighlightCardState extends State<FeatureHighlightCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedScale(
      duration: const Duration(milliseconds: 140),
      scale: _pressed ? 0.98 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  widget.onTap?.call();
                },
          onHighlightChanged: (value) {
            if (_pressed != value) {
              setState(() => _pressed = value);
            }
          },
          borderRadius: BorderRadius.circular(AppRadius.radiusLg),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.radiusLg),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        AppThemeColors.darkSurface.withValues(alpha: 0.94),
                        AppThemeColors.darkSurface2.withValues(alpha: 0.88),
                      ]
                    : [
                        Colors.white,
                        widget.accentColor.withValues(alpha: 0.08),
                      ],
              ),
              border: Border.all(
                color: isDark
                    ? AppThemeColors.darkBorder.withValues(alpha: 0.9)
                    : widget.accentColor.withValues(alpha: 0.14),
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.accentColor.withValues(alpha: isDark ? 0.10 : 0.12),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(widget.compact ? AppSpacing.md : AppSpacing.lg),
              child: SizedBox(
                height: widget.compact ? 150 : 168,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: widget.compact ? 44 : 52,
                      height: widget.compact ? 44 : 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            widget.accentColor.withValues(alpha: 0.24),
                            widget.accentColor.withValues(alpha: 0.10),
                          ],
                        ),
                      ),
                      child: Icon(
                        widget.icon,
                        color: widget.accentColor,
                        size: widget.compact ? 22 : 24,
                      ),
                    ),
                    SizedBox(height: widget.compact ? AppSpacing.sm : AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            maxLines: widget.compact ? 2 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: (widget.compact
                                    ? theme.textTheme.titleSmall
                                    : theme.textTheme.titleMedium)
                                ?.copyWith(
                                  color: isDark
                                      ? AppThemeColors.darkTextPrimary
                                      : AppThemeColors.textPrimary,
                                  height: 1.2,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              widget.subtitle,
                              maxLines: widget.compact ? 3 : 4,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? AppThemeColors.darkTextSecondary
                                    : AppThemeColors.textSecondary,
                                fontSize: widget.compact ? 12 : 12.5,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
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
  }
}
