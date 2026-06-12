import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../design_system/tokens/meatvo_radii.dart';
import '../../design_system/tokens/meatvo_spacing.dart';
import '../skeletons/shimmer_base.dart';

/// Skeleton shown while GPS + reverse geocoding is in progress.
class LocationFetchSkeleton extends StatelessWidget {
  const LocationFetchSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MeatvoSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(MeatvoRadii.xl),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ShimmerCircle(diameter: 44),
              const SizedBox(width: MeatvoSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    ShimmerContainer(width: double.infinity, height: 14, borderRadius: 8),
                    SizedBox(height: MeatvoSpacing.sm),
                    ShimmerContainer(width: 180, height: 12, borderRadius: 6),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: MeatvoSpacing.lg),
          const ShimmerContainer(width: double.infinity, height: 120, borderRadius: MeatvoRadii.md),
          const SizedBox(height: MeatvoSpacing.md),
          const ShimmerContainer(width: 140, height: 12, borderRadius: 6),
        ],
      ),
    );
  }
}
