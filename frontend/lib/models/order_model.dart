double _toDouble(dynamic value, {double fallback = 0.0}) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value.trim()) ?? fallback;
  }
  return fallback;
}

/// Safe date parser used by OrderModel / OrderItem. Returns `null` on any
/// failure so a malformed timestamp from the backend cannot crash the
/// orders screen.
DateTime? _safeDate(Object? value) {
  if (value == null) return null;
  try {
    return DateTime.parse(value.toString());
  } catch (_) {
    return null;
  }
}

int? _parseIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

/// Order model representing customer orders
class OrderModel {
  final String id;
  final String userId;
  final String? riderId;
  final String? riderName;
  final String? riderPhone;
  final double? riderLatitude;
  final double? riderLongitude;
  final List<OrderItem> items;
  final double totalAmount;
  final double? discountAmount;
  final double? deliveryCharge;
  final double finalAmount;
  final String status; // 'pending', 'confirmed', 'preparing', 'out_for_delivery', 'delivered', 'cancelled'
  final String paymentMethod; // 'cod', 'online'
  final String? paymentStatus; // 'pending', 'completed', 'failed'
  final String? paymentId; // Cashfree / gateway payment reference
  final Map<String, dynamic>? paymentMethodDetails; // Payment details (JSONB)
  final String? deliveryAddress;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final String? specialInstructions;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deliveredAt;
  final DateTime? estimatedDeliveryTime;
  final int? etaMinutes;
  final String? deliverySlotLabel;

  OrderModel({
    required this.id,
    required this.userId,
    this.riderId,
    this.riderName,
    this.riderPhone,
    this.riderLatitude,
    this.riderLongitude,
    required this.items,
    required this.totalAmount,
    this.discountAmount,
    this.deliveryCharge,
    required this.finalAmount,
    this.status = 'pending',
    this.paymentMethod = 'cod',
    this.paymentStatus,
    this.paymentId,
    this.paymentMethodDetails,
    this.deliveryAddress,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.specialInstructions,
    this.createdAt,
    this.updatedAt,
    this.deliveredAt,
    this.estimatedDeliveryTime,
    this.etaMinutes,
    this.deliverySlotLabel,
  });

  /// Create OrderModel from JSON
  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return OrderModel(
      id: json['id'] is String ? json['id'] as String : json['id'].toString(),
      userId: (json['user_id'] ?? json['userId'] ?? json['customer_id'] ?? '')
          .toString(),
      riderId: json['rider_id'] as String?,
      riderName: json['rider_name'] as String?,
      riderPhone: json['rider_phone'] as String?,
      riderLatitude: json['rider_latitude'] != null
          ? _toDouble(json['rider_latitude'])
          : null,
      riderLongitude: json['rider_longitude'] != null
          ? _toDouble(json['rider_longitude'])
          : null,
      items: rawItems
          .map((item) => OrderItem.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(),
      totalAmount: _toDouble(json['subtotal'] ?? json['total_amount']),
      discountAmount: json['discount_amount'] != null
          ? _toDouble(json['discount_amount'])
          : null,
      deliveryCharge: json['delivery_charge'] != null
          ? _toDouble(json['delivery_charge'])
          : null,
      finalAmount: _toDouble(
        json['total_price'] ?? json['final_amount'] ?? json['total_amount'],
      ),
      status: json['status'] as String? ?? 'pending',
      paymentMethod: json['payment_method'] as String? ?? 'cod',
      paymentStatus: json['payment_status'] as String?,
      paymentId: json['payment_id'] as String?,
      paymentMethodDetails: json['payment_method_details'] != null
          ? Map<String, dynamic>.from(json['payment_method_details'] as Map)
          : null,
      deliveryAddress: json['delivery_address']?.toString(),
      deliveryLatitude: json['delivery_latitude'] != null
          ? _toDouble(json['delivery_latitude'], fallback: 0)
          : null,
      deliveryLongitude: json['delivery_longitude'] != null
          ? _toDouble(json['delivery_longitude'], fallback: 0)
          : null,
      specialInstructions: json['special_instructions']?.toString(),
      createdAt: _safeDate(json['created_at']),
      updatedAt: _safeDate(json['updated_at']),
      deliveredAt: _safeDate(json['delivered_at']),
      estimatedDeliveryTime: _safeDate(
        json['estimated_delivery_time'] ?? json['estimatedDeliveryTime'],
      ),
      etaMinutes: _parseIntOrNull(json['eta_minutes'] ?? json['etaMinutes']),
      deliverySlotLabel: (json['delivery_slot_label'] ??
              json['deliverySlotLabel'] ??
              json['slot_name'])
          ?.toString(),
    );
  }

  /// Convert OrderModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'rider_id': riderId,
      'rider_name': riderName,
      'rider_phone': riderPhone,
      'rider_latitude': riderLatitude,
      'rider_longitude': riderLongitude,
      'items': items.map((item) => item.toJson()).toList(),
      'total_amount': totalAmount,
      'discount_amount': discountAmount,
      'delivery_charge': deliveryCharge,
      'final_amount': finalAmount,
      'status': status,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'payment_id': paymentId,
      'payment_method_details': paymentMethodDetails,
      'delivery_address': deliveryAddress,
      'delivery_latitude': deliveryLatitude,
      'delivery_longitude': deliveryLongitude,
      'special_instructions': specialInstructions,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
      'estimated_delivery_time': estimatedDeliveryTime?.toIso8601String(),
      'eta_minutes': etaMinutes,
      'delivery_slot_label': deliverySlotLabel,
    };
  }

  OrderModel copyWith({
    String? status,
    String? paymentStatus,
    String? riderId,
    String? riderName,
    String? riderPhone,
    double? riderLatitude,
    double? riderLongitude,
    double? deliveryLatitude,
    double? deliveryLongitude,
    DateTime? estimatedDeliveryTime,
    int? etaMinutes,
    String? deliverySlotLabel,
  }) {
    return OrderModel(
      id: id,
      userId: userId,
      riderId: riderId ?? this.riderId,
      riderName: riderName ?? this.riderName,
      riderPhone: riderPhone ?? this.riderPhone,
      riderLatitude: riderLatitude ?? this.riderLatitude,
      riderLongitude: riderLongitude ?? this.riderLongitude,
      items: items,
      totalAmount: totalAmount,
      discountAmount: discountAmount,
      deliveryCharge: deliveryCharge,
      finalAmount: finalAmount,
      status: status ?? this.status,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentId: paymentId,
      paymentMethodDetails: paymentMethodDetails,
      deliveryAddress: deliveryAddress,
      deliveryLatitude: deliveryLatitude ?? this.deliveryLatitude,
      deliveryLongitude: deliveryLongitude ?? this.deliveryLongitude,
      specialInstructions: specialInstructions,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deliveredAt: deliveredAt,
      estimatedDeliveryTime:
          estimatedDeliveryTime ?? this.estimatedDeliveryTime,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      deliverySlotLabel: deliverySlotLabel ?? this.deliverySlotLabel,
    );
  }
}

/// Order item model representing individual items in an order
class OrderItem {
  final String productId;
  final String productName;
  final double quantity;
  final String unit;
  final double price;
  final double totalPrice;
  final String? variantId;
  final String? imageUrl;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.price,
    required this.totalPrice,
    this.variantId,
    this.imageUrl,
  });

  /// Create OrderItem from JSON
  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: (json['product_id'] ?? '').toString(),
      productName: json['product_name'] as String? ?? '',
      quantity: _toDouble(json['quantity'], fallback: 1.0),
      unit: json['weight_option'] as String? ??
          json['unit'] as String? ??
          'kg',
      price: _toDouble(json['unit_price'] ?? json['price']),
      totalPrice: _toDouble(json['item_price'] ?? json['total_price']),
      variantId: json['variant_id']?.toString(),
      imageUrl: (json['image_url'] ?? json['imageUrl'])?.toString(),
    );
  }

  /// Convert OrderItem to JSON
  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'weight_option': unit,
      'unit_price': price,
      'item_price': totalPrice,
      'variant_id': variantId,
      'image_url': imageUrl,
    };
  }
}

