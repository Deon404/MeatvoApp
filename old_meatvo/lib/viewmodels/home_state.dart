import '../models/address_model.dart';
import '../models/banner_model.dart';
import '../models/cart_model.dart';
import '../models/home_category_item.dart';
import '../models/product_variant_model.dart';
import '../models/user_model.dart';

const Object unsetHomeStateValue = Object();

class HomeState {
  final bool isInitialLoading;
  final bool isRefreshing;
  final bool isBannerLoading;
  final bool isCategoriesLoading;
  final bool isFeaturedLoading;
  final bool isRecommendedLoading;
  final bool isBestSellersLoading;
  final String? pageError;
  final String? bannerError;
  final String? categoriesError;
  final String? featuredError;
  final String? recommendedError;
  final String? bestSellersError;
  final String? cartErrorMessage;
  final AddressModel? defaultAddress;
  final UserModel? user;
  final CartModel cart;
  final int unreadNotificationCount;
  final List<BannerModel> banners;
  final List<HomeCategoryItem> categories;
  final List<ProductWithVariants> featuredProducts;
  final List<ProductWithVariants> recommendedProducts;
  final List<ProductWithVariants> bestSellingProducts;
  final List<ProductWithVariants> reorderProducts;
  final Set<String> busyProductIds;

  const HomeState({
    required this.isInitialLoading,
    required this.isRefreshing,
    required this.isBannerLoading,
    required this.isCategoriesLoading,
    required this.isFeaturedLoading,
    required this.isRecommendedLoading,
    required this.isBestSellersLoading,
    required this.pageError,
    required this.bannerError,
    required this.categoriesError,
    required this.featuredError,
    required this.recommendedError,
    required this.bestSellersError,
    required this.cartErrorMessage,
    required this.defaultAddress,
    required this.user,
    required this.cart,
    required this.unreadNotificationCount,
    required this.banners,
    required this.categories,
    required this.featuredProducts,
    required this.recommendedProducts,
    required this.bestSellingProducts,
    required this.reorderProducts,
    required this.busyProductIds,
  });

  factory HomeState.initial() => HomeState(
        isInitialLoading: true,
        isRefreshing: false,
        isBannerLoading: true,
        isCategoriesLoading: true,
        isFeaturedLoading: true,
        isRecommendedLoading: true,
        isBestSellersLoading: true,
        pageError: null,
        bannerError: null,
        categoriesError: null,
        featuredError: null,
        recommendedError: null,
        bestSellersError: null,
        cartErrorMessage: null,
        defaultAddress: null,
        user: null,
        cart: CartModel(),
        unreadNotificationCount: 0,
        banners: const [],
        categories: const [],
        featuredProducts: const [],
        recommendedProducts: const [],
        bestSellingProducts: const [],
        reorderProducts: const [],
        busyProductIds: const <String>{},
      );

  bool get hasContent =>
      banners.isNotEmpty ||
      categories.isNotEmpty ||
      featuredProducts.isNotEmpty ||
      recommendedProducts.isNotEmpty ||
      bestSellingProducts.isNotEmpty;

  HomeState copyWith({
    bool? isInitialLoading,
    bool? isRefreshing,
    bool? isBannerLoading,
    bool? isCategoriesLoading,
    bool? isFeaturedLoading,
    bool? isRecommendedLoading,
    bool? isBestSellersLoading,
    Object? pageError = unsetHomeStateValue,
    Object? bannerError = unsetHomeStateValue,
    Object? categoriesError = unsetHomeStateValue,
    Object? featuredError = unsetHomeStateValue,
    Object? recommendedError = unsetHomeStateValue,
    Object? bestSellersError = unsetHomeStateValue,
    Object? cartErrorMessage = unsetHomeStateValue,
    Object? defaultAddress = unsetHomeStateValue,
    Object? user = unsetHomeStateValue,
    CartModel? cart,
    int? unreadNotificationCount,
    List<BannerModel>? banners,
    List<HomeCategoryItem>? categories,
    List<ProductWithVariants>? featuredProducts,
    List<ProductWithVariants>? recommendedProducts,
    List<ProductWithVariants>? bestSellingProducts,
    List<ProductWithVariants>? reorderProducts,
    Set<String>? busyProductIds,
  }) {
    return HomeState(
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isBannerLoading: isBannerLoading ?? this.isBannerLoading,
      isCategoriesLoading: isCategoriesLoading ?? this.isCategoriesLoading,
      isFeaturedLoading: isFeaturedLoading ?? this.isFeaturedLoading,
      isRecommendedLoading: isRecommendedLoading ?? this.isRecommendedLoading,
      isBestSellersLoading: isBestSellersLoading ?? this.isBestSellersLoading,
      pageError:
          pageError == unsetHomeStateValue ? this.pageError : pageError as String?,
      bannerError: bannerError == unsetHomeStateValue
          ? this.bannerError
          : bannerError as String?,
      categoriesError: categoriesError == unsetHomeStateValue
          ? this.categoriesError
          : categoriesError as String?,
      featuredError: featuredError == unsetHomeStateValue
          ? this.featuredError
          : featuredError as String?,
      recommendedError: recommendedError == unsetHomeStateValue
          ? this.recommendedError
          : recommendedError as String?,
      bestSellersError: bestSellersError == unsetHomeStateValue
          ? this.bestSellersError
          : bestSellersError as String?,
      cartErrorMessage: cartErrorMessage == unsetHomeStateValue
          ? this.cartErrorMessage
          : cartErrorMessage as String?,
      defaultAddress: defaultAddress == unsetHomeStateValue
          ? this.defaultAddress
          : defaultAddress as AddressModel?,
      user: user == unsetHomeStateValue ? this.user : user as UserModel?,
      cart: cart ?? this.cart,
      unreadNotificationCount:
          unreadNotificationCount ?? this.unreadNotificationCount,
      banners: banners ?? this.banners,
      categories: categories ?? this.categories,
      featuredProducts: featuredProducts ?? this.featuredProducts,
      recommendedProducts: recommendedProducts ?? this.recommendedProducts,
      bestSellingProducts: bestSellingProducts ?? this.bestSellingProducts,
      reorderProducts: reorderProducts ?? this.reorderProducts,
      busyProductIds: busyProductIds ?? this.busyProductIds,
    );
  }
}
