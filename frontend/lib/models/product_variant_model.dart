import 'product_model.dart';
import '../utils/product_unit_helper.dart';

/// Product Variant Model - Different weight/price options for products
class ProductVariantModel {
  final String id;
  final String productId;
  final String weight; // e.g., "500g", "1kg", "2kg"
  final double weightValue; // Numeric value for calculations
  final double price;
  final int stock;
  final bool isAvailable;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ProductVariantModel({
    required this.id,
    required this.productId,
    required this.weight,
    required this.weightValue,
    required this.price,
    this.stock = 0,
    this.isAvailable = true,
    this.createdAt,
    this.updatedAt,
  });

  /// Hardened parser — never throws. A malformed variant row from the
  /// admin dashboard cannot blank out the product detail screen.
  factory ProductVariantModel.fromJson(Map<String, dynamic> json) {
    double parseDouble(Object? v, double fallback) {
      if (v == null) return fallback;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.trim()) ?? fallback;
      return fallback;
    }

    int parseInt(Object? v, int fallback) {
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v.trim()) ?? fallback;
      return fallback;
    }

    bool parseBool(Object? v, bool fallback) {
      if (v == null) return fallback;
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final s = v.trim().toLowerCase();
        if (s == 'true' || s == '1' || s == 'yes') return true;
        if (s == 'false' || s == '0' || s == 'no') return false;
      }
      return fallback;
    }

    DateTime? parseDate(Object? v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    return ProductVariantModel(
      id: (json['id'] ?? '').toString(),
      productId: (json['product_id'] ?? '').toString(),
      weight: (json['weight'] ?? '1kg').toString(),
      weightValue: parseDouble(json['weight_value'], 1.0),
      price: parseDouble(json['price'], 0.0),
      stock: parseInt(json['stock'], 0),
      isAvailable: parseBool(json['is_available'], true),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'weight': weight,
      'weight_value': weightValue,
      'price': price,
      'stock': stock,
      'is_available': isAvailable,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

/// Product with Variants - Complete product data
class ProductWithVariants {
  final ProductModel product;
  final List<ProductVariantModel> variants;

  ProductWithVariants({
    required this.product,
    required this.variants,
  });

  /// Get minimum price from variants or base price
  double get minPrice {
    if (variants.isNotEmpty) {
      return variants.map((v) => v.price).reduce((a, b) => a < b ? a : b);
    }
    return product.price;
  }

  /// Get maximum price from variants or base price
  double get maxPrice {
    if (variants.isNotEmpty) {
      return variants.map((v) => v.price).reduce((a, b) => a > b ? a : b);
    }
    return product.price;
  }

  /// Check if product has variants
  bool get hasVariants => variants.isNotEmpty;

  /// Get available variants
  List<ProductVariantModel> get availableVariants =>
      variants.where((v) => v.isAvailable && v.stock > 0).toList();

  /// Get display unit for product (variant weight or product unit)
  String getDisplayUnit() {
    if (ProductUnitHelper.isPieceUnit(product.unit)) {
      return ProductUnitHelper.normalizeDisplayUnit(product.unit);
    }
    if (variants.isNotEmpty) {
      final available = availableVariants;
      if (available.isNotEmpty) {
        return available.first.weight; // Return first available variant weight
      }
      return variants.first.weight; // Fallback to first variant
    }
    return product.unit; // No variants, use product unit
  }

  /// Get price display text with unit
  String getPriceDisplayText() {
    if (hasVariants) {
      if (minPrice == maxPrice) {
        return '₹${minPrice.toStringAsFixed(0)} / ${getDisplayUnit()}';
      }
      return '₹${minPrice.toStringAsFixed(0)} - ₹${maxPrice.toStringAsFixed(0)} / ${getDisplayUnit()}';
    }
    return '₹${product.finalPrice.toStringAsFixed(0)} / ${product.unit}';
  }
}

