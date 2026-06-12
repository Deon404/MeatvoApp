import 'package:flutter/material.dart';
import 'order_card_skeleton.dart';

/// Skeleton loader for order list
class OrderListSkeleton extends StatelessWidget {
  final int count;

  const OrderListSkeleton({
    super.key,
    this.count = 5,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: count,
      itemBuilder: (context, index) => const OrderCardSkeleton(),
    );
  }
}

