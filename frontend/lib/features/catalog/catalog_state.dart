import '../../models/cart_model.dart';
import '../../models/category_model.dart';
import '../../models/product_variant_model.dart';

const Object unsetCatalogValue = Object();

class CatalogState {
  const CatalogState({
    required this.isLoading,
    required this.isRefreshing,
    required this.errorMessage,
    required this.allProducts,
    required this.categories,
    required this.cart,
    required this.selectedCategory,
    required this.searchQuery,
    required this.selectedSort,
    required this.busyProductIds,
  });

  final bool isLoading;
  final bool isRefreshing;
  final String? errorMessage;
  final List<ProductWithVariants> allProducts;
  final List<CategoryModel> categories;
  final CartModel cart;
  final String selectedCategory;
  final String searchQuery;
  final String selectedSort;
  final Set<String> busyProductIds;

  factory CatalogState.initial({String? initialCategory}) => CatalogState(
        isLoading: true,
        isRefreshing: false,
        errorMessage: null,
        allProducts: const [],
        categories: const [],
        cart: CartModel(),
        selectedCategory: initialCategory ?? 'Chicken',
        searchQuery: '',
        selectedSort: 'All',
        busyProductIds: const {},
      );

  List<ProductWithVariants> get filteredProducts {
    // Determine the effective category. If the requested `selectedCategory`
    // has zero matching products (e.g. admin renamed the category but the
    // customer app sent the old/default name like "Chicken" or "Fish"),
    // we silently fall back to the first category that actually has
    // products — this prevents the historical "white / empty screen" bug
    // where filtering produced 0 rows.
    final hasMatch = allProducts.any(
      (p) => _matchesCategory(p, selectedCategory),
    );
    final effectiveCategory = hasMatch
        ? selectedCategory
        : (_firstCategoryWithProducts() ?? selectedCategory);

    var products = allProducts.where((product) {
      if (!_matchesCategory(product, effectiveCategory)) return false;

      if (searchQuery.isNotEmpty) {
        final name = product.product.name.toLowerCase();
        final description = (product.product.description ?? '').toLowerCase();
        if (!name.contains(searchQuery) && !description.contains(searchQuery)) {
          return false;
        }
      }

      switch (selectedSort) {
        case 'Offers':
          return product.product.hasDiscount;
        case 'In Stock':
          return _canAdd(product);
        default:
          return true;
      }
    }).toList();

    switch (selectedSort) {
      case 'Price ↑':
        products.sort((a, b) => a.minPrice.compareTo(b.minPrice));
        break;
      case 'Weight':
        products.sort(
          (a, b) => _weightScore(a).compareTo(_weightScore(b)),
        );
        break;
      default:
        products.sort((a, b) => a.product.name.compareTo(b.product.name));
        break;
    }

    return products;
  }

  bool _matchesCategory(ProductWithVariants product, String categoryName) {
    return (product.product.categoryName ?? '').trim().toLowerCase() ==
        categoryName.toLowerCase();
  }

  /// Used by [filteredProducts] when the requested category has zero matches —
  /// returns the first category name that DOES have products, so the user
  /// always sees something instead of a blank screen.
  String? _firstCategoryWithProducts() {
    for (final category in categories) {
      final hasAny = allProducts.any((p) => _matchesCategory(p, category.name));
      if (hasAny) return category.name;
    }
    for (final product in allProducts) {
      final name = product.product.categoryName?.trim();
      if (name != null && name.isNotEmpty) return name;
    }
    return null;
  }

  double _weightScore(ProductWithVariants product) {
    if (product.availableVariants.isNotEmpty) {
      return product.availableVariants.first.weightValue;
    }
    if (product.variants.isNotEmpty) {
      return product.variants.first.weightValue;
    }
    return 0;
  }

  static bool _canAdd(ProductWithVariants product) {
    final variant = product.availableVariants.isNotEmpty
        ? product.availableVariants.first
        : product.variants.isNotEmpty
            ? product.variants.first
            : null;
    if (!product.product.isAvailable) return false;
    if (variant != null) return variant.isAvailable && variant.stock > 0;
    return (product.product.stock ?? 1) > 0;
  }

  CatalogState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    Object? errorMessage = unsetCatalogValue,
    List<ProductWithVariants>? allProducts,
    List<CategoryModel>? categories,
    CartModel? cart,
    String? selectedCategory,
    String? searchQuery,
    String? selectedSort,
    Set<String>? busyProductIds,
  }) {
    return CatalogState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: errorMessage == unsetCatalogValue
          ? this.errorMessage
          : errorMessage as String?,
      allProducts: allProducts ?? this.allProducts,
      categories: categories ?? this.categories,
      cart: cart ?? this.cart,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedSort: selectedSort ?? this.selectedSort,
      busyProductIds: busyProductIds ?? this.busyProductIds,
    );
  }
}
