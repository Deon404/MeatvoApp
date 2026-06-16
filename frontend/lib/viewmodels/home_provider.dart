import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/banner_model.dart';
import '../services/address_service.dart';
import '../services/auth_service.dart';
import '../services/banner_service.dart';
import '../services/cart_service.dart';
import '../services/notification_service.dart';
import '../services/product_service.dart';
import 'home_viewmodel.dart';

final bannerServiceProvider = Provider<BannerService>((ref) {
  return BannerService();
});

/// Fetches active banners; returns an empty list on any error (no throw).
final bannerProvider = FutureProvider<List<BannerModel>>((ref) async {
  try {
    return await ref.read(bannerServiceProvider).getActiveBanners();
  } catch (_) {
    return const [];
  }
});

final homeViewModelProvider =
    StateNotifierProvider<HomeViewModel, HomeState>((ref) {
  return HomeViewModel(
    productService: ref.read(productServiceProvider),
    cartService: ref.read(cartServiceProvider),
    addressService: AddressService(),
    authService: AuthService(),
    bannerService: BannerService(),
    notificationService: NotificationService(),
  );
});
