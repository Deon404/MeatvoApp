import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/constants/app_constants.dart';

/// Base shimmer widget with consistent styling
class ShimmerBase extends StatelessWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerBase({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: baseColor ?? AppColors.divider,
      highlightColor: highlightColor ?? AppColors.surface,
      period: const Duration(milliseconds: 1200),
      child: child,
    );
  }
}

/// Shimmer container for rectangular shapes (cards, text)
class ShimmerContainer extends StatelessWidget {
  final double width;
  final double height;
  final double? borderRadius;

  const ShimmerContainer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerBase(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius ?? 8),
        ),
      ),
    );
  }
}

/// Shimmer container for circular shapes (avatars, images)
class ShimmerCircle extends StatelessWidget {
  final double diameter;

  const ShimmerCircle({
    super.key,
    required this.diameter,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerBase(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

