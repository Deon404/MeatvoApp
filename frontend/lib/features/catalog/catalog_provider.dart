import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/cart_service.dart';
import '../../services/product_service.dart';
import 'catalog_state.dart';
import 'catalog_viewmodel.dart';

typedef CatalogProviderKey = ({String? categoryName, int? categoryId});

final catalogViewModelProvider =
    StateNotifierProvider.autoDispose.family<CatalogViewModel, CatalogState,
        CatalogProviderKey>((ref, key) {
  final vm = CatalogViewModel(
    productService: ProductService(),
    cartService: CartService(),
    initialCategory: key.categoryName,
    initialCategoryId: key.categoryId,
  );
  ref.onDispose(vm.dispose);
  vm.load();
  return vm;
});
