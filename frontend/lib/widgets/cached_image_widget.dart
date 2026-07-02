import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../utils/media_url_resolver.dart';

/// Optimized cached network image widget with placeholder and error handling
/// This widget provides:
/// - Automatic image caching
/// - Loading placeholder
/// - Error fallback
/// - Memory efficient rendering
class CachedImageWidget extends StatelessWidget {
  final String? imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final double? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Color? placeholderColor;
  final Color? errorColor;

  const CachedImageWidget({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.placeholderColor,
    this.errorColor,
  });

  @override
  Widget build(BuildContext context) {
    // Smart-cast locals — `imageUrl!` / `borderRadius!` bangs removed.
    // Instance fields cannot be promoted across an `if` because they
    // are technically getters; capturing into locals fixes that and
    // also caches the final values for the rest of build().
    final url = imageUrl;
    if (url == null || url.isEmpty) {
      return _buildPlaceholder();
    }
    final cacheKey = MediaUrlResolver.cacheKey(url);

    Widget imageWidget = CachedNetworkImage(
      imageUrl: url,
      cacheKey: cacheKey,
      fit: fit,
      width: width,
      height: height,
      placeholder: (context, url) => placeholder ?? _buildPlaceholder(),
      errorWidget: (context, url, error) => errorWidget ?? _buildErrorWidget(),
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 100),
      memCacheWidth: width?.toInt(),
      memCacheHeight: height?.toInt(),
      maxWidthDiskCache: 1200,
      maxHeightDiskCache: 1200,
    );

    final radius = borderRadius;
    if (radius != null && radius > 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: placeholderColor ?? const Color(0xFFF5F5F5),
      child: Center(
        child: Icon(Icons.image_outlined, size: 40, color: Colors.grey[300]),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: width,
      height: height,
      color: errorColor ?? const Color(0xFFF5F5F5),
      child: Center(
        child: Icon(Icons.image_outlined, size: 40, color: Colors.grey[300]),
      ),
    );
  }
}

/// Circular cached image widget (for profile pictures, avatars, etc.)
class CachedCircleImageWidget extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Color? backgroundColor;

  const CachedCircleImageWidget({
    super.key,
    required this.imageUrl,
    required this.radius,
    this.placeholder,
    this.errorWidget,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    // Smart-cast local — `imageUrl!` bangs removed.
    final url = imageUrl;
    final hasUrl = url != null && url.isNotEmpty;
    final cacheKey = hasUrl ? MediaUrlResolver.cacheKey(url) : null;

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? AppColors.divider,
      child: !hasUrl
          ? (placeholder ??
                Icon(Icons.person, size: radius, color: AppColors.surface))
          : ClipOval(
              child: CachedNetworkImage(
                imageUrl: url,
                cacheKey: cacheKey,
                fit: BoxFit.cover,
                width: radius * 2,
                height: radius * 2,
                placeholder: (context, url) =>
                    placeholder ??
                    Icon(Icons.person, size: radius, color: AppColors.surface),
                errorWidget: (context, url, error) =>
                    errorWidget ??
                    Icon(Icons.person, size: radius, color: AppColors.surface),
                fadeInDuration: const Duration(milliseconds: 300),
                maxWidthDiskCache: 400,
                maxHeightDiskCache: 400,
              ),
            ),
    );
  }
}
