import 'package:flutter/material.dart';

class LoadingSkeleton extends StatelessWidget {
  final double height;

  const LoadingSkeleton({
    super.key,
    this.height = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
