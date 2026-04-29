import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category_model.dart';
import '../models/product_model.dart';
import 'api_service.dart';

final productServiceProvider = Provider<ProductService>((ref) {
  return ProductService(ref);
});

class ProductService {
  final Ref _ref;
  ProductService(this._ref);

  Future<ProductListResponse> getProductsPaged({
    int page = 1,
    int limit = 20,
    int? categoryId,
    String? search,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (categoryId != null) 'categoryId': categoryId,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    };

    final response = await _ref.read(apiServiceProvider).get('/v1/products', params: query);
    final payload = response.data as Map<String, dynamic>;
    final data = (payload['data'] ?? payload) as Map<String, dynamic>;
    final list = (data['products'] ?? const <dynamic>[]) as List<dynamic>;
    final products = list.map((e) => ProductModel.fromJson(e as Map<String, dynamic>)).toList();
    return ProductListResponse(
      products: products,
      page: ((data['page'] ?? page) as num).toInt(),
      pages: ((data['pages'] ?? page) as num).toInt(),
      total: ((data['total'] ?? products.length) as num).toInt(),
    );
  }

  Future<List<CategoryModel>> getCategories() async {
    final response = await _ref.read(apiServiceProvider).get('/v1/categories');
    final payload = response.data as Map<String, dynamic>;
    final data = (payload['data'] ?? payload) as Map<String, dynamic>;
    final list = (data['categories'] ?? const <dynamic>[]) as List<dynamic>;
    return list
        .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ProductModel>> getProducts({
    int page = 1,
    int limit = 20,
    int? categoryId,
    String? search,
  }) async {
    final result = await getProductsPaged(
      page: page,
      limit: limit,
      categoryId: categoryId,
      search: search,
    );
    return result.products;
  }

  Future<ProductModel> getProductById(int id) async {
    final response = await _ref.read(apiServiceProvider).get('/v1/products/$id');
    final payload = response.data as Map<String, dynamic>;
    final data = (payload['data'] ?? payload) as Map<String, dynamic>;
    final product = (data['product'] ?? const <String, dynamic>{}) as Map<String, dynamic>;
    return ProductModel.fromJson(product);
  }
}

class ProductListResponse {
  final List<ProductModel> products;
  final int page;
  final int pages;
  final int total;

  const ProductListResponse({
    required this.products,
    required this.page,
    required this.pages,
    required this.total,
  });
}
