import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/home_strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/atoms/safe_icon_tap.dart';

class HomeHeader extends StatelessWidget implements PreferredSizeWidget {
  static const double _toolbarHeight = 60;
  static const String searchHeroTag = 'home-search-bar';

  final String deliveryAreaLabel;
  final int unreadNotificationCount;
  final String? profileImageUrl;
  final String profileInitial;
  final VoidCallback onAddressTap;
  final Future<void> Function() onNotificationsTap;
  final VoidCallback onProfileTap;
  final bool searchExpanded;
  final TextEditingController? searchController;
  final FocusNode? searchFocusNode;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchToggle;

  const HomeHeader({
    super.key,
    required this.deliveryAreaLabel,
    required this.unreadNotificationCount,
    required this.profileImageUrl,
    required this.profileInitial,
    required this.onAddressTap,
    required this.onNotificationsTap,
    required this.onProfileTap,
    this.searchExpanded = false,
    this.searchController,
    this.searchFocusNode,
    this.onSearchChanged,
    this.onSearchToggle,
  });

  bool get _hasInlineSearch =>
      onSearchToggle != null && searchController != null;

  @override
  Size get preferredSize => Size.fromHeight(
        _toolbarHeight + (_hasInlineSearch ? 52 : 0),
      );

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppThemeColors.primary,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: _toolbarHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onAddressTap();
                        },
                        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                HomeStrings.deliveryLabel,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppThemeColors.white
                                          .withValues(alpha: 0.70),
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_pin,
                                    size: 16,
                                    color: AppThemeColors.white,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Expanded(
                                    child: Text(
                                      deliveryAreaLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: AppThemeColors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: AppThemeColors.white,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _HeaderActionButton(
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        await onNotificationsTap();
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(
                            Icons.notifications_none_rounded,
                            color: AppThemeColors.white,
                            size: 24,
                          ),
                          if (unreadNotificationCount > 0)
                            Positioned(
                              top: -3,
                              right: -3,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: AppThemeColors.accentGold,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.radiusPill),
                                  border: Border.all(
                                    color: AppThemeColors.primary,
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _HeaderActionButton(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onProfileTap();
                      },
                      // Builder + local smart-cast — eliminates three
                      // separate `profileImageUrl!` bangs that crashed
                      // when the user model was rebuilt mid-frame.
                      child: Builder(builder: (context) {
                        final url = profileImageUrl;
                        final hasUrl = url != null && url.isNotEmpty;
                        return CircleAvatar(
                          radius: 18,
                          backgroundColor: AppThemeColors.white
                              .withValues(alpha: 0.18),
                          backgroundImage: hasUrl
                              ? CachedNetworkImageProvider(url)
                              : null,
                          child: hasUrl
                              ? null
                              : Text(
                                  profileInitial,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(
                                        color: AppThemeColors.white,
                                      ),
                                ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
            if (_hasInlineSearch)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Hero(
                  tag: searchHeroTag,
                  child: Material(
                    color: Colors.transparent,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        color: AppThemeColors.white,
                        borderRadius: BorderRadius.circular(AppRadius.radiusPill),
                      ),
                      child: searchExpanded
                          ? TextField(
                              controller: searchController,
                              focusNode: searchFocusNode,
                              onChanged: onSearchChanged,
                              decoration: InputDecoration(
                                hintText: HomeStrings.searchHint,
                                prefixIcon: const Icon(Icons.search_rounded),
                                // SafeIconTap (no `_RenderInputPadding`) so
                                // the suffix slot can fit inside this
                                // 44-px-tall pill without overflowing.
                                suffixIcon: Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: SafeIconTap(
                                    icon: Icons.close_rounded,
                                    onTap: onSearchToggle,
                                  ),
                                ),
                                suffixIconConstraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                                border: InputBorder.none,
                              ),
                            )
                          : InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                onSearchToggle?.call();
                              },
                              borderRadius:
                                  BorderRadius.circular(AppRadius.radiusPill),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.sm,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.search_rounded,
                                      color: AppThemeColors.textMuted
                                          .withValues(alpha: 0.8),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        HomeStrings.searchHint,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: AppThemeColors.textMuted,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _HeaderActionButton({
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.radiusPill),
      child: Ink(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppThemeColors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppRadius.radiusPill),
        ),
        child: Center(child: child),
      ),
    );
  }
}
