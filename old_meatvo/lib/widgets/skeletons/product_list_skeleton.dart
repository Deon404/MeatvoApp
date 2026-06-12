import 'package:flutter/material.dart';
import 'product_card_skeleton.dart';

// Import ProductListItemSkeleton from product_card_skeleton
export 'product_card_skeleton.dart' show ProductListItemSkeleton;

/// Skeleton loader for product list (grid view)
class ProductGridSkeleton extends StatelessWidget {
  final int count;

  const ProductGridSkeleton({
    super.key,
    this.count = 6,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: count,
      itemBuilder: (context, index) => const ProductCardSkeleton(),
    );
  }
}

/// Skeleton loader for product list (list view)
class ProductListSkeleton extends StatelessWidget {
  final int count;

  const ProductListSkeleton({
    super.key,
    this.count = 6,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: count,
      itemBuilder: (context, index) => const ProductListItemSkeleton(),
    );
  }
}

