import 'product_model.dart';

/// Cart item model
class CartItem {
  final String? itemId;
  final String productId;
  final ProductModel product;
  final String? variantId; // Variant ID if product has variants
  final double? variantPrice; // Variant price if variant is selected
  double quantity;
  final String unit;

  CartItem({
    this.itemId,
    required this.productId,
    required this.product,
    this.variantId,
    this.variantPrice,
    required this.quantity,
    required this.unit,
  });

  /// Calculate total price for this cart item
  /// Uses variant price if available, otherwise uses product final price
  double get totalPrice {
    final unitPrice = variantPrice ?? product.finalPrice;
    return unitPrice * quantity;
  }
  
  /// Get unit price (variant price or product price)
  double get unitPrice => variantPrice ?? product.finalPrice;

  /// Create CartItem from JSON
  factory CartItem.fromJson(Map<String, dynamic> json) {
    // Extract variant price if variant data is available
    double? variantPrice;
    if (json['variant'] != null && json['variant'] is Map) {
      final variant = json['variant'] as Map<String, dynamic>;
      variantPrice = variant['price'] != null
          ? ((variant['price'] is num) ? (variant['price'] as num).toDouble() : null)
          : null;
    }
    
    return CartItem(
      itemId: json['id']?.toString() ??
          json['_id']?.toString() ??
          json['itemId']?.toString(),
      productId: json['product_id']?.toString() ??
          json['productId']?.toString() ??
          '',
      product: ProductModel.fromJson(json['product'] as Map<String, dynamic>),
      variantId: json['variant_id']?.toString() ?? json['variantId']?.toString(),
      variantPrice: variantPrice,
      quantity: json['quantity'] != null 
          ? ((json['quantity'] is num) ? (json['quantity'] as num).toDouble() : 1.0)
          : 1.0,
      unit: json['unit'] as String? ?? 'kg',
    );
  }

  /// Convert CartItem to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': itemId,
      'product_id': productId,
      'variant_id': variantId,
      'variant_price': variantPrice,
      'product': product.toJson(),
      'quantity': quantity,
      'unit': unit,
    };
  }

  /// Create a copy with updated quantity
  CartItem copyWith({
    String? itemId,
    double? quantity,
    String? variantId,
    double? variantPrice,
  }) {
    return CartItem(
      itemId: itemId ?? this.itemId,
      productId: productId,
      product: product,
      variantId: variantId ?? this.variantId,
      variantPrice: variantPrice ?? this.variantPrice,
      quantity: quantity ?? this.quantity,
      unit: unit,
    );
  }
}

/// Cart model to manage shopping cart
class CartModel {
  final List<CartItem> items;

  CartModel({this.items = const []});

  /// Get total number of items in cart
  int get itemCount => items.length;

  /// Get total quantity of all items
  double get totalQuantity {
    return items.fold(0.0, (sum, item) => sum + item.quantity);
  }

  /// Get subtotal (without delivery charges)
  double get subtotal {
    return items.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  /// Get total discount amount
  double get totalDiscount {
    return items.fold(0.0, (sum, item) {
      if (item.product.hasDiscount) {
        double originalPrice = item.product.price * item.quantity;
        double discountedPrice = item.product.finalPrice * item.quantity;
        return sum + (originalPrice - discountedPrice);
      }
      return sum;
    });
  }

  /// Check if cart is empty
  bool get isEmpty => items.isEmpty;

  /// Check if cart has items
  bool get isNotEmpty => items.isNotEmpty;

  /// Find item by product ID
  CartItem? findItemByProductId(String productId) {
    try {
      return items.firstWhere((item) => item.productId == productId);
    } catch (e) {
      return null;
    }
  }

  /// Find item by product ID and variant ID (variant-aware lookup)
  CartItem? findItemByProductAndVariant(String productId, String? variantId) {
    try {
      return items.firstWhere((item) =>
          item.productId == productId && item.variantId == variantId);
    } catch (e) {
      return null;
    }
  }

  /// Check if product exists in cart
  bool hasProduct(String productId) {
    return findItemByProductId(productId) != null;
  }

  /// Create CartModel from JSON
  factory CartModel.fromJson(Map<String, dynamic> json) {
    return CartModel(
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => CartItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Convert CartModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  /// Create a copy with updated items
  CartModel copyWith({List<CartItem>? items}) {
    return CartModel(
      items: items ?? this.items,
    );
  }
}

