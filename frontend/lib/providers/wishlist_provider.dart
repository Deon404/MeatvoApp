import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product_variant_model.dart';
import '../services/product_service.dart';

const _wishlistStorageKey = 'wishlist_product_ids';

final wishlistProvider =
    StateNotifierProvider<WishlistNotifier, List<String>>((ref) {
  return WishlistNotifier()..load();
});

final wishlistProductsProvider =
    FutureProvider.autoDispose<List<ProductWithVariants>>((ref) async {
  final ids = ref.watch(wishlistProvider);
  if (ids.isEmpty) return [];

  final service = ref.read(productServiceProvider);
  final products = <ProductWithVariants>[];

  for (final id in ids) {
    final product = await service.getProductById(id);
    if (product != null) {
      products.add(product);
    }
  }

  return products;
});

class WishlistNotifier extends StateNotifier<List<String>> {
  WishlistNotifier() : super(const []);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getStringList(_wishlistStorageKey) ?? const [];
    } catch (_) {
      state = const [];
    }
  }

  bool isInWishlist(String productId) => state.contains(productId);

  Future<void> add(String productId) async {
    final trimmed = productId.trim();
    if (trimmed.isEmpty || state.contains(trimmed)) return;

    final updated = [...state, trimmed];
    state = updated;
    await _persist(updated);
  }

  Future<void> remove(String productId) async {
    if (!state.contains(productId)) return;

    final updated = state.where((id) => id != productId).toList();
    state = updated;
    await _persist(updated);
  }

  Future<void> toggle(String productId) async {
    if (isInWishlist(productId)) {
      await remove(productId);
    } else {
      await add(productId);
    }
  }

  Future<void> _persist(List<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_wishlistStorageKey, ids);
    } catch (_) {}
  }
}
