import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cart_item_model.dart';
import '../models/product_model.dart';

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItemModel>>((ref) {
  return CartNotifier()..load();
});

class CartNotifier extends StateNotifier<List<CartItemModel>> {
  CartNotifier() : super(const []);

  static const _cartKey = 'customer_cart_items';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cartKey);
    if (raw == null || raw.isEmpty) return;
    final list = (jsonDecode(raw) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(_fromMap)
        .toList();
    state = list;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = state.map(_toMap).toList();
    await prefs.setString(_cartKey, jsonEncode(payload));
  }

  void add(ProductModel product, {int quantity = 1, int? weight}) {
    final selectedWeight = weight ?? (product.weightVariants.isNotEmpty ? product.weightVariants.first : 500);
    final index = state.indexWhere((e) => e.product.id == product.id && e.weight == selectedWeight);
    if (index == -1) {
      state = [...state, CartItemModel(product: product, quantity: quantity, weight: selectedWeight)];
    } else {
      final existing = state[index];
      final updated = existing.copyWith(quantity: existing.quantity + quantity);
      final next = [...state];
      next[index] = updated;
      state = next;
    }
    _save();
  }

  void updateQuantity(ProductModel product, int weight, int quantity) {
    final index = state.indexWhere((e) => e.product.id == product.id && e.weight == weight);
    if (index == -1) return;
    if (quantity <= 0) {
      remove(product, weight);
      return;
    }
    final next = [...state];
    next[index] = next[index].copyWith(quantity: quantity);
    state = next;
    _save();
  }

  void remove(ProductModel product, int weight) {
    state = state.where((e) => !(e.product.id == product.id && e.weight == weight)).toList();
    _save();
  }

  void clear() {
    state = const [];
    _save();
  }

  int get itemCount => state.fold(0, (sum, e) => sum + e.quantity);
  double get total => state.fold(0, (sum, e) => sum + e.total);

  static Map<String, dynamic> _toMap(CartItemModel item) {
    return {
      'product': {
        'id': item.product.id,
        'name': item.product.name,
        'description': item.product.description,
        'category_id': item.product.categoryId,
        'category_name': item.product.categoryName,
        'price': item.product.price,
        'image_url': item.product.imageUrl,
        'stock': item.product.stock,
        'weight_variants': item.product.weightVariants,
      },
      'quantity': item.quantity,
      'weight': item.weight,
    };
  }

  static CartItemModel _fromMap(Map<String, dynamic> map) {
    final product = ProductModel.fromJson((map['product'] ?? const <String, dynamic>{}) as Map<String, dynamic>);
    return CartItemModel(
      product: product,
      quantity: (map['quantity'] as num).toInt(),
      weight: (map['weight'] as num).toInt(),
    );
  }
}
