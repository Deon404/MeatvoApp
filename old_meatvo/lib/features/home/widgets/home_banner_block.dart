import 'package:flutter/material.dart';

import '../../../models/banner_model.dart';
import 'delivery_promise_strip.dart';
import 'hero_banner_carousel.dart';

/// Banner carousel with trust ticker integrated at the top.
class HomeBannerBlock extends StatelessWidget {
  const HomeBannerBlock({
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

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const DeliveryPromiseStrip(),
        HeroBannerCarousel(
          banners: banners,
          isLoading: isLoading,
          onBannerTap: onBannerTap,
          maxHeight: maxHeight,
        ),
      ],
    );
  }
}
