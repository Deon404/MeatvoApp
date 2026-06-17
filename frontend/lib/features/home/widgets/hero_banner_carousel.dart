import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../design_system/theme/meatvo_theme_extensions.dart';
import '../../../design_system/tokens/meatvo_colors.dart';
import '../../../models/banner_model.dart';
import '../../../utils/media_url_resolver.dart';
import '../../../widgets/common/banner_image_shimmer.dart';

class HeroBannerCarousel extends StatefulWidget {
  const HeroBannerCarousel({
    super.key,
    required this.banners,
    required this.isLoading,
    required this.onBannerTap,
    required this.maxHeight,
  });

  final List<BannerModel> banners;
  final bool isLoading;
  final ValueChanged<BannerModel> onBannerTap;
  final double maxHeight;

  static const String _fallbackChickenImage =
      'https://images.unsplash.com/photo-1604503468506-a8da286d644f?auto=format&fit=crop&w=900&q=80';

  @override
  State<HeroBannerCarousel> createState() => _HeroBannerCarouselState();
}

class _HeroBannerCarouselState extends State<HeroBannerCarousel> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    const oroshiHeight = 150.0;

    if (widget.isLoading && widget.banners.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Shimmer.fromColors(
          baseColor: mv.surfaceWarm,
          highlightColor: mv.surfaceCard,
          child: Container(
            height: oroshiHeight,
            decoration: BoxDecoration(
              color: mv.surfaceCard,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
    }

    if (widget.banners.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _PremiumFallbackBanner(
          height: oroshiHeight,
          onTap: () {},
        ),
      );
    }

    return Column(
      children: [
        CarouselSlider.builder(
          itemCount: widget.banners.length,
          itemBuilder: (context, index, _) {
            final banner = widget.banners[index];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _BannerSlide(
                banner: banner,
                height: oroshiHeight,
                onTap: () => widget.onBannerTap(banner),
              ),
            );
          },
          options: CarouselOptions(
            height: oroshiHeight,
            viewportFraction: 0.9,
            autoPlay: widget.banners.length > 1,
            autoPlayInterval: const Duration(seconds: 5),
            enlargeCenterPage: false,
            enableInfiniteScroll: widget.banners.length > 1,
            onPageChanged: (index, _) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),
        ),
        if (widget.banners.length > 1) ...[
          const SizedBox(height: 12),
          _DotIndicators(
            count: widget.banners.length,
            activeIndex: _currentIndex,
          ),
        ],
      ],
    );
  }
}

class _DotIndicators extends StatelessWidget {
  const _DotIndicators({
    required this.count,
    required this.activeIndex,
  });

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == activeIndex;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 8 : 6,
          height: isActive ? 8 : 6,
          decoration: BoxDecoration(
            color: isActive ? Colors.red : Colors.grey.shade400,
            borderRadius: BorderRadius.circular(isActive ? 4 : 3),
          ),
        );
      }),
    );
  }
}

class _BannerSlide extends StatelessWidget {
  const _BannerSlide({
    required this.banner,
    required this.height,
    required this.onTap,
  });

  final BannerModel banner;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final resolvedImage = MediaUrlResolver.resolve(banner.imageUrl) ?? '';
    final hasImage = resolvedImage.isNotEmpty;

    if (!hasImage) {
      return _PremiumFallbackBanner(height: height, onTap: onTap);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                BannerImageWithShimmer(
                  imageUrl: resolvedImage,
                  fit: BoxFit.cover,
                  baseColor: mv.surfaceWarm,
                  highlightColor: mv.surfaceCard,
                  errorWidget: (_, __, ___) => CachedNetworkImage(
                    imageUrl: HeroBannerCarousel._fallbackChickenImage,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        MeatvoColors.brandPrimaryDark.withValues(alpha: 0.82),
                        MeatvoColors.brandPrimary.withValues(alpha: 0.35),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: _BannerCopy(
                    title: banner.title,
                    subtitle: banner.subtitle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumFallbackBanner extends StatelessWidget {
  const _PremiumFallbackBanner({
    required this.height,
    required this.onTap,
  });

  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: HeroBannerCarousel._fallbackChickenImage,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          MeatvoColors.brandPrimary,
                          MeatvoColors.brandPrimaryDark,
                        ],
                      ),
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        MeatvoColors.brandPrimaryDark.withValues(alpha: 0.88),
                        MeatvoColors.brandPrimary.withValues(alpha: 0.5),
                        MeatvoColors.surfaceWarm.withValues(alpha: 0.15),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  right: -24,
                  bottom: -20,
                  child: Icon(
                    Icons.kebab_dining_rounded,
                    size: height * 0.55,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: _BannerCopy(
                    title: 'Farm-fresh chicken',
                    subtitle: 'Premium cuts · Same-day delivery',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerCopy extends StatelessWidget {
  const _BannerCopy({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          'MEATVO',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: MeatvoColors.surfaceWarm.withValues(alpha: 0.9),
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
        ),
        SizedBox(height: mv.spacing.xxs),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                height: 1.1,
                letterSpacing: -0.5,
              ),
        ),
        if ((subtitle ?? '').isNotEmpty) ...[
          SizedBox(height: mv.spacing.xxs),
          Text(
            subtitle!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.92),
                  height: 1.25,
                ),
          ),
        ],
      ],
    );
  }
}
