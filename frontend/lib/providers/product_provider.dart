import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/api_config.dart';
import '../constants/home_strings.dart';
import '../models/address_model.dart';
import '../models/banner_model.dart';
import '../models/cart_model.dart';
import '../models/category_model.dart';
import '../models/home_category_item.dart';
import '../models/product_variant_model.dart';
import '../models/user_model.dart';
import 'product_state.dart';
import '../services/address_service.dart';
import '../services/auth_service.dart';
import '../services/banner_service.dart';
import '../services/cart_service.dart';
import '../services/notification_service.dart';
import '../services/product_service.dart';

final productProvider =
    StateNotifierProvider<ProductNotifier, ProductState>((ref) {
  return ProductNotifier(
    productService: ref.read(productServiceProvider),
    cartService: ref.read(cartServiceProvider),
    addressService: AddressService(),
    authService: AuthService(),
    bannerService: BannerService(),
    notificationService: NotificationService(),
  )..initialize();
});

class ProductNotifier extends StateNotifier<ProductState> {
  ProductNotifier({
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
        super(ProductState.initial());

  final ProductService _productService;
  final CartService _cartService;
  final AddressService _addressService;
  final AuthService _authService;
  final BannerService _bannerService;
  final NotificationService _notificationService;

  bool _initialized = false;
  Timer? _searchDebounce;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await loadHome();
  }

  Future<void> loadHome({bool forceRefresh = false}) async {
    if (forceRefresh) {
      await Future.wait([
        ProductService.clearProductCache(),
        BannerService.clearBannerCache(),
      ]);
    }

    state = state.copyWith(
      isLoading: !state.hasContent,
      isRefreshing: state.hasContent,
      error: null,
      cartError: null,
    );

    try {
      final results = await Future.wait<dynamic>([
        _bannerService.getActiveBanners(useCache: !forceRefresh),
        _productService.getAllCategories(
          useCache: !forceRefresh,
          swallowErrors: false,
        ),
        _productService.getFeaturedProducts(
          useCache: !forceRefresh,
          swallowErrors: false,
        ),
        _productService.getBestSellingProducts(
          limit: 8,
          useCache: !forceRefresh,
          swallowErrors: false,
        ),
        _addressService.getDefaultAddress(),
        _authService.getCurrentUserProfile(),
        _notificationService.getUnreadCount(),
        _cartService.getCart().catchError((_) => CartModel()),
      ]);

      final categories = _normalizeCategories(
        results[1] as List<Map<String, dynamic>>,
      );
      final featured = (results[2] as List<ProductWithVariants>).take(8).toList();
      final deals = (results[3] as List<ProductWithVariants>).take(8).toList();

      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        banners: results[0] as List<BannerModel>,
        categories: categories.isNotEmpty
            ? categories
            : _deriveCategories([...featured, ...deals]),
        featuredProducts: featured,
        dealProducts: deals,
        defaultAddress: results[4] as AddressModel?,
        user: results[5] as UserModel?,
        unreadNotificationCount: results[6] as int,
        cart: results[7] as CartModel,
        error: null,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        error: _friendlyError(error, HomeStrings.genericHomeLoadError),
      );
    }
  }

  Future<void> refresh() => loadHome(forceRefresh: true);

  Future<void> refreshCart() async {
    try {
      final cart = await _cartService.getCart();
      state = state.copyWith(cart: cart, cartError: null);
    } catch (_) {}
  }

  void searchProducts(String query) {
    _searchDebounce?.cancel();
    state = state.copyWith(
      searchQuery: query,
      isSearching: query.trim().isNotEmpty,
      error: null,
    );

    if (query.trim().isEmpty) {
      state = state.copyWith(
        isSearching: false,
        searchResults: const [],
      );
      return;
    }

    _searchDebounce = Timer(ApiConfig.searchDebounce, () async {
      try {
        final results = await _productService.searchProducts(query.trim());
        if (state.searchQuery != query) return;
        state = state.copyWith(
          isSearching: false,
          searchResults: results,
        );
      } catch (error) {
        if (state.searchQuery != query) return;
        state = state.copyWith(
          isSearching: false,
          error: _friendlyError(error, 'Could not load search results.'),
        );
      }
    });
  }

  Future<void> changeCartQuantity(
    ProductWithVariants product,
    int nextQuantity,
  ) async {
    final productId = product.product.id;
    final existingCartItem = state.cart.findItemByProductId(productId);
    if (nextQuantity > 0 && !_canAddProduct(product)) return;

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
    state = state.copyWith(
      cart: optimisticCart,
      cartError: null,
    );

    try {
      if (existingCartItem == null && nextQuantity > 0) {
        await _cartService.addToCart(
          productId,
          nextQuantity,
          unit: variant?.weight ?? product.product.unit,
          variantId: variant?.id,
        );
      } else if (existingCartItem != null && nextQuantity > 0) {
        await _cartService.updateCartItem(
          existingCartItem.itemId ?? existingCartItem.productId,
          nextQuantity,
        );
      } else if (existingCartItem != null) {
        await _cartService.removeFromCart(
          existingCartItem.itemId ?? existingCartItem.productId,
        );
      }
      await refreshCart();
    } catch (error) {
      await refreshCart();
      state = state.copyWith(
        cartError: HomeStrings.cartUpdateFailed(error),
      );
    }
  }

  void clearCartError() {
    state = state.copyWith(cartError: null);
  }

  List<HomeCategoryItem> _normalizeCategories(
    List<Map<String, dynamic>> rawCategories,
  ) {
    final seen = <String>{};
    return rawCategories
        .map((item) {
          final name =
              (item['name'] ?? item['title'] ?? item['id'] ?? '').toString().trim();
          if (name.isEmpty || !seen.add(name.toLowerCase())) return null;
          final id = (item['id'] ?? item['slug'] ?? name).toString();
          final model = CategoryModel.fromMap(item);
          return HomeCategoryItem(
            id: id,
            name: name,
            imageUrl: model.imageUrl,
            productCount: model.productCount,
          );
        })
        .whereType<HomeCategoryItem>()
        .take(8)
        .toList(growable: false);
  }

  List<HomeCategoryItem> _deriveCategories(List<ProductWithVariants> products) {
    final seen = <String>{};
    final categories = <HomeCategoryItem>[];
    for (final product in products) {
      final name = product.product.categoryName?.trim();
      if (name == null || name.isEmpty || !seen.add(name.toLowerCase())) {
        continue;
      }
      categories.add(HomeCategoryItem(id: name.toLowerCase(), name: name));
    }
    return categories;
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
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    return message.isEmpty ? fallback : message;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}

/// Loads a single product for [ProductDetailScreen].
final productDetailProvider =
    FutureProvider.autoDispose.family<ProductWithVariants?, String>(
  (ref, productId) async {
    final trimmedId = productId.trim();
    if (trimmedId.isEmpty) {
      throw Exception('Invalid product id');
    }

    return ref.read(productServiceProvider).getProductById(trimmedId);
  },
);
