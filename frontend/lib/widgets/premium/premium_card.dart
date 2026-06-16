import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

/// Premium card with enhanced shadows and optional gradient
class PremiumCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final bool showGradient;
  final List<Color>? gradientColors;
  final double? elevation;
  final Border? border;

  const PremiumCard({
    super.key,
    required this.child,
    this.onTap,
    this.backgroundColor,
    this.borderRadius = 16,
    this.margin,
    this.padding,
    this.showGradient = false,
    this.gradientColors,
    this.elevation,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: showGradient
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors ??
                    [
                      Colors.white,
                      AppColors.divider,
                    ],
              )
            : null,
        border: border ??
            Border.all(
              color: AppColors.divider,
              width: 1,
            ),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.08),
            blurRadius: elevation ?? 12,
            offset: Offset(0, (elevation ?? 12) / 3),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.04),
            blurRadius: elevation ?? 12,
            offset: Offset(0, (elevation ?? 12) / 6),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Premium gradient card
class PremiumGradientCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final List<Color> gradientColors;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const PremiumGradientCard({
    super.key,
    required this.child,
    required this.gradientColors,
    this.onTap,
    this.borderRadius = 16,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: onTap,
      borderRadius: borderRadius,
      margin: margin,
      padding: padding,
      showGradient: true,
      gradientColors: gradientColors,
      backgroundColor: Colors.transparent,
      border: null,
      child: child,
    );
  }
}

/// Premium card with image header
class PremiumImageCard extends StatelessWidget {
  final Widget child;
  final String? imageUrl;
  final Widget? imageWidget;
  final double imageHeight;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const PremiumImageCard({
    super.key,
    required this.child,
    this.imageUrl,
    this.imageWidget,
    this.imageHeight = 200,
    this.onTap,
    this.backgroundColor,
    this.borderRadius = 16,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    // Smart-cast locals — `imageUrl!` bang removed.
    final url = imageUrl;
    final overrideImage = imageWidget;

    final Widget headerImage;
    if (overrideImage != null) {
      headerImage = overrideImage;
    } else if (url != null && url.isNotEmpty) {
      headerImage = Image.network(
        url,
        height: imageHeight,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: imageHeight,
            color: AppColors.divider,
            child: const Icon(Icons.image_not_supported),
          );
        },
      );
    } else {
      headerImage = Container(
        height: imageHeight,
        color: AppColors.divider,
      );
    }

    return PremiumCard(
      onTap: onTap,
      backgroundColor: backgroundColor,
      borderRadius: borderRadius,
      margin: margin,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(borderRadius),
              topRight: Radius.circular(borderRadius),
            ),
            child: headerImage,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

