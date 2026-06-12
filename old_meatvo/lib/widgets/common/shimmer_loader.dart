import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../theme/app_theme.dart';

enum _ShimmerLoaderVariant {
  productCard,
  productGrid,
  listTile,
  banner,
  circle,
  productDetail,
}

class ShimmerLoader extends StatelessWidget {
  final _ShimmerLoaderVariant _variant;
  final int _count;
  final double _size;

  const ShimmerLoader._({
    super.key,
    required _ShimmerLoaderVariant variant,
    int count = 1,
    double size = 64,
  })  : _variant = variant,
        _count = count,
        _size = size;

  const ShimmerLoader.productCard({Key? key, int count = 4})
      : this._(
          key: key,
          variant: _ShimmerLoaderVariant.productCard,
          count: count,
        );

  const ShimmerLoader.productGrid({Key? key, int count = 6})
      : this._(
          key: key,
          variant: _ShimmerLoaderVariant.productGrid,
          count: count,
        );

  const ShimmerLoader.listTile({Key? key, int count = 5})
      : this._(
          key: key,
          variant: _ShimmerLoaderVariant.listTile,
          count: count,
        );

  const ShimmerLoader.banner({Key? key})
      : this._(
          key: key,
          variant: _ShimmerLoaderVariant.banner,
        );

  const ShimmerLoader.circle({Key? key, double size = 64})
      : this._(
          key: key,
          variant: _ShimmerLoaderVariant.circle,
          size: size,
        );

  const ShimmerLoader.productDetail({Key? key})
      : this._(
          key: key,
          variant: _ShimmerLoaderVariant.productDetail,
        );

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8E8E8),
      highlightColor: const Color(0xFFF5F5F5),
      child: _buildVariant(),
    );
  }

  Widget _buildVariant() {
    switch (_variant) {
      case _ShimmerLoaderVariant.productCard:
        return SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: _count,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (_, __) => _block(
              width: 160,
              height: 220,
            ),
          ),
        );
      case _ShimmerLoaderVariant.productGrid:
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.md),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            childAspectRatio: 160 / 220,
          ),
          itemCount: _count,
          itemBuilder: (_, __) => _block(
            width: double.infinity,
            height: double.infinity,
          ),
        );
      case _ShimmerLoaderVariant.listTile:
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: _count,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (_, __) {
            return Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppThemeColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.radiusLg),
              ),
              child: Row(
                children: [
                  _block(width: 72, height: 72, radius: AppRadius.radiusMd),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _block(width: double.infinity, height: 16),
                        const SizedBox(height: AppSpacing.xs),
                        _block(width: 140, height: 12, radius: AppRadius.radiusSm),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      case _ShimmerLoaderVariant.banner:
        return Container(
          height: 140,
          margin: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFFEEEEEE),
            borderRadius: BorderRadius.circular(16),
          ),
        );
      case _ShimmerLoaderVariant.circle:
        return Container(
          width: _size,
          height: _size,
          decoration: const BoxDecoration(
            color: AppThemeColors.surface,
            shape: BoxShape.circle,
          ),
        );
      case _ShimmerLoaderVariant.productDetail:
        return ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            _block(width: double.infinity, height: 320, radius: 0),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _block(width: 220, height: 20),
                  const SizedBox(height: AppSpacing.sm),
                  _block(width: 120, height: 16, radius: AppRadius.radiusSm),
                  const SizedBox(height: AppSpacing.md),
                  _block(width: 140, height: 24),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: List.generate(
                      3,
                      (index) => Padding(
                        padding: EdgeInsets.only(
                          right: index == 2 ? 0 : AppSpacing.sm,
                        ),
                        child: _block(width: 88, height: 44),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _block(width: double.infinity, height: 90),
                  const SizedBox(height: AppSpacing.lg),
                  const ShimmerLoader.productCard(count: 3),
                ],
              ),
            ),
          ],
        );
    }
  }

  Widget _block({
    required double width,
    required double height,
    double radius = AppRadius.radiusLg,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppThemeColors.surface,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
