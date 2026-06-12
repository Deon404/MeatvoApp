import 'package:flutter/material.dart';
import 'shimmer_base.dart';

/// Skeleton loader for banner carousel
class BannerSkeleton extends StatelessWidget {
  const BannerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ShimmerContainer(
        width: double.infinity,
        height: 200,
        borderRadius: 12,
      ),
    );
  }
}

/// Multiple banner skeletons for carousel
class BannerCarouselSkeleton extends StatelessWidget {
  final int count;

  const BannerCarouselSkeleton({
    super.key,
    this.count = 3,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: count,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(right: 12),
            child: const BannerSkeleton(),
          );
        },
      ),
    );
  }
}

