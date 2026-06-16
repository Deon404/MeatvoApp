import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

class SkeletonProductCard extends StatefulWidget {
  const SkeletonProductCard({super.key});

  @override
  State<SkeletonProductCard> createState() => _SkeletonProductCardState();
}

class _SkeletonProductCardState extends State<SkeletonProductCard>
    with SingleTickerProviderStateMixin {
  static const Color _baseColor = Color(0xFFE0E0E0);
  static const Color _highlightColor = Color(0xFFF5F5F5);

  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
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
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          final shimmerColor =
              Color.lerp(_baseColor, _highlightColor, _animation.value) ??
                  _baseColor;

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _block(
                  color: shimmerColor,
                  width: double.infinity,
                  height: 120,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _block(
                        color: shimmerColor,
                        width: 80,
                        height: 12,
                      ),
                      const SizedBox(height: 8),
                      _block(
                        color: shimmerColor,
                        width: 50,
                        height: 10,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _block(
                                color: shimmerColor,
                                width: 60,
                                height: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _block(
                            color: shimmerColor,
                            width: 60,
                            height: 28,
                            radius: 10,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _block({
    required Color color,
    required double width,
    required double height,
    double radius = 8,
    BorderRadius? borderRadius,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius ?? BorderRadius.circular(radius),
      ),
    );
  }
}
