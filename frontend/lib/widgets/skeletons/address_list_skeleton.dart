import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import 'shimmer_base.dart';

/// Skeleton placeholders for saved-address cards in the location sheet.
class AddressListSkeleton extends StatelessWidget {
  const AddressListSkeleton({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, __) => const _AddressCardSkeleton(),
    );
  }
}

class _AddressCardSkeleton extends StatelessWidget {
  const _AddressCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.greyLight,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          ShimmerContainer(width: 36, height: 36, borderRadius: 10),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerContainer(width: 72, height: 16, borderRadius: 6),
                SizedBox(height: 8),
                ShimmerContainer(width: double.infinity, height: 12, borderRadius: 6),
                SizedBox(height: 6),
                ShimmerContainer(width: 180, height: 12, borderRadius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
