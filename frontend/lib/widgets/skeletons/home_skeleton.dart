import 'package:flutter/material.dart';
import 'banner_skeleton.dart';
import 'category_skeleton.dart';
import 'shimmer_base.dart';
import '../../core/constants/app_constants.dart';
import '../common/skeleton_product_card.dart';

/// Complete skeleton loader for home screen
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 196,
            decoration: const BoxDecoration(
              color: AppColors.redPrimary,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(28),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShimmerContainer(width: 72, height: 10, borderRadius: 6),
                              SizedBox(height: 10),
                              ShimmerContainer(width: 170, height: 18, borderRadius: 8),
                            ],
                          ),
                        ),
                        SizedBox(width: 12),
                        ShimmerCircle(diameter: 42),
                        SizedBox(width: 10),
                        ShimmerCircle(diameter: 42),
                      ],
                    ),
                    SizedBox(height: 20),
                    ShimmerContainer(width: 230, height: 34, borderRadius: 16),
                  ],
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const ShimmerContainer(
                width: double.infinity,
                height: 44,
                borderRadius: 18,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: const [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerContainer(width: 90, height: 24, borderRadius: 999),
                        SizedBox(height: 14),
                        ShimmerContainer(width: 180, height: 28, borderRadius: 10),
                        SizedBox(height: 8),
                        ShimmerContainer(width: 160, height: 14, borderRadius: 8),
                        SizedBox(height: 8),
                        ShimmerContainer(width: 132, height: 14, borderRadius: 8),
                      ],
                    ),
                  ),
                  SizedBox(width: 16),
                  ShimmerContainer(width: 102, height: 102, borderRadius: 24),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.divider),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: ShimmerContainer(width: 120, height: 20, borderRadius: 8),
                  ),
                  SizedBox(height: 16),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: CategoryGridSkeleton(count: 4),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerContainer(width: 130, height: 20, borderRadius: 8),
                const SizedBox(height: 12),
                const BannerCarouselSkeleton(count: 2),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerContainer(width: 140, height: 20, borderRadius: 8),
                const SizedBox(height: 10),
                const ShimmerContainer(width: 180, height: 14, borderRadius: 8),
                const SizedBox(height: 14),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.68,
                  ),
                  itemCount: 4,
                  itemBuilder: (context, index) => const SkeletonProductCard(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

