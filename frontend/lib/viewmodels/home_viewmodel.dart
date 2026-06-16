import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/home_strings.dart';
import '../features/connectivity/error_message_mapper.dart';
import '../models/address_model.dart';
import '../constants/category_images.dart';
import '../models/category_model.dart';
import '../models/home_category_item.dart';
import '../models/product_variant_model.dart';
import '../models/user_model.dart';
import '../services/address_service.dart';
import '../services/auth_service.dart';
import '../services/banner_service.dart';
import '../services/cart_service.dart';
import '../services/notification_service.dart';
import '../services/product_service.dart';
import 'home_state.dart';

export 'home_state.dart';

class HomeViewModel extends StateNotifier<HomeState> {
  final ProductService _productService;
  final CartService _cartService;
  final AddressService _addressService;
  final AuthService _authService;
  final BannerService _bannerService;
  final NotificationService _notificationService;
  bool _initialized = false;

  HomeViewModel({
    required ProductService productService,
    required CartService cartService,
    required AddressService addressService,
    required AuthService authService,
    required BannerService bannerService,
    required NotificationService notificationService,
  })  : _productService = productService,
        _cartService = cartService,
        _addressService = addressService,
        _authService = authService,
        _bannerService = bannerService,
        _notificationService = notificationService,
        super(HomeState.initial());

  Future<void> initialize() async {
    if (_initialized && !state.isInitialLoading) return;
    _initialized = true;
    await loadHome();
  }

  Future<void> loadHome({bool forceRefresh = false}) async {
    if (forceRefresh) {
      await ProductService.clearProductCache();
      await BannerService.clearBannerCache();
    }

    final showFullLoader = !state.hasContent;
    state = state.copyWith(
      isInitialLoading: showFullLoader,
      isRefreshing: !showFullLoader,
      pageError: null,
      isBannerLoading: state.banners.isEmpty,
      isCategoriesLoading: state.categories.isEmpty,
      isFeaturedLoading: state.featuredProducts.isEmpty,
      isRecommendedLoading: state.recommendedProducts.isEmpty,
      isBestSellersLoading: state.bestSellingProducts.isEmpty,
    );

    await Future.wait([
      _loadHeaderData(),
      _loadBanners(forceRefresh: forceRefresh),
      fetchCategories(forceRefresh: forceRefresh),
      fetchFeaturedProducts(forceRefresh: forceRefresh),
      fetchBestSellers(forceRefresh: forceRefresh),
      refreshCart(),
    ]);

    if (state.categories.isEmpty) {
      final fallback = _deriveCategories(
        state.featuredProducts,
      );
      if (fallback.isNotEmpty) {
        state = state.copyWith(categories: fallback);
      }
    }

    String? pageError;
    if (!state.hasContent) {
      final errors = [
        state.categoriesError,
        state.featuredError,
      ].whereType<String>().toList(growable: false);
      pageError = errors.isNotEmpty ? errors.first : HomeStrings.genericHomeLoadError;
    }

    state = state.copyWith(
      isInitialLoading: false,
      isRefreshing: false,
      pageError: pageError,
    );
  }

  Future<void> refresh() => loadHome(forceRefresh: true);

  Future<void> handleResume() => refresh();

  Future<void> fetchCategories({bool forceRefresh = false}) async {
    state = state.copyWith(isCategoriesLoading: true, categoriesError: null);
    try {
      final rawCategories = await _productService.getAllCategories(
        useCache: !forceRefresh,
        swallowErrors: false,
      );
      state = state.copyWith(
        categories: _normalizeCategories(rawCategories),
        isCategoriesLoading: false,
      );
    } catch (error) {
      state = state.copyWith(
        isCategoriesLoading: false,
        categoriesError: _friendlyError(error, HomeStrings.categoriesLoadError),
      );
    }
  }

  Future<void> fetchFeaturedProducts({bool forceRefresh = false}) async {
    state = state.copyWith(
      isFeaturedLoading: true,
      isRecommendedLoading: true,
      featuredError: null,
      recommendedError: null,
    );
    try {
      final products = await _productService.getFeaturedProducts(
        limit: 10,
        useCache: !forceRefresh,
        swallowErrors: false,
      );
      state = state.copyWith(
        featuredProducts: products,
        recommendedProducts: products,
        reorderProducts: products.take(3).toList(growable: false),
        isFeaturedLoading: false,
        isRecommendedLoading: false,
      );
    } catch (error) {
      state = state.copyWith(
        isFeaturedLoading: false,
        isRecommendedLoading: false,
        isBestSellersLoading: false,
        featuredError: _friendlyError(error, HomeStrings.featuredLoadError),
        recommendedError: _friendlyError(error, HomeStrings.featuredLoadError),
      );
    }
  }

  Future<void> fetchRecommended({bool forceRefresh = false}) =>
      fetchFeaturedProducts(forceRefresh: forceRefresh);

  Future<void> fetchBestSellers({bool forceRefresh = false}) async {
    state = state.copyWith(
      isBestSellersLoading: true,
      bestSellersError: null,
    );
    try {
      final products = await _productService.getBestSellingProducts(
        limit: 10,
        useCache: !forceRefresh,
        swallowErrors: false,
      );
      state = state.copyWith(
        bestSellingProducts: products,
        isBestSellersLoading: false,
      );
    } catch (error) {
      state = state.copyWith(
        isBestSellersLoading: false,
        bestSellersError:
            _friendlyError(error, HomeStrings.popularLoadError),
      );
    }
  }

  Future<void> refreshCart() async {
    try {
      final cart = await _cartService.getCart();
      state = state.copyWith(cart: cart);
    } catch (_) {}
  }

  Future<void> changeCartQuantity(
    ProductWithVariants product,
    int nextQuantity,
  ) async {
    final productId = product.product.id;
    if (state.busyProductIds.contains(productId)) return;
    if (nextQuantity > 0 && !_canAddProduct(product)) return;

    final busyIds = {...state.busyProductIds, productId};
    state = state.copyWith(busyProductIds: busyIds);

    try {
      final cartItem = state.cart.findItemByProductId(productId);
      final variant = _preferredVariant(product);
      if (cartItem == null && nextQuantity > 0) {
        await _cartService.addToCart(
          productId,
          nextQuantity,
          unit: variant?.weight ?? product.product.unit,
          variantId: variant?.id,
        );
      } else if (cartItem != null && nextQuantity > 0) {
        await _cartService.updateCartItem(
          cartItem.itemId ?? cartItem.productId,
          nextQuantity,
        );
      } else if (cartItem != null) {
        await _cartService.removeFromCart(cartItem.itemId ?? cartItem.productId);
      }
      await refreshCart();
    } catch (error) {
      state = state.copyWith(
        cartErrorMessage: HomeStrings.cartUpdateFailed(error),
      );
    } finally {
      final nextBusyIds = {...state.busyProductIds}..remove(productId);
      state = state.copyWith(busyProductIds: nextBusyIds);
    }
  }

  void clearCartError() {
    state = state.copyWith(cartErrorMessage: null);
  }

  Future<void> _loadHeaderData() async {
    try {
      final results = await Future.wait<dynamic>([
        _addressService.getDefaultAddress(),
        _authService.getCurrentUserProfile(),
        _notificationService.getUnreadCount(),
      ]);
      state = state.copyWith(
        defaultAddress: results[0] as AddressModel?,
        user: results[1] as UserModel?,
        unreadNotificationCount: results[2] as int,
      );
    } catch (_) {}
  }

  Future<void> _loadBanners({bool forceRefresh = false}) async {
    state = state.copyWith(isBannerLoading: true, bannerError: null);
    final banners = await _bannerService.getActiveBanners(
      useCache: !forceRefresh,
    );
    state = state.copyWith(banners: banners, isBannerLoading: false);
  }

  List<HomeCategoryItem> _normalizeCategories(
    List<Map<String, dynamic>> rawCategories,
  ) {
    final seen = <String>{};
    return rawCategories
        .map((item) {
          final name =
              (item['name'] ?? item['title'] ?? item['id'] ?? '').toString().trim();
          if (name.isEmpty) return null;
          final key = name.toLowerCase();
          if (!seen.add(key)) return null;
          final id = (item['id'] ?? item['slug'] ?? name).toString();
          final model = CategoryModel.fromMap(item);
          return HomeCategoryItem(
            id: id,
            name: name,
            imageUrl: CategoryImages.resolveUrl(model.imageUrl, name),
            productCount: model.productCount,
          );
        })
        .whereType<HomeCategoryItem>()
        .take(8)
        .toList(growable: false);
  }

  List<HomeCategoryItem> _deriveCategories(List<ProductWithVariants> products) {
    final seen = <String>{};
    final items = <HomeCategoryItem>[];
    for (final product in products) {
      final name = product.product.categoryName?.trim();
      if (name == null || name.isEmpty || !seen.add(name.toLowerCase())) continue;
      items.add(HomeCategoryItem(id: name.toLowerCase(), name: name));
    }
    return items;
  }

  ProductVariantModel? _preferredVariant(ProductWithVariants product) {
    if (product.availableVariants.isNotEmpty) return product.availableVariants.first;
    if (product.variants.isNotEmpty) return product.variants.first;
    return null;
  }

  bool _canAddProduct(ProductWithVariants product) {
    final variant = _preferredVariant(product);
    if (!product.product.isAvailable) return false;
    if (variant != null) return variant.isAvailable && variant.stock > 0;
    return (product.product.stock ?? 1) > 0;
  }

  String _friendlyError(Object error, String fallback) {
    return ErrorMessageMapper.userMessage(error, fallback: fallback);
  }
}
