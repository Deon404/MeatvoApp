import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/connectivity/error_message_mapper.dart';
import '../../models/cart_model.dart';
import '../../models/category_model.dart';
import '../../models/product_variant_model.dart';
import '../../services/cart_service.dart';
import '../../services/product_service.dart';
import 'catalog_state.dart';

class CatalogViewModel extends StateNotifier<CatalogState> {
  CatalogViewModel({
    required ProductService productService,
    required CartService cartService,
    String? initialCategory,
    int? initialCategoryId,
  })  : _productService = productService,
        _cartService = cartService,
        _currentCategoryId = initialCategoryId,
        super(CatalogState.initial(initialCategory: initialCategory));

  final ProductService _productService;
  final CartService _cartService;
  int? _currentCategoryId;

  static const _defaultCategories = ['Chicken', 'Eggs', 'Fish', 'Mutton'];

  Future<void> load({bool refresh = false, int? categoryId}) async {
    if (categoryId != null) {
      _currentCategoryId = categoryId;
    }

    state = state.copyWith(
      isLoading: !refresh && state.allProducts.isEmpty,
      isRefreshing: refresh,
      errorMessage: null,
    );

    // Fetch each piece independently so a single failure doesn't blank the
    // entire screen (the old `Future.wait` rethrew on any failure even if
    // products had already loaded, producing a silent empty state).
    List<ProductWithVariants> products;
    try {
      products = await _productService.getProducts(
        limit: 100,
        categoryId: _currentCategoryId,
        useCache: !refresh,
      );
    } catch (e, st) {
      // Keep this one — it's the only log that matters when the catalog
      // can't show anything at all.
      if (kDebugMode) {
        debugPrint('[CatalogViewModel] getProducts FAILED: $e\n$st');
      }
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: ErrorMessageMapper.userMessage(e),
      );
      return;
    }

    List<Map<String, dynamic>> categoryMaps;
    try {
      categoryMaps =
          await _productService.getAllCategories(useCache: !refresh);
    } catch (_) {
      // Non-fatal: chip strip just won't show backend categories.
      categoryMaps = const [];
    }

    CartModel cart;
    try {
      cart = await _cartService.getCart();
    } catch (_) {
      cart = state.cart;
    }

    final categories = _resolveCategories(categoryMaps, products);
    final selected = _resolveSelectedCategory(
      requested: state.selectedCategory,
      categories: categories,
      products: products,
    );

    state = state.copyWith(
      isLoading: false,
      isRefreshing: false,
      allProducts: products,
      categories: categories,
      cart: cart,
      selectedCategory: selected,
      errorMessage: null,
    );
  }

  String _resolveSelectedCategory({
    required String requested,
    required List<CategoryModel> categories,
    required List<ProductWithVariants> products,
  }) {
    bool categoryHasProducts(String categoryName) {
      final key = categoryName.trim().toLowerCase();
      return products.any(
        (item) =>
            (item.product.categoryName ?? '').trim().toLowerCase() == key,
      );
    }

    if (categoryHasProducts(requested)) return requested;

    for (final category in categories) {
      if (categoryHasProducts(category.name)) return category.name;
    }

    for (final product in products) {
      final name = product.product.categoryName?.trim();
      if (name != null && name.isNotEmpty) return name;
    }

    if (categories.isNotEmpty) return categories.first.name;
    return requested.isNotEmpty ? requested : _defaultCategories.first;
  }

  List<CategoryModel> _resolveCategories(
    List<Map<String, dynamic>> maps,
    List<ProductWithVariants> products,
  ) {
    final seen = <String>{};
    final items = <CategoryModel>[];

    for (final map in maps) {
      final model = CategoryModel.fromMap(map);
      if (model.name.isEmpty || !seen.add(model.name.toLowerCase())) continue;
      items.add(model);
    }

    if (items.isEmpty) {
      for (final name in _defaultCategories) {
        if (seen.add(name.toLowerCase())) {
          items.add(CategoryModel(id: name.toLowerCase(), name: name));
        }
      }
    }

    for (final product in products) {
      final name = product.product.categoryName?.trim();
      if (name == null || name.isEmpty || !seen.add(name.toLowerCase())) continue;
      items.add(CategoryModel(id: name.toLowerCase(), name: name));
    }

    // Sort: active categories first, then by sort order, then by default order
    items.sort((a, b) {
      // Active categories come first
      if (a.isActive != b.isActive) {
        return a.isActive ? -1 : 1;
      }

      // Then sort by sortOrder if available
      if (a.sortOrder != b.sortOrder) {
        return a.sortOrder.compareTo(b.sortOrder);
      }

      // Finally, maintain default order: Chicken, Eggs, Fish, Mutton
      final orderA = _defaultCategories.indexOf(a.name);
      final orderB = _defaultCategories.indexOf(b.name);
      if (orderA != -1 && orderB != -1) {
        return orderA.compareTo(orderB);
      }
      if (orderA != -1) return -1;
      if (orderB != -1) return 1;

      return a.name.compareTo(b.name);
    });

    return items;
  }

  void setCategory(String name) {
    final category = state.categories.firstWhere(
      (cat) => cat.name.toLowerCase() == name.toLowerCase(),
      orElse: () => CategoryModel(id: '', name: name),
    );
    
    final categoryId = int.tryParse(category.id);
    
    // Update the selected category immediately for UI feedback
    state = state.copyWith(selectedCategory: name);
    
    // Reload products with the new category ID
    if (categoryId != null) {
      load(refresh: true, categoryId: categoryId);
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query.trim().toLowerCase());
  }

  void setSort(String sort) {
    state = state.copyWith(selectedSort: sort);
  }

  Future<void> changeCartQuantity(
    ProductWithVariants product,
    int nextQuantity,
  ) async {
    final productId = product.product.id;
    if (state.busyProductIds.contains(productId)) return;

    state = state.copyWith(
      busyProductIds: {...state.busyProductIds, productId},
    );

    try {
      final variant = product.availableVariants.isNotEmpty
          ? product.availableVariants.first
          : product.variants.isNotEmpty
              ? product.variants.first
              : null;
      final existing = state.cart.findItemByProductId(productId);
      final existingItemId = existing?.itemId;

      if (existingItemId != null &&
          existingItemId.isNotEmpty &&
          nextQuantity > 0) {
        await _cartService.updateCartItem(existingItemId, nextQuantity);
      } else if (existingItemId != null &&
          existingItemId.isNotEmpty &&
          nextQuantity <= 0) {
        await _cartService.removeFromCart(existingItemId);
      } else if (nextQuantity > 0) {
        await _cartService.addToCart(
          productId,
          nextQuantity,
          unit: variant?.weight ?? product.product.unit,
          variantId: variant?.id,
        );
      }

      final cart = await _cartService.getCart().catchError((_) => state.cart);
      state = state.copyWith(cart: cart);
    } finally {
      final busy = {...state.busyProductIds}..remove(productId);
      state = state.copyWith(busyProductIds: busy);
    }
  }
}
