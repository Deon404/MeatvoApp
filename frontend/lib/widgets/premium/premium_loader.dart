import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../theme/app_theme.dart';

class PremiumLoader extends StatelessWidget {
  const PremiumLoader.home({super.key})
      : height = 420,
        count = 3;

  const PremiumLoader.carousel({super.key})
      : height = 180,
        count = 1;

  final double height;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).brightness == Brightness.dark
          ? AppThemeColors.darkSurface2
          : const Color(0xFFE8ECF1),
      highlightColor: Theme.of(context).brightness == Brightness.dark
          ? AppThemeColors.darkBorder
          : const Color(0xFFF6F8FB),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.radiusLg),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: List.generate(
              4,
              (_) => Expanded(
                child: Container(
                  height: 72,
                  margin: const EdgeInsets.only(right: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 254,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (_, __) => Container(
                width: 182,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.radiusLg),
                ),
              ),
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
              itemCount: count,
            ),
          ),
        ],
      ),
    );
  }
}
