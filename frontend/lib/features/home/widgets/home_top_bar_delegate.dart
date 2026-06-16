import 'package:flutter/material.dart';

import 'home_top_bar.dart';

class HomeTopBarDelegate extends SliverPersistentHeaderDelegate {
  HomeTopBarDelegate({
    required this.topPadding,
    required this.locationLabel,
    required this.unreadCount,
    required this.profileInitial,
    this.profileImageUrl,
    required this.onAddressTap,
    required this.onNotificationTap,
    required this.onProfileTap,
  });

  final double topPadding;
  final String locationLabel;
  final int unreadCount;
  final String profileInitial;
  final String? profileImageUrl;
  final VoidCallback onAddressTap;
  final VoidCallback onNotificationTap;
  final VoidCallback onProfileTap;

  @override
  double get minExtent => topPadding + HomeTopBar.barHeight;

  @override
  double get maxExtent => minExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Column(
      children: [
        SizedBox(height: topPadding),
        HomeTopBar(
          locationLabel: locationLabel,
          unreadCount: unreadCount,
          profileInitial: profileInitial,
          profileImageUrl: profileImageUrl,
          onAddressTap: onAddressTap,
          onNotificationTap: onNotificationTap,
          onProfileTap: onProfileTap,
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(covariant HomeTopBarDelegate oldDelegate) {
    return topPadding != oldDelegate.topPadding ||
        locationLabel != oldDelegate.locationLabel ||
        unreadCount != oldDelegate.unreadCount ||
        profileInitial != oldDelegate.profileInitial ||
        profileImageUrl != oldDelegate.profileImageUrl;
  }
}
