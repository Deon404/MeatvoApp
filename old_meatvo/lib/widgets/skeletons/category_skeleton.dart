import 'package:flutter/material.dart';
import 'shimmer_base.dart';
import '../../core/constants/app_constants.dart';

/// Skeleton loader for category card
class CategorySkeleton extends StatelessWidget {
  const CategorySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShimmerContainer(
            width: 58,
            height: 58,
            borderRadius: 18,
          ),
          const SizedBox(height: 8),
          ShimmerContainer(width: 52, height: 12),
        ],
      ),
    );
  }
}

/// Grid of category skeletons
class CategoryGridSkeleton extends StatelessWidget {
  final int count;

  const CategoryGridSkeleton({
    super.key,
    this.count = 8,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return SizedBox(
            width: 82,
            child: const CategorySkeleton(),
          );
        },
      ),
    );
  }
}

