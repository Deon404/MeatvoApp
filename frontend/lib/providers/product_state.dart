import '../models/address_model.dart';
import '../models/banner_model.dart';
import '../models/cart_model.dart';
import '../models/home_category_item.dart';
import '../models/product_variant_model.dart';
import '../models/user_model.dart';

class ProductState {
  const ProductState({
    required this.isLoading,
    required this.isRefreshing,
    required this.isSearching,
    required this.error,
    required this.searchQuery,
    required this.defaultAddress,
    required this.user,
    required this.unreadNotificationCount,
    required this.cart,
    required this.banners,
    required this.categories,
    required this.featuredProducts,
    required this.dealProducts,
    required this.searchResults,
    required this.busyProductIds,
    required this.cartError,
  });

  factory ProductState.initial() => ProductState(
        isLoading: true,
        isRefreshing: false,
        isSearching: false,
        error: null,
        searchQuery: '',
        defaultAddress: null,
        user: null,
        unreadNotificationCount: 0,
        cart: CartModel(),
        banners: const [],
        categories: const [],
        featuredProducts: const [],
        dealProducts: const [],
        searchResults: const [],
        busyProductIds: const <String>{},
        cartError: null,
      );

  final bool isLoading;
  final bool isRefreshing;
  final bool isSearching;
  final String? error;
  final String searchQuery;
  final AddressModel? defaultAddress;
  final UserModel? user;
  final int unreadNotificationCount;
  final CartModel cart;
  final List<BannerModel> banners;
  final List<HomeCategoryItem> categories;
  final List<ProductWithVariants> featuredProducts;
  final List<ProductWithVariants> dealProducts;
  final List<ProductWithVariants> searchResults;
  final Set<String> busyProductIds;
  final String? cartError;

  bool get hasContent =>
      banners.isNotEmpty ||
      categories.isNotEmpty ||
      featuredProducts.isNotEmpty ||
      dealProducts.isNotEmpty;

  ProductState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    bool? isSearching,
    Object? error = _sentinel,
    String? searchQuery,
    Object? defaultAddress = _sentinel,
    Object? user = _sentinel,
    int? unreadNotificationCount,
    CartModel? cart,
    List<BannerModel>? banners,
    List<HomeCategoryItem>? categories,
    List<ProductWithVariants>? featuredProducts,
    List<ProductWithVariants>? dealProducts,
    List<ProductWithVariants>? searchResults,
    Set<String>? busyProductIds,
    Object? cartError = _sentinel,
  }) {
    return ProductState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSearching: isSearching ?? this.isSearching,
      error: identical(error, _sentinel) ? this.error : error as String?,
      searchQuery: searchQuery ?? this.searchQuery,
      defaultAddress: identical(defaultAddress, _sentinel)
          ? this.defaultAddress
          : defaultAddress as AddressModel?,
      user: identical(user, _sentinel) ? this.user : user as UserModel?,
      unreadNotificationCount:
          unreadNotificationCount ?? this.unreadNotificationCount,
      cart: cart ?? this.cart,
      banners: banners ?? this.banners,
      categories: categories ?? this.categories,
      featuredProducts: featuredProducts ?? this.featuredProducts,
      dealProducts: dealProducts ?? this.dealProducts,
      searchResults: searchResults ?? this.searchResults,
      busyProductIds: busyProductIds ?? this.busyProductIds,
      cartError:
          identical(cartError, _sentinel) ? this.cartError : cartError as String?,
    );
  }
}

const Object _sentinel = Object();
