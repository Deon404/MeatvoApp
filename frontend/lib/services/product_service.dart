import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart' show ApiProductPaths, ApiUserPaths;
import '../models/product_model.dart';
import '../models/product_variant_model.dart';
import '../utils/media_url_resolver.dart';
import '../utils/product_unit_helper.dart';
import 'api_service.dart';
import 'cache_service.dart';

/// Product Filters
class ProductFilters {
  final String? category;
  final bool? featured;
  final List<String>? tags;
  final String? search;

  ProductFilters({
    this.category,
    this.featured,
    this.tags,
    this.search,
  });
}

/// Product service — uses custom Node.js backend
final productServiceProvider = Provider<ProductService>((ref) {
  return ProductService(ref.read(apiServiceProvider));
});

class ProductService {
  final ApiService _api;

  ProductService([ApiService? api]) : _api = api ?? ApiService();

  // ── Helpers ─────────────────────────────────────────────────────────────

  /// Extract product rows from `/api/products` style payloads (`data.products`)
  /// or legacy catalog arrays (`data` as list).
  List<dynamic> _extractProductRows(dynamic dataField) {
    if (dataField == null) return [];
    if (dataField is List) return dataField;
    if (dataField is Map) {
      final m = Map<String, dynamic>.from(dataField);
      final products = m['products'];
      if (products is List) return products;
    }
    return [];
  }

  /// Parse a raw product JSON from the backend into [ProductWithVariants].
  ProductWithVariants _parseProduct(Map<String, dynamic> json) {
    final productJson = Map<String, dynamic>.from(json);
    // IDs may be numeric from API
    if (productJson['id'] != null) {
      productJson['id'] = productJson['id'].toString();
    }
    if (productJson['category_id'] != null) {
      productJson['category_id'] = productJson['category_id'].toString();
    }
    // Normalize field names: backend may return camelCase or snake_case
    final salePrice = productJson['display_price'] ??
        productJson['base_price'] ??
        productJson['basePrice'] ??
        productJson['price'] ??
        0;
    final salePriceNum = salePrice is num
        ? salePrice.toDouble()
        : double.tryParse('$salePrice') ?? 0;
    final mrpRaw = productJson['mrp'];
    final mrp = mrpRaw is num ? mrpRaw.toDouble() : double.tryParse('$mrpRaw');
    final discountRaw = productJson['discount'];
    final discountFromApi = discountRaw is num
        ? discountRaw.toDouble()
        : double.tryParse('$discountRaw');
    if (mrp != null && mrp > salePriceNum + 0.01) {
      productJson['price'] = mrp;
      productJson['discount'] = discountFromApi ??
          ((mrp - salePriceNum) / mrp * 100).round();
    } else {
      productJson['price'] = salePriceNum;
    }

    productJson['image_url'] =
        MediaUrlResolver.resolve(productJson['image_url']?.toString());
    if (productJson['images'] is List) {
      productJson['images'] = MediaUrlResolver.resolveList(
        (productJson['images'] as List)
            .map((e) => e?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList(),
      );
    }
    if (!productJson.containsKey('is_available')) {
      productJson['is_available'] =
          productJson['is_active'] ?? productJson['isActive'] ?? true;
    }

    final product = ProductModel.fromJson(productJson);

    final rawVariants = productJson['variants'] as List?;
    List<ProductVariantModel> variants = (rawVariants ?? [])
        .map((v) {
          final variantJson = Map<String, dynamic>.from(v as Map);
          if (variantJson['id'] != null) {
            variantJson['id'] = variantJson['id'].toString();
          }
          if (variantJson['product_id'] != null) {
            variantJson['product_id'] = variantJson['product_id'].toString();
          }
          return ProductVariantModel.fromJson(variantJson);
        })
        .toList();

    if (variants.isEmpty) {
      final rawWeights =
          productJson['weight_variants'] ?? productJson['weightVariants'];
      final isPieceProduct = ProductUnitHelper.isPieceUnit(product.unit);
      if (rawWeights is List && rawWeights.isNotEmpty) {
        if (isPieceProduct &&
            ProductUnitHelper.isDefaultMeatWeightVariants(rawWeights)) {
          // Eggs etc.: admin unit is piece — ignore default gram variants.
          variants = [];
        } else if (isPieceProduct) {
          final pricePerPiece = product.finalPrice;
          variants = rawWeights.map((countRaw) {
            final count = countRaw is num
                ? countRaw.toInt()
                : int.tryParse('$countRaw') ?? 1;
            final safeCount = count > 0 ? count : 1;
            return ProductVariantModel(
              id: '${product.id}_$safeCount',
              productId: product.id,
              weight: ProductUnitHelper.pieceVariantLabel(safeCount),
              weightValue: safeCount.toDouble(),
              price: (pricePerPiece * safeCount * 100).round() / 100,
              stock: product.stock?.toInt() ?? 0,
              isAvailable: product.isAvailable,
            );
          }).toList();
        } else {
          final basePerKgRaw = productJson['base_price_per_kg'] ??
              productJson['basePricePerKg'] ??
              productJson['price'];
          final basePerKg = basePerKgRaw is num
              ? basePerKgRaw.toDouble()
              : double.tryParse('$basePerKgRaw') ?? product.price;
          variants = rawWeights.map((weightRaw) {
            final grams = weightRaw is num
                ? weightRaw.toInt()
                : int.tryParse('$weightRaw') ?? 500;
            final kgLabel = grams >= 1000
                ? '${(grams / 1000).toStringAsFixed(grams % 1000 == 0 ? 0 : 1)}kg'
                : '${grams}g';
            final variantPrice =
                (basePerKg * (grams / 1000) * 100).round() / 100;
            return ProductVariantModel(
              id: '${product.id}_$grams',
              productId: product.id,
              weight: kgLabel,
              weightValue: grams / 1000,
              price: variantPrice,
              stock: product.stock?.toInt() ?? 0,
              isAvailable: product.isAvailable,
            );
          }).toList();
        }
      }
    }

    return ProductWithVariants(product: product, variants: variants);
  }

  List<ProductWithVariants> _parseList(List<dynamic> list) =>
      list.map((e) => _parseProduct(e as Map<String, dynamic>)).toList();

  List<ProductWithVariants> _rankProductsForHome(
    List<ProductWithVariants> products, {
    String? preferredCategory,
  }) {
    final ranked = products.where((item) => item.product.name.trim().isNotEmpty).toList();

    int score(ProductWithVariants item) {
      final product = item.product;
      var total = 0;

      if (product.isAvailable) total += 40;
      if ((product.stock ?? 0) > 0) total += 20;
      if (item.availableVariants.isNotEmpty) total += 10;
      if (product.hasDiscount) total += 15;
      if ((product.imageUrl ?? product.primaryImageUrl ?? '').isNotEmpty) {
        total += 8;
      }
      if ((product.description ?? '').isNotEmpty) total += 4;
      if (preferredCategory != null &&
          (product.categoryName ?? '').toLowerCase() ==
              preferredCategory.toLowerCase()) {
        total += 6;
      }

      return total;
    }

    ranked.sort((a, b) {
      final byScore = score(b).compareTo(score(a));
      if (byScore != 0) return byScore;

      final byDiscount =
          (b.product.discount ?? 0).compareTo(a.product.discount ?? 0);
      if (byDiscount != 0) return byDiscount;

      final byPrice = a.minPrice.compareTo(b.minPrice);
      if (byPrice != 0) return byPrice;

      return a.product.name.compareTo(b.product.name);
    });

    return ranked;
  }

  bool _isRequestSuccessful(dynamic data) {
    if (data is! Map) return false;
    final map = data.cast<String, dynamic>();
    return map['success'] == true || map['ok'] == true;
  }

  dynamic _extractData(dynamic responseData) {
    if (responseData is Map) {
      return responseData['data'];
    }
    return null;
  }

  List<dynamic> _extractCategoryRows(dynamic payload) {
    if (payload is List) return payload;
    if (payload is Map) {
      final map = Map<String, dynamic>.from(payload);
      final categories = map['categories'];
      if (categories is List) return categories;
      // `/api/catalog/categories` style: data is already the array.
      if (map.containsKey('id') && map.containsKey('name')) {
        return [map];
      }
    }
    return const [];
  }

  Map<String, dynamic> _normalizeCategoryMap(dynamic raw) {
    if (raw is! Map) {
      return {'name': raw.toString(), 'id': raw.toString()};
    }
    final map = Map<String, dynamic>.from(raw);
    final image =
        map['image_url'] ?? map['imageUrl'] ?? map['icon_url'] ?? map['iconUrl'];
    if (image != null) {
      map['image_url'] = MediaUrlResolver.resolve(image.toString());
    }
    return map;
  }

  // ── Core endpoints ───────────────────────────────────────────────────────

  /// Get all products (with optional filters).
  Future<List<ProductWithVariants>> getProducts({
    int? page,
    int? limit,
    int? categoryId,
    String? search,
    bool useCache = true,
  }) async {
    final cacheKey = CacheService.generateKey('products', {
      'page': page?.toString(),
      'limit': limit?.toString(),
      'category_id': categoryId?.toString(),
      'search': search,
    });

    if (useCache) {
      final cached = CacheService.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        try {
          return _parseList(cached);
        } catch (_) {
          await CacheService.remove(cacheKey);
        }
      }
    }

    try {
      final params = <String, dynamic>{};
      if (page != null) params['page'] = page;
      if (limit != null) params['limit'] = limit;
      if (categoryId != null) params['category'] = categoryId;
      if (search != null && search.isNotEmpty) params['search'] = search;

      final res = await _api.get(
        ApiProductPaths.products,
        queryParameters: params.isEmpty ? null : params,
      );

      if (!_isRequestSuccessful(res.data)) {
        throw Exception(res.data['message'] ?? 'Failed to fetch products');
      }

      final rawList = _extractProductRows(_extractData(res.data));
      final products = _parseList(rawList);

      if (useCache) {
        await CacheService.set(cacheKey, rawList,
            ttl: const Duration(minutes: 1));
      }

      return products;
    } on DioException catch (e) {
      throw Exception(
          'Failed to fetch products: ${e.response?.data?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to fetch products: $e');
    }
  }

  /// Get all products (backward compatibility — returns only ProductModel).
  Future<List<ProductModel>> getAllProducts() async {
    final list = await getProducts();
    return list.map((p) => p.product).toList();
  }

  /// Get products by category.
  Future<List<ProductWithVariants>> getProductsByCategory(
    String category, {
    int? limit,
    int? offset,
    bool useCache = true,
  }) async {
    final parsedCategoryId = int.tryParse(category);
    if (parsedCategoryId == null) {
      final products = await getProducts(
        limit: limit == null ? 100 : limit * 4,
        useCache: useCache,
      );
      final filtered = products
          .where((product) =>
              (product.product.categoryName ?? '').toLowerCase() ==
              category.toLowerCase())
          .toList();
      final start = offset ?? 0;
      if (start >= filtered.length) {
        return [];
      }
      final end = limit == null
          ? filtered.length
          : (start + limit).clamp(0, filtered.length);
      return filtered.sublist(start, end);
    }

    final cacheKey = CacheService.generateKey('products_category', {
      'category_id': parsedCategoryId.toString(),
      'limit': limit?.toString(),
      'page': offset?.toString(),
    });

    if (useCache && offset == null) {
      final cached = CacheService.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        try {
          return _parseList(cached);
        } catch (_) {
          await CacheService.remove(cacheKey);
        }
      }
    }

    try {
      final params = <String, dynamic>{'category': parsedCategoryId};
      if (limit != null) params['limit'] = limit;
      if (offset != null) params['page'] = offset;

      final res = await _api.get(
        ApiProductPaths.products,
        queryParameters: params,
      );

      if (!_isRequestSuccessful(res.data)) {
        throw Exception(res.data['message'] ?? 'Failed to fetch products');
      }

      final rawList = _extractProductRows(_extractData(res.data));
      final products = _parseList(rawList);

      if (useCache && offset == null) {
        await CacheService.set(cacheKey, rawList,
            ttl: const Duration(minutes: 1));
      }

      return products;
    } on DioException catch (e) {
      throw Exception(
          'Failed to fetch products by category: ${e.response?.data?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to fetch products by category: $e');
    }
  }

  /// Get a single product by ID (numeric or string slug from API).
  Future<ProductWithVariants?> getProductById(String id) async {
    final trimmedId = id.trim();
    if (trimmedId.isEmpty) return null;

    try {
      final res = await _api.get('${ApiProductPaths.productById}$trimmedId');

      if (!_isRequestSuccessful(res.data)) return null;

      final data = _extractData(res.data);
      if (data is! Map) return null;
      final map = Map<String, dynamic>.from(data);
      final productPayload = map['product'];
      if (productPayload is Map<String, dynamic>) {
        return _parseProduct(productPayload);
      }
      if (map.containsKey('name') || map.containsKey('id')) {
        return _parseProduct(map);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Search products by term.
  Future<List<ProductWithVariants>> searchProducts(String searchTerm) async {
    try {
      final res = await _api.get(
        ApiProductPaths.search,
        queryParameters: {'q': searchTerm, 'search': searchTerm},
      );

      if (!_isRequestSuccessful(res.data)) {
        throw Exception(
            res.data['message'] ?? 'Failed to search products');
      }

      final rawList = _extractProductRows(_extractData(res.data));
      return _parseList(rawList);
    } on DioException catch (e) {
      throw Exception(
          'Failed to search products: ${e.response?.data?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to search products: $e');
    }
  }

  /// Get featured products.
  Future<List<ProductWithVariants>> getFeaturedProducts({
    int limit = 10,
    bool useCache = true,
    bool swallowErrors = true,
  }) async {
    try {
      final res = await _api.get('${ApiProductPaths.productById}featured');
      if (!_isRequestSuccessful(res.data)) return [];
      final rawList = _extractProductRows(_extractData(res.data));
      final featured = _parseList(rawList);
      if (featured.isNotEmpty) {
        return _rankProductsForHome(featured).take(limit).toList();
      }
    } catch (_) {}

    try {
      final products = await getProducts(limit: 20, useCache: useCache);
      return _rankProductsForHome(products).take(limit).toList();
    } catch (_) {
      if (!swallowErrors) rethrow;
      return [];
    }
  }

  /// Get categories (returns unique strings).
  Future<List<String>> getCategories({
    bool useCache = true,
    bool swallowErrors = true,
  }) async {
    const cacheKey = 'product_categories';
    if (useCache) {
      final cached = CacheService.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        return cached.map((item) => item.toString()).toList(growable: false);
      }
    }
    try {
      final res = await _api.get(ApiProductPaths.categories);
      if (!_isRequestSuccessful(res.data)) return [];

      final payload = _extractData(res.data);
      final List data = payload is Map && payload['categories'] is List
          ? (payload['categories'] as List)
          : payload is List
              ? payload
              : [];
      final categories = data
          .map((c) =>
              (c is Map ? (c['name'] ?? c['id'] ?? '') : c).toString())
          .where((s) => s.isNotEmpty)
          .toList()
          .cast<String>();
      if (useCache) {
        await CacheService.set(
          cacheKey,
          categories,
          ttl: const Duration(minutes: 5),
        );
      }
      return categories;
    } catch (_) {
      if (!swallowErrors) rethrow;
      return [];
    }
  }

  /// Get all categories — returns list of maps for backward compatibility.
  Future<List<Map<String, dynamic>>> getAllCategories({
    bool useCache = true,
    bool swallowErrors = true,
  }) async {
    const cacheKey = 'product_categories_maps';
    if (useCache) {
      final cached = CacheService.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        try {
          return cached
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false);
        } catch (_) {
          await CacheService.remove(cacheKey);
        }
      }
    }
    try {
      final res = await _api.get(ApiProductPaths.categories);
      if (!_isRequestSuccessful(res.data)) return [];

      final payload = _extractData(res.data);
      final List data = _extractCategoryRows(payload);
      final categories = data
          .map(_normalizeCategoryMap)
          .toList(growable: false);
      if (useCache) {
        await CacheService.set(
          cacheKey,
          categories,
          ttl: const Duration(minutes: 5),
        );
      }
      return categories;
    } catch (_) {
      if (!swallowErrors) rethrow;
      return [];
    }
  }

  Future<List<ProductWithVariants>> getRecommendedProducts({
    String? userId,
    int limit = 10,
    bool useCache = true,
    bool swallowErrors = true,
  }) async {
    try {
      final products = await getProducts(
        limit: limit < 12 ? 24 : limit * 2,
        useCache: useCache,
      );
      return _rankProductsForHome(products).take(limit).toList();
    } catch (_) {
      if (!swallowErrors) rethrow;
      return [];
    }
  }

  /// Fetch every active product (paginated) for the home catalog.
  Future<List<ProductWithVariants>> getAllActiveProducts({
    bool useCache = true,
    bool swallowErrors = true,
  }) async {
    try {
      final merged = <ProductWithVariants>[];
      final seenIds = <String>{};
      var page = 1;

      while (page <= 10) {
        final batch = await getProducts(
          page: page,
          limit: 100,
          useCache: useCache,
        );
        if (batch.isEmpty) break;

        for (final product in batch) {
          final id = product.product.id;
          if (seenIds.add(id)) {
            merged.add(product);
          }
        }

        if (batch.length < 100) break;
        page++;
      }

      return _rankProductsForHome(merged);
    } catch (_) {
      if (!swallowErrors) rethrow;
      return [];
    }
  }

  Future<List<ProductWithVariants>> getBestSellingProducts({
    int limit = 10,
    bool useCache = true,
    bool swallowErrors = true,
  }) async {
    try {
      final featured = await getFeaturedProducts(
        useCache: useCache,
        swallowErrors: swallowErrors,
      );
      if (featured.isNotEmpty) {
        return _rankProductsForHome(
          featured,
          preferredCategory: 'chicken',
        ).take(limit).toList();
      }

      final products = await getProducts(
        limit: limit < 12 ? 24 : limit * 2,
        useCache: useCache,
      );
      return _rankProductsForHome(
        products,
        preferredCategory: 'chicken',
      ).take(limit).toList();
    } catch (_) {
      if (!swallowErrors) rethrow;
      return [];
    }
  }

  /// Related products — fetches same category.
  Future<List<ProductWithVariants>> getRelatedProducts({
    required String productId,
    required String category,
    int limit = 6,
  }) async {
    final list = await getProductsByCategory(category, limit: limit + 1);
    return list.where((p) => p.product.id != productId).take(limit).toList();
  }

  /// Check product availability — fetches product and checks stock.
  Future<Map<String, dynamic>> checkProductAvailability(
    String productId, {
    String? variantId,
  }) async {
    try {
      final pwv = await getProductById(productId);
      if (pwv == null) return {'available': false, 'stock': 0};

      if (variantId != null) {
        final variant = pwv.variants.firstWhere(
          (v) => v.id == variantId,
          orElse: () => pwv.variants.first,
        );
        return {
          'available': variant.isAvailable && variant.stock > 0,
          'stock': variant.stock,
        };
      }

      return {
        'available': pwv.product.isAvailable,
        'stock': pwv.product.stock ?? 0,
      };
    } catch (_) {
      return {'available': false, 'stock': 0};
    }
  }

  /// Product rating from backend API.
  Future<Map<String, dynamic>> getProductRating(String productId) async {
    try {
      final res = await _api.get(ApiUserPaths.productRating(productId));
      final data = res.data;
      if (data is Map && data['success'] == true && data['data'] is Map) {
        final payload = Map<String, dynamic>.from(data['data'] as Map);
        return {
          'averageRating': (payload['averageRating'] as num?)?.toDouble() ?? 0.0,
          'reviewCount': (payload['reviewCount'] as num?)?.toInt() ?? 0,
        };
      }
    } catch (_) {}
    return {'averageRating': 0.0, 'reviewCount': 0};
  }

  /// Get banners list from public endpoint.
  Future<List<Map<String, dynamic>>> getBanners() async {
    try {
      final res = await _api.get(ApiProductPaths.banners);
      if (!_isRequestSuccessful(res.data)) return [];

      final payload = _extractData(res.data);
      final data = payload is Map && payload['banners'] is List
          ? payload['banners'] as List
          : payload is List
              ? payload
              : <dynamic>[];
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Cache helpers ─────────────────────────────────────────────────────────

  static Future<void> clearProductCache() async {
    await CacheService.clearByPrefix('products');
    await CacheService.clearByPrefix('products_category');
    await CacheService.remove('product_categories');
    await CacheService.remove('product_categories_maps');
  }

  // ── Realtime stubs (no-op in REST backend) ────────────────────────────────

  RealtimeChannel subscribeToProductUpdates({
    Function()? onProductUpdated,
    Function()? onProductInserted,
    Function()? onProductDeleted,
  }) =>
      RealtimeChannel();

  void unsubscribeFromProductUpdates() {}
}
