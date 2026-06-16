import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../constants/home_strings.dart';
import '../../../design_system/theme/meatvo_theme_extensions.dart';
import '../../../design_system/tokens/meatvo_colors.dart';

/// Oroshi-style top bar: warm background, delivery location, notification badge.
class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    required this.locationLabel,
    required this.unreadCount,
    required this.profileInitial,
    this.profileImageUrl,
    required this.onAddressTap,
    required this.onNotificationTap,
    required this.onProfileTap,
  });

  final String locationLabel;
  final int unreadCount;
  final String profileInitial;
  final String? profileImageUrl;
  final VoidCallback onAddressTap;
  final VoidCallback onNotificationTap;
  final VoidCallback onProfileTap;

  static const double barHeight = 60;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFFFAF9F7),
      ),
      child: SizedBox(
        height: barHeight,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: mv.spacing.md),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onAddressTap();
                  },
                  borderRadius: BorderRadius.circular(mv.radii.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Deliver now',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    locationLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF1A1A1A),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Colors.grey.shade700,
                                  size: 18,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _IconBtn(
                onTap: onNotificationTap,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      Icons.notifications_outlined,
                      color: const Color(0xFF1A1A1A),
                      size: 24,
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFFAF9F7),
                              width: 1.5,
                            ),
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
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        customBorder: const CircleBorder(),
        child: SizedBox(width: 40, height: 40, child: Center(child: child)),
      ),
    );
  }
}
