import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/home_strings.dart';
import '../../theme/app_theme.dart';

class SearchBarWidget extends StatelessWidget {
  final VoidCallback onTap;

  const SearchBarWidget({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppThemeColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.radiusXl),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppThemeColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.radiusPill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: AppThemeColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    HomeStrings.heroTagline,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppThemeColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                onTap();
              },
              borderRadius: BorderRadius.circular(AppRadius.radiusPill),
              child: Ink(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppThemeColors.surface2,
                  borderRadius: BorderRadius.circular(AppRadius.radiusPill),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      color: AppThemeColors.textMuted,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        HomeStrings.searchHint,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppThemeColors.textMuted,
                            ),
                      ),
                    ),
                    const Icon(
                      Icons.tune_rounded,
                      color: AppThemeColors.textMuted,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
