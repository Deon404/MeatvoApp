import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

class ShimmerLoader extends StatefulWidget {
  const ShimmerLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = AppRadius.card,
  });

  final double width;
  final double height;
  final double borderRadius;

  static const Color _highlight = Color(0xFF3A3A3C);

  @override
  State<ShimmerLoader> createState() => _ShimmerLoaderState();
}

class _ShimmerLoaderState extends State<ShimmerLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final color = Color.lerp(
              AppColors.divider,
              ShimmerLoader._highlight,
              _animation.value,
            ) ??
            AppColors.divider;

        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}
