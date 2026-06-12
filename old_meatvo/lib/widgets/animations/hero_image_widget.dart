import 'package:flutter/material.dart';
import '../cached_image_widget.dart';

/// Hero Image Widget
/// Wraps an image with Hero animation for smooth transitions
/// 
/// Usage:
/// - Use same heroTag in both source and destination screens
/// - Provides smooth shared element transition
class HeroImageWidget extends StatelessWidget {
  final String heroTag;
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const HeroImageWidget({
    super.key,
    required this.heroTag,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;

    // Smart-cast local — `imageUrl!` bangs removed. Instance fields on
    // a StatelessWidget cannot be smart-cast across an `if` because
    // they are technically getters; capturing into a local fixes that.
    final url = imageUrl;
    if (url != null && url.isNotEmpty) {
      imageWidget = CachedImageWidget(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        placeholder: placeholder,
        errorWidget: errorWidget,
      );
    } else {
      imageWidget = Container(
        width: width,
        height: height,
        color: const Color(0xFFF5F5F5),
        alignment: Alignment.center,
        child: Icon(
          Icons.image_outlined,
          color: Colors.grey[300],
          size: 40,
        ),
      );
    }

    final radius = borderRadius;
    if (radius != null) {
      imageWidget = ClipRRect(
        borderRadius: radius,
        child: imageWidget,
      );
    }

    return Hero(
      tag: heroTag,
      child: Material(
        color: Colors.transparent,
        child: imageWidget,
      ),
    );
  }
}

/// Helper function to generate unique hero tag for product images
String getProductHeroTag(String productId) {
  return 'product_image_$productId';
}

