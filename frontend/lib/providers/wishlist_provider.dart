import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product_variant_model.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../services/product_service.dart';

const _wishlistStorageKey = 'wishlist_product_ids';

final wishlistProvider =
    StateNotifierProvider<WishlistNotifier, List<String>>((ref) {
  return WishlistNotifier(ref.read(apiServiceProvider));
});

final wishlistProductsProvider =
    FutureProvider.autoDispose<List<ProductWithVariants>>((ref) async {
  final ids = ref.watch(wishlistProvider);
  if (ids.isEmpty) return [];

  final service = ref.read(productServiceProvider);
  final results = await Future.wait(
    ids.map((id) => service.getProductById(id)),
  );

  return results.whereType<ProductWithVariants>().toList();
});

class WishlistNotifier extends StateNotifier<List<String>> {
  WishlistNotifier(this._api) : super(const []) {
    AuthService.registerLogoutCallback(() {
      state = const [];
    });
    load();
  }

  final ApiService _api;

  Future<void> load() async {
    try {
      final res = await _api.get(ApiUserPaths.wishlist);
      final data = res.data;
      if (data is Map && data['success'] == true && data['data'] is Map) {
        final payload = Map<String, dynamic>.from(data['data'] as Map);
        final ids = (payload['productIds'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        state = ids;
        await _persistLocal(ids);
        return;
      }
    } catch (_) {}

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
    await _persistLocal(updated);
    try {
      await _api.post(
        ApiUserPaths.wishlist,
        data: {'product_id': int.tryParse(trimmed) ?? trimmed},
      );
    } catch (_) {}
  }

  Future<void> remove(String productId) async {
    if (!state.contains(productId)) return;

    final updated = state.where((id) => id != productId).toList();
    state = updated;
    await _persistLocal(updated);
    try {
      await _api.delete('${ApiUserPaths.wishlist}/$productId');
    } catch (_) {}
  }

  Future<void> toggle(String productId) async {
    if (isInWishlist(productId)) {
      await remove(productId);
    } else {
      await add(productId);
    }
  }

  Future<void> syncToServer() async {
    try {
      await _api.put(
        ApiUserPaths.wishlist,
        data: {'productIds': state.map((id) => int.tryParse(id) ?? id).toList()},
      );
    } catch (_) {}
  }

  Future<void> _persistLocal(List<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_wishlistStorageKey, ids);
    } catch (_) {}
  }
}
