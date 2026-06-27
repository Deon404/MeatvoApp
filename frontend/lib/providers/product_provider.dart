import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product_variant_model.dart';
import '../services/product_service.dart';

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
