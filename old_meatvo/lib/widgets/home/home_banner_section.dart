import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../models/banner_model.dart';
import 'home_layout.dart';

class HomeBannerSection extends StatelessWidget {
  final List<BannerModel> banners;
  final bool isLoading;
  final ValueChanged<BannerModel> onBannerTap;

  const HomeBannerSection({
    super.key,
    required this.banners,
    required this.isLoading,
    required this.onBannerTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HomeLayout.horizontalPadding,
      ),
      child: SizedBox(
        height: HomeLayout.bannerHeight,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading && banners.isEmpty) {
      return _buildShimmer();
    }
    if (banners.isEmpty) {
      return _buildFallbackBanner();
    }
    if (banners.length == 1) {
      return _buildBannerImage(banners.first);
    }
    return _buildCarousel();
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8E8E8),
      highlightColor: const Color(0xFFF5F5F5),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(HomeLayout.bannerRadius),
        ),
      ),
    );
  }

  Widget _buildCarousel() {
    return CarouselSlider.builder(
      itemCount: banners.length,
      itemBuilder: (context, index, realIndex) {
        return _buildBannerImage(banners[index]);
      },
      options: CarouselOptions(
        height: HomeLayout.bannerHeight,
        viewportFraction: 1,
        enlargeCenterPage: false,
        autoPlay: banners.length > 1,
        autoPlayInterval: const Duration(seconds: 4),
        autoPlayAnimationDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  Widget _buildBannerImage(BannerModel banner) {
    return GestureDetector(
      onTap: () => onBannerTap(banner),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(HomeLayout.bannerRadius),
        child: CachedNetworkImage(
          imageUrl: banner.imageUrl,
          width: double.infinity,
          height: HomeLayout.bannerHeight,
          fit: BoxFit.cover,
          placeholder: (_, __) => _buildShimmer(),
          errorWidget: (_, __, ___) => _buildFallbackBanner(),
        ),
      ),
    );
  }

  Widget _buildFallbackBanner() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFCC0000), Color(0xFF8B0000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(HomeLayout.bannerRadius),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '🥩 Fresh Meat Daily',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Premium cuts delivered in 30 min',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
