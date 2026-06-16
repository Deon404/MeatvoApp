// DEPRECATED: Use features/home/widgets/home_top_bar.dart instead.
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import 'premium_search_bar.dart';

class PremiumAppBar extends StatelessWidget {
  const PremiumAppBar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onAddressTap,
    required this.onNotificationTap,
    required this.onProfileTap,
    required this.onSearchTap,
    required this.searchHint,
    required this.unreadCount,
    required this.profileInitial,
  });

  final String title;
  final String subtitle;
  final VoidCallback onAddressTap;
  final VoidCallback onNotificationTap;
  final VoidCallback onProfileTap;
  final VoidCallback onSearchTap;
  final String searchHint;
  final int unreadCount;
  final String profileInitial;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1F0F3B), Color(0xFF4D1F7C), Color(0xFFFF4D6D)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _GlassIconButton(
                      wide: true,
                      onTap: onAddressTap,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            subtitle,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppThemeColors.white.withValues(alpha: 0.76),
                                ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                color: AppThemeColors.white,
                                size: 16,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: AppThemeColors.white,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _GlassIconButton(
                    onTap: onNotificationTap,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(
                          Icons.notifications_none_rounded,
                          color: AppThemeColors.white,
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: AppThemeColors.accentGold,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _GlassIconButton(
                    onTap: onProfileTap,
                    child: Text(
                      profileInitial,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppThemeColors.white,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Fresh picks for tonight',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: AppThemeColors.white,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Hand-cut meats, premium deals aur fast delivery.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppThemeColors.white.withValues(alpha: 0.86),
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              PremiumSearchBar(
                hintText: searchHint,
                onTap: onSearchTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.child,
    required this.onTap,
    this.wide = false,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: wide ? null : 48,
      height: 48,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Material(
            color: AppThemeColors.white.withValues(alpha: 0.12),
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                onTap();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.radiusLg),
                  border: Border.all(
                    color: AppThemeColors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
