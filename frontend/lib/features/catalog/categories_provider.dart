import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/category_images.dart';
import '../../models/category_model.dart';
import '../../services/cache_service.dart';
import '../../services/product_service.dart';

const _defaultCategoryNames = ['Chicken', 'Mutton', 'Fish', 'Eggs'];

/// Fetches category list for [CategoriesListScreen].
/// Kept alive (non–auto-dispose) so the Categories tab does not flash blank on revisit.
final categoriesProvider = FutureProvider<List<CategoryModel>>((ref) async {
  final productService = ref.watch(productServiceProvider);

  try {
    final maps = await productService
        .getAllCategories(swallowErrors: false)
        .timeout(const Duration(seconds: 12));
    return _withDefaultImages(_resolveCategories(maps));
  } on DioException catch (e) {
    final code = e.response?.statusCode;
    if (code != null && code >= 500) rethrow;
    return _withDefaultImages(_defaultCategories());
  } on Object {
    return _withDefaultImages(_defaultCategories());
  }
});

Future<void> refreshCategoriesCache() async {
  await CacheService.remove('product_categories_maps');
  await CacheService.remove('product_categories');
}

List<CategoryModel> _defaultCategories() {
  return _defaultCategoryNames
      .map(
        (name) => CategoryModel(
          id: name.toLowerCase(),
          name: name,
          imageUrl: CategoryImages.urlForName(name),
        ),
      )
      .toList(growable: false);
}

List<CategoryModel> _resolveCategories(List<Map<String, dynamic>> maps) {
  final seen = <String>{};
  final items = <CategoryModel>[];

  for (final map in maps) {
    final model = CategoryModel.fromMap(map);
    if (model.name.isEmpty || !seen.add(model.name.toLowerCase())) continue;
    items.add(model);
  }

  if (items.isEmpty) {
    return _defaultCategories();
  }

  return items;
}

List<CategoryModel> _withDefaultImages(List<CategoryModel> categories) {
  return categories
      .map(
        (c) => CategoryModel(
          id: c.id,
          name: c.name,
          imageUrl: CategoryImages.resolveUrl(c.imageUrl, c.name),
          productCount: c.productCount,
        ),
      )
      .toList(growable: false);
}
