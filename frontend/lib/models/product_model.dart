import 'dart:convert';

/// Product Nutrients Model
class ProductNutrients {
  final double? calories; // per 100g
  final double? protein; // grams per 100g
  final double? fat; // grams per 100g
  final double? carbs; // grams per 100g
  final double? fiber; // grams per 100g
  final double? sodium; // mg per 100g
  final String? servingSize; // e.g., "100g", "1 piece"

  ProductNutrients({
    this.calories,
    this.protein,
    this.fat,
    this.carbs,
    this.fiber,
    this.sodium,
    this.servingSize,
  });

  factory ProductNutrients.fromJson(Map<String, dynamic> json) {
    // Defensive num parser: backend (admin) might send a string like "31",
    // an int, a double, or even null. We accept ALL of those and never
    // throw — silently dropping unparseable values to `null` so a single
    // bad nutrient field can never crash the product card.
    double? asDouble(Object? value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value.trim());
      return null;
    }

    return ProductNutrients(
      calories: asDouble(json['calories']),
      protein: asDouble(json['protein']),
      fat: asDouble(json['fat']),
      carbs: asDouble(json['carbs']),
      fiber: asDouble(json['fiber']),
      sodium: asDouble(json['sodium']),
      servingSize: (json['serving_size'] ?? '100g').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'protein': protein,
      'fat': fat,
      'carbs': carbs,
      'fiber': fiber,
      'sodium': sodium,
      'serving_size': servingSize,
    };
  }
}

/// Product model representing meat products
class ProductModel {
  final String id;
  final String name;
  final String? description;
  final double price;
  final String? categoryId;
  final String? categoryName;
  final String? imageUrl;
  final List<String>? images; // Multiple images array
  final String unit; // 'kg', 'gm', 'piece'
  final double? stock;
  final bool isAvailable;
  final bool isVegetarian;
  final double? discount;
  final ProductNutrients? nutritionalInfo; // Nutritional information
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ProductModel({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.categoryId,
    this.categoryName,
    this.imageUrl,
    this.images,
    this.unit = 'kg',
    this.stock,
    this.isAvailable = true,
    this.isVegetarian = false,
    this.discount,
    this.nutritionalInfo,
    this.createdAt,
    this.updatedAt,
  });

  /// Calculate final price after discount.
  ///
  /// Captures `discount` into a LOCAL so smart-cast promotes it to
  /// non-null. The previous version used `discount!` after a null
  /// check — bangs on instance fields are NOT safe in Dart because the
  /// field is technically a getter and a subclass could override it
  /// to return null after the check. Local capture sidesteps that
  /// "Null check operator used on a null value" crash entirely.
  double get finalPrice {
    final d = discount;
    if (d != null && d > 0) {
      return price - (price * d / 100);
    }
    return price;
  }

  /// True when the product has a non-zero discount. Same local-capture
  /// safety guarantee as [finalPrice] — never throws.
  bool get hasDiscount {
    final d = discount;
    return d != null && d > 0;
  }

  /// Get primary image URL (from images array or imageUrl).
  ///
  /// Locals capture nullable fields once so the rest of the method
  /// can use smart-cast non-null values. The previous version used
  /// `images!` and `imageUrl!` which could throw if the model was
  /// rebuilt mid-read from a stream.
  String? get primaryImageUrl {
    final list = images;
    if (list != null && list.isNotEmpty) {
      return list.first;
    }
    return imageUrl;
  }

  /// All available images (images array + imageUrl if not already in it).
  List<String> get allImages {
    final imageList = <String>[];

    final list = images;
    if (list != null && list.isNotEmpty) {
      imageList.addAll(list);
    }

    final url = imageUrl;
    if (url != null && url.isNotEmpty && !imageList.contains(url)) {
      imageList.insert(0, url);
    }

    return imageList;
  }

  /// Create ProductModel from JSON.
  ///
  /// Hardened against:
  ///   • null/missing required fields (id, name, price)  → safe defaults
  ///   • wrong types from admin dashboard (int sent as string, etc.)
  ///   • malformed nutritional_info blobs
  ///   • bad URL strings (trimmed; empty → null fallback)
  ///   • bad dates (parse errors → null instead of throwing)
  ///
  /// We DO NOT throw from here. A single bad product row from the admin
  /// dashboard must never crash the catalog grid.
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    // Local helpers — kept inside the factory so the public API stays clean.
    String asString(Object? v, [String fallback = '']) {
      if (v == null) return fallback;
      return v.toString();
    }

    String? asStringOrNull(Object? v) {
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    double asDouble(Object? v, [double fallback = 0.0]) {
      if (v == null) return fallback;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.trim()) ?? fallback;
      return fallback;
    }

    double? asDoubleOrNull(Object? v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.trim());
      return null;
    }

    bool asBool(Object? v, {required bool fallback}) {
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

    DateTime? asDate(Object? v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    ProductNutrients? nutritionalInfo;
    final rawNutrients = json['nutritional_info'];
    if (rawNutrients is Map) {
      try {
        nutritionalInfo = ProductNutrients.fromJson(
          Map<String, dynamic>.from(rawNutrients),
        );
      } catch (_) {
        nutritionalInfo = null;
      }
    } else if (rawNutrients is String && rawNutrients.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawNutrients);
        if (decoded is Map) {
          nutritionalInfo =
              ProductNutrients.fromJson(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {
        nutritionalInfo = null;
      }
    }

    List<String>? parsedImages;
    final rawImages = json['images'];
    if (rawImages is List) {
      parsedImages = rawImages
          .map((e) => e?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      if (parsedImages.isEmpty) parsedImages = null;
    } else if (rawImages is String && rawImages.trim().isNotEmpty) {
      parsedImages = [rawImages.trim()];
    }

    return ProductModel(
      // id is required for cart/wishlist lookups, so we coerce to string
      // and fall back to empty (caller can drop empty-id rows).
      id: asString(json['id']),
      // Empty product name still renders cleanly (the card uses maxLines+
      // ellipsis); we deliberately do NOT throw.
      name: asString(json['name']),
      description: asStringOrNull(json['description']),
      price: asDouble(json['price']),
      categoryId: asStringOrNull(json['category_id']),
      categoryName:
          asStringOrNull(json['category_name']) ?? asStringOrNull(json['category']),
      imageUrl: asStringOrNull(json['image_url']),
      images: parsedImages,
      unit: asString(json['unit'], 'kg'),
      stock: asDoubleOrNull(json['stock']),
      isAvailable: asBool(json['is_available'], fallback: true),
      isVegetarian: asBool(json['is_vegetarian'], fallback: false),
      discount: asDoubleOrNull(json['discount']),
      nutritionalInfo: nutritionalInfo,
      createdAt: asDate(json['created_at']),
      updatedAt: asDate(json['updated_at']),
    );
  }

  /// Convert ProductModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'category_id': categoryId,
      'category_name': categoryName,
      'image_url': imageUrl,
      'images': images,
      'unit': unit,
      'stock': stock,
      'is_available': isAvailable,
      'is_vegetarian': isVegetarian,
      'discount': discount,
      'nutritional_info': nutritionalInfo?.toJson(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  ProductModel copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? categoryId,
    String? categoryName,
    String? imageUrl,
    List<String>? images,
    String? unit,
    double? stock,
    bool? isAvailable,
    bool? isVegetarian,
    double? discount,
    ProductNutrients? nutritionalInfo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      imageUrl: imageUrl ?? this.imageUrl,
      images: images ?? this.images,
      unit: unit ?? this.unit,
      stock: stock ?? this.stock,
      isAvailable: isAvailable ?? this.isAvailable,
      isVegetarian: isVegetarian ?? this.isVegetarian,
      discount: discount ?? this.discount,
      nutritionalInfo: nutritionalInfo ?? this.nutritionalInfo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get default nutrients for chicken products based on product name
  ProductNutrients? getDefaultNutrients() {
    if (categoryName?.toLowerCase() != 'chicken') return null;
    
    final nameLower = name.toLowerCase();
    
    // Chicken Breast
    if (nameLower.contains('breast') || nameLower.contains('boneless')) {
      return ProductNutrients(
        calories: 165.0,
        protein: 31.0,
        fat: 3.6,
        carbs: 0.0,
        fiber: 0.0,
        sodium: 74.0,
        servingSize: '100g',
      );
    }
    
    // Chicken Drumsticks
    if (nameLower.contains('drumstick') || nameLower.contains('leg')) {
      return ProductNutrients(
        calories: 172.0,
        protein: 28.3,
        fat: 5.7,
        carbs: 0.0,
        fiber: 0.0,
        sodium: 84.0,
        servingSize: '100g',
      );
    }
    
    // Whole Chicken
    if (nameLower.contains('whole') || nameLower.contains('full')) {
      return ProductNutrients(
        calories: 239.0,
        protein: 27.3,
        fat: 13.6,
        carbs: 0.0,
        fiber: 0.0,
        sodium: 82.0,
        servingSize: '100g',
      );
    }
    
    // Chicken Thigh
    if (nameLower.contains('thigh')) {
      return ProductNutrients(
        calories: 209.0,
        protein: 26.0,
        fat: 10.9,
        carbs: 0.0,
        fiber: 0.0,
        sodium: 79.0,
        servingSize: '100g',
      );
    }
    
    // Chicken Wings
    if (nameLower.contains('wing')) {
      return ProductNutrients(
        calories: 203.0,
        protein: 30.5,
        fat: 8.1,
        carbs: 0.0,
        fiber: 0.0,
        sodium: 82.0,
        servingSize: '100g',
      );
    }
    
    // Default chicken nutrients (average)
    return ProductNutrients(
      calories: 200.0,
      protein: 27.0,
      fat: 9.0,
      carbs: 0.0,
      fiber: 0.0,
      sodium: 80.0,
      servingSize: '100g',
    );
  }
}

