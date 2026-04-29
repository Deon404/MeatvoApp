import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category_model.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';

final categoriesProvider = FutureProvider<List<CategoryModel>>((ref) async {
  return ref.read(productServiceProvider).getCategories();
});

final featuredProductsProvider = FutureProvider<List<ProductModel>>((ref) async {
  return ref.read(productServiceProvider).getProducts(limit: 12);
});

final productsByCategoryProvider =
    FutureProvider.family<List<ProductModel>, int>((ref, categoryId) async {
  return ref.read(productServiceProvider).getProducts(categoryId: categoryId, limit: 30);
});

final searchedProductsProvider =
    FutureProvider.family<List<ProductModel>, String>((ref, query) async {
  return ref.read(productServiceProvider).getProducts(search: query, limit: 30);
});

final pagedProductsProvider =
    FutureProvider.family<ProductListResponse, ProductListQuery>((ref, query) async {
  return ref.read(productServiceProvider).getProductsPaged(
        page: query.page,
        limit: query.limit,
        search: query.search,
      );
});

final productDetailProvider = FutureProvider.family<ProductModel, int>((ref, productId) async {
  return ref.read(productServiceProvider).getProductById(productId);
});

class ProductListQuery {
  final String search;
  final int page;
  final int limit;

  const ProductListQuery({
    required this.search,
    required this.page,
    this.limit = 20,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductListQuery &&
        other.search == search &&
        other.page == page &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(search, page, limit);
}
