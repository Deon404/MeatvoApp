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
import '../services/cart_sync_subscription.dart';
import '../services/delivery_service.dart';
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
  late final CartSyncSubscription _cartSync;

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
        super(HomeState.initial()) {
    _cartSync = CartSyncSubscription((cart) {
      state = state.copyWith(cart: cart);
    });
  }

  Future<void> initialize() async {
    if (_initialized && !state.isInitialLoading) {
      await refreshCart();
      return;
    }
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
      isAllProductsLoading: state.allProducts.isEmpty,
    );

    await Future.wait([
      _loadHeaderData(),
      _loadBanners(forceRefresh: forceRefresh),
      fetchCategories(forceRefresh: forceRefresh),
      fetchAllProducts(forceRefresh: forceRefresh),
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
        state.allProductsError,
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

  Future<void> fetchAllProducts({bool forceRefresh = false}) async {
    state = state.copyWith(
      isAllProductsLoading: true,
      isFeaturedLoading: state.featuredProducts.isEmpty,
      isRecommendedLoading: state.recommendedProducts.isEmpty,
      isBestSellersLoading: state.bestSellingProducts.isEmpty,
      allProductsError: null,
      featuredError: null,
      recommendedError: null,
      bestSellersError: null,
    );

    try {
      final products = await _productService.getAllActiveProducts(
        useCache: !forceRefresh,
        swallowErrors: false,
      );
      final bestSellers = products.take(10).toList(growable: false);
      final featured = products.length > 10
          ? products.skip(10).take(10).toList(growable: false)
          : products.take(10).toList(growable: false);

      state = state.copyWith(
        allProducts: products,
        categoryProductSections: _groupProductsByCategory(products),
        bestSellingProducts: bestSellers,
        featuredProducts: featured,
        recommendedProducts: featured,
        reorderProducts: products.take(3).toList(growable: false),
        isAllProductsLoading: false,
        isFeaturedLoading: false,
        isRecommendedLoading: false,
        isBestSellersLoading: false,
      );
    } catch (error) {
      final message = _friendlyError(error, HomeStrings.allProductsLoadError);
      state = state.copyWith(
        isAllProductsLoading: false,
        isFeaturedLoading: false,
        isRecommendedLoading: false,
        isBestSellersLoading: false,
        allProductsError: message,
        featuredError: message,
        recommendedError: message,
        bestSellersError: message,
      );
    }
  }

  Future<void> fetchFeaturedProducts({bool forceRefresh = false}) async {
    if (state.allProducts.isNotEmpty) return;
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
    if (state.allProducts.isNotEmpty) return;
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
    if (nextQuantity > 0 && !_canAddProduct(product)) return;

    final cartItem = state.cart.findItemByProductId(productId);
    final variant = _preferredVariant(product);
    final optimisticCart = _cartService.buildOptimisticCart(
      current: state.cart,
      product: product.product,
      productId: productId,
      nextQuantity: nextQuantity,
      variantId: variant?.id,
      variantPrice: variant?.price,
      unit: variant?.weight ?? product.product.unit,
    );
    _cartService.applyOptimisticCart(optimisticCart);
    state = state.copyWith(cart: optimisticCart, cartErrorMessage: null);

    try {
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
      await refreshCart();
      state = state.copyWith(
        cartErrorMessage: HomeStrings.cartUpdateFailed(error),
      );
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
      final address = results[0] as AddressModel?;
      bool? serviceable;
      if (address?.latitude != null && address?.longitude != null) {
        final validation = await DeliveryService().validateDeliveryAddress(
          latitude: address!.latitude!,
          longitude: address.longitude!,
        );
        serviceable = validation.isValid;
      }
      state = state.copyWith(
        defaultAddress: address,
        user: results[1] as UserModel?,
        unreadNotificationCount: results[2] as int,
        isDeliveryServiceable: serviceable,
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

  List<HomeCategoryProducts> _groupProductsByCategory(
    List<ProductWithVariants> products,
  ) {
    if (products.isEmpty) return const [];

    final grouped = <String, List<ProductWithVariants>>{};
    for (final product in products) {
      final categoryName = product.product.categoryName?.trim();
      final key = categoryName == null || categoryName.isEmpty
          ? 'More Products'
          : categoryName;
      grouped.putIfAbsent(key, () => []).add(product);
    }

    final orderedNames = <String>[];
    for (final category in state.categories) {
      final name = category.name.trim();
      if (name.isEmpty || !grouped.containsKey(name)) continue;
      orderedNames.add(name);
    }

    for (final name in grouped.keys) {
      if (!orderedNames.contains(name)) {
        orderedNames.add(name);
      }
    }

    return orderedNames
        .map((name) {
          final items = grouped[name];
          if (items == null || items.isEmpty) return null;
          return HomeCategoryProducts(
            category: _categoryItemForName(name),
            products: items,
          );
        })
        .whereType<HomeCategoryProducts>()
        .toList(growable: false);
  }

  HomeCategoryItem _categoryItemForName(String name) {
    for (final category in state.categories) {
      if (category.name.toLowerCase() == name.toLowerCase()) {
        return category;
      }
    }
    return HomeCategoryItem(id: name.toLowerCase(), name: name);
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

  @override
  void dispose() {
    _cartSync.dispose();
    super.dispose();
  }
}
