import 'package:flutter/material.dart';
import 'shimmer_base.dart';
import '../../core/constants/app_constants.dart';

/// Skeleton loader for order card
class OrderCardSkeleton extends StatelessWidget {
  const OrderCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order ID and date row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerContainer(width: 120, height: 16),
              ShimmerContainer(width: 80, height: 14),
            ],
          ),
          const SizedBox(height: 12),
          
          // Status badge skeleton
          ShimmerContainer(width: 100, height: 24, borderRadius: 12),
          const SizedBox(height: 12),
          
          // Order items skeleton (3 items)
          ...List.generate(3, (index) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                ShimmerContainer(width: 50, height: 50, borderRadius: 8),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerContainer(width: double.infinity, height: 14),
                      const SizedBox(height: 4),
                      ShimmerContainer(width: 80, height: 12),
                    ],
                  ),
                ),
                ShimmerContainer(width: 60, height: 14),
              ],
            ),
          )),
          const SizedBox(height: 12),
          
          // Divider
          const Divider(),
          const SizedBox(height: 12),
          
          // Total amount and action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerContainer(width: 100, height: 18),
              Row(
                children: [
                  ShimmerContainer(width: 80, height: 32, borderRadius: 8),
                  const SizedBox(width: 8),
                  ShimmerContainer(width: 80, height: 32, borderRadius: 8),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

