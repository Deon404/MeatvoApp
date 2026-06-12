import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Cached banner image with shimmer placeholder (no white flash on load).
class BannerImageWithShimmer extends StatelessWidget {
  const BannerImageWithShimmer({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.baseColor = const Color(0xFFE8E8E8),
    this.highlightColor = const Color(0xFFF5F5F5),
    this.errorWidget,
  });

  final String imageUrl;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Color baseColor;
  final Color highlightColor;
  final Widget Function(BuildContext context, String url, Object error)?
      errorWidget;

  @override
  Widget build(BuildContext context) {
    final image = CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 280),
      placeholder: (_, __) => _ShimmerBox(
        baseColor: baseColor,
        highlightColor: highlightColor,
      ),
      errorWidget: errorWidget ??
          (_, __, ___) => _ShimmerBox(
                baseColor: baseColor,
                highlightColor: highlightColor,
                showIcon: true,
              ),
    );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({
    required this.baseColor,
    required this.highlightColor,
    this.showIcon = false,
  });

  final Color baseColor;
  final Color highlightColor;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: baseColor,
        alignment: Alignment.center,
        child: showIcon
            ? Icon(
                Icons.image_outlined,
                color: highlightColor.withValues(alpha: 0.9),
                size: 36,
              )
            : null,
      ),
    );
  }
}
