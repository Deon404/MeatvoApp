class OrderModel {
  final int id;
  final String status;
  final double totalAmount;
  final String address;
  final String paymentMode;
  final DateTime createdAt;
  final List<OrderItemModel> items;
  final OrderAssignmentModel? assignment;

  const OrderModel({
    required this.id,
    required this.status,
    required this.totalAmount,
    required this.address,
    required this.paymentMode,
    required this.createdAt,
    this.items = const [],
    this.assignment,
  });

  factory OrderModel.fromListJson(Map<String, dynamic> json) {
    return OrderModel(
      id: (json['id'] as num).toInt(),
      status: (json['status'] ?? 'PLACED').toString(),
      totalAmount: ((json['total_amount'] ?? json['totalAmount'] ?? 0) as num).toDouble(),
      address: (json['address'] ?? '').toString(),
      paymentMode: (json['payment_mode'] ?? json['paymentMode'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.now(),
    );
  }

  factory OrderModel.fromDetailJson(Map<String, dynamic> order, List<OrderItemModel> items, OrderAssignmentModel? assignment) {
    return OrderModel(
      id: (order['id'] as num).toInt(),
      status: (order['status'] ?? 'PLACED').toString(),
      totalAmount: ((order['total_amount'] ?? order['totalAmount'] ?? 0) as num).toDouble(),
      address: (order['address'] ?? '').toString(),
      paymentMode: (order['payment_mode'] ?? order['paymentMode'] ?? '').toString(),
      createdAt: DateTime.tryParse((order['created_at'] ?? '').toString()) ?? DateTime.now(),
      items: items,
      assignment: assignment,
    );
  }
}

class OrderItemModel {
  final int id;
  final int productId;
  final int quantity;
  final double price;
  final String name;
  final String imageUrl;
  final String unit;

  const OrderItemModel({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.price,
    required this.name,
    required this.imageUrl,
    required this.unit,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: (json['id'] as num).toInt(),
      productId: (json['product_id'] as num).toInt(),
      quantity: (json['quantity'] as num).toInt(),
      price: ((json['price'] ?? 0) as num).toDouble(),
      name: (json['name'] ?? '').toString(),
      imageUrl: (json['image_url'] ?? '').toString(),
      unit: (json['unit'] ?? '').toString(),
    );
  }
}

class OrderAssignmentModel {
  final int deliveryPartnerId;
  final String partnerName;
  final String partnerPhone;
  final double? currentLat;
  final double? currentLng;

  const OrderAssignmentModel({
    required this.deliveryPartnerId,
    required this.partnerName,
    required this.partnerPhone,
    required this.currentLat,
    required this.currentLng,
  });

  factory OrderAssignmentModel.fromJson(Map<String, dynamic> json) {
    return OrderAssignmentModel(
      deliveryPartnerId: (json['delivery_partner_id'] as num).toInt(),
      partnerName: (json['user_name'] ?? 'Delivery Partner').toString(),
      partnerPhone: (json['user_phone'] ?? '').toString(),
      currentLat: json['current_lat'] == null ? null : ((json['current_lat'] as num).toDouble()),
      currentLng: json['current_lng'] == null ? null : ((json['current_lng'] as num).toDouble()),
    );
  }
}
