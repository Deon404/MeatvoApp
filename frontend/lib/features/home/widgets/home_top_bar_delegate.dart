import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../widgets/location/delivery_location_header.dart';

class HomeTopBarDelegate extends SliverPersistentHeaderDelegate {
  HomeTopBarDelegate({
    required this.topPadding,
    required this.locationTitle,
    this.locationSubtitle,
    this.isLocationLoading = false,
    required this.unreadCount,
    required this.onAddressTap,
    required this.onNotificationTap,
  });

  final double topPadding;
  final String locationTitle;
  final String? locationSubtitle;
  final bool isLocationLoading;
  final int unreadCount;
  final VoidCallback onAddressTap;
  final VoidCallback onNotificationTap;

  @override
  double get minExtent =>
      topPadding + DeliveryLocationHeader.barHeight;

  @override
  double get maxExtent => minExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: AppColors.primary,
      child: Column(
        children: [
          SizedBox(height: topPadding),
          DeliveryLocationHeader(
            title: locationTitle,
            subtitle: locationSubtitle,
            isLoading: isLocationLoading,
            onTap: onAddressTap,
            onNotificationTap: onNotificationTap,
            unreadCount: unreadCount,
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant HomeTopBarDelegate oldDelegate) {
    return topPadding != oldDelegate.topPadding ||
        locationTitle != oldDelegate.locationTitle ||
        locationSubtitle != oldDelegate.locationSubtitle ||
        isLocationLoading != oldDelegate.isLocationLoading ||
        unreadCount != oldDelegate.unreadCount;
  }
}
