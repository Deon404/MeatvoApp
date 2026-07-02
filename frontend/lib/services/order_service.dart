import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../config/api_config.dart'
    show ApiConfig, ApiOrderPaths, ApiUserPaths;
import '../models/order_model.dart';
import '../models/cart_model.dart';
import '../utils/address_display_util.dart';
import '../utils/order_status_util.dart';
import 'api_service.dart';
import 'error_tracking_service.dart';
import 'delivery_service.dart';

/// Order service — custom Node.js backend
class OrderService {
  final ApiService _api = ApiService();
  // DeliveryService kept for delivery-radius validation
  final DeliveryService _deliveryService = DeliveryService();

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool _isRequestSuccessful(dynamic data) {
    if (data is! Map) return false;
    final map = data.cast<String, dynamic>();
    return map['success'] == true || map['ok'] == true;
  }

  String _responseMessage(dynamic data, {String fallback = 'Request failed'}) {
    if (data is Map) {
      final map = data.cast<String, dynamic>();
      final error = map['error'];
      if (error is Map && error['message'] != null) {
        return error['message'].toString();
      }
      final message = map['message'];
      if (message != null && message.toString().trim().isNotEmpty) {
        return message.toString();
      }
    } else if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }
    return fallback;
  }

  dynamic _extractData(dynamic responseData) {
    if (responseData is Map) {
      return responseData['data'];
    }
    return null;
  }

  String _normalizeStatus(String? status) => normalizeOrderStatus(status);

  String? _normalizeAddress(dynamic address) {
    if (address == null) return null;
    final formatted = formatAddressForDisplay(address);
    if (formatted == 'Address not available') return null;
    return formatted;
  }

  String _formatDeliveryAddress(Map<String, dynamic> address) {
    final formatted = formatAddressForDisplay(address);
    if (formatted == 'Address not available') {
      throw Exception('Delivery address is missing. Please select a saved address.');
    }
    return formatted;
  }

  Map<String, dynamic> _normalizeOrderItem(Map<String, dynamic> json) {
    final item = Map<String, dynamic>.from(json);
    final quantity = item['quantity'];
    final unitPrice = item['unit_price'] ?? item['price'];
    final qtyValue =
        quantity is num ? quantity.toDouble() : double.tryParse('$quantity') ?? 0;
    final unitPriceValue = unitPrice is num
        ? unitPrice.toDouble()
        : double.tryParse('$unitPrice') ?? 0;

    item['product_id'] = (item['product_id'] ?? item['productId'] ?? '').toString();
    item['product_name'] ??= item['name'] ?? '';
    item['image_url'] ??= item['imageUrl'] ?? '';
    item['unit'] ??= item['weight_option'] ?? '';
    item['unit_price'] = unitPriceValue;
    item['total_price'] ??= unitPriceValue * qtyValue;
    if (item['variant_id'] != null) {
      item['variant_id'] = item['variant_id'].toString();
    }
    return item;
  }

  Map<String, dynamic> _extractOrderPayload(dynamic data) {
    if (data is! Map) return <String, dynamic>{};

    final payload = Map<String, dynamic>.from(data);
    final orderPayload = payload['order'];
    if (orderPayload is Map) {
      final order = Map<String, dynamic>.from(orderPayload);
      if (payload['items'] is List) {
        order['items'] = payload['items'];
      }
      if (payload['pricing'] is Map) {
        final pricing = Map<String, dynamic>.from(payload['pricing']);
        order['subtotal'] ??= pricing['subtotal'];
        order['delivery_charge'] ??=
            pricing['deliveryCharge'] ?? pricing['delivery_charge'];
        order['discount_amount'] ??=
            pricing['discountAmount'] ?? pricing['discount_amount'];
        order['final_amount'] ??=
            pricing['totalAmount'] ?? pricing['finalAmount'] ?? pricing['final_amount'];
        order['total_price'] ??= order['final_amount'];
      }
      return order;
    }

    return payload;
  }

  List<dynamic> _extractOrdersPayload(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      final payload = Map<String, dynamic>.from(data);
      final orders = payload['orders'];
      if (orders is List) return orders;
    }
    return const [];
  }

  OrderModel _parseOrder(Map<String, dynamic> json) {
    final m = Map<String, dynamic>.from(json);

    // Normalise items list
    final rawItems = (m['items'] as List<dynamic>? ?? [])
        .map((i) => Map<String, dynamic>.from(i as Map))
        .toList();
    m['items'] = rawItems;

    // Normalise camelCase → snake_case for OrderModel.fromJson
    m['id'] = (m['id'] ?? '').toString();
    m['user_id'] =
        (m['user_id'] ?? m['userId'] ?? m['customer_id'] ?? m['customerId'] ?? '')
            .toString();
    m['total_price'] ??= m['totalPrice'] ?? m['total'];
    m['total_price'] ??= m['final_amount'] ?? m['total_amount'];
    m['delivery_charge'] ??= m['deliveryCharge'];
    m['discount_amount'] ??= m['discountAmount'];
    m['payment_method'] ??= m['paymentMethod'];
    m['payment_method'] ??= m['payment_mode'];
    if (m['payment_method'] != null) {
      m['payment_method'] = m['payment_method'].toString().toLowerCase();
    }
    m['payment_status'] ??= m['paymentStatus'];
    if (m['payment_status'] != null) {
      m['payment_status'] = m['payment_status'].toString().toLowerCase();
    }
    m['payment_id'] ??= m['paymentId'];
    m['payment_id'] ??= m['gateway_payment_id'];
    m['payment_id'] ??= m['gatewayPaymentId'];
    m['payment_id'] ??= m['gateway_transaction_id'];
    m['payment_id'] ??= m['gatewayTransactionId'];
    m['payment_method_details'] ??= m['paymentMethodDetails'];
    m['payment_method_details'] ??= m['gateway_response'];
    m['payment_method_details'] ??= m['gatewayResponse'];
    m['delivery_address'] ??= m['deliveryAddress'];
    m['delivery_address'] ??= _normalizeAddress(m['address']);
    final addressObj = m['address'];
    if (addressObj is Map) {
      final addrMap = Map<String, dynamic>.from(addressObj);
      m['delivery_latitude'] ??= addrMap['lat'] ?? addrMap['latitude'];
      m['delivery_longitude'] ??= addrMap['lng'] ?? addrMap['longitude'];
    }
    m['created_at'] ??= m['createdAt'];
    m['updated_at'] ??= m['updatedAt'];
    m['estimated_delivery_time'] ??= m['estimatedDeliveryTime'];
    m['eta_minutes'] ??= m['etaMinutes'];
    m['rider_id'] ??= m['riderId'];
    if (m['rider_id'] != null) {
      m['rider_id'] = m['rider_id'].toString();
    }
    m['rider_name'] ??= m['riderName'];
    m['rider_phone'] ??= m['riderPhone'];
    m['rider_latitude'] ??= m['riderLatitude'];
    m['rider_longitude'] ??= m['riderLongitude'];
    m['delivery_slot_label'] ??= m['deliverySlotLabel'];
    m['status'] = _normalizeStatus(m['status']?.toString());
    m['items'] = rawItems.map(_normalizeOrderItem).toList();

    return OrderModel.fromJson(m);
  }

  OrderModel _mergeAssignment(OrderModel order, dynamic assignment) {
    if (assignment is! Map) return order;
    final map = Map<String, dynamic>.from(assignment);
    final lat = map['current_lat'] ?? map['currentLat'];
    final lng = map['current_lng'] ?? map['currentLng'];
    final riderLat = lat is num
        ? lat.toDouble()
        : double.tryParse('$lat');
    final riderLng = lng is num
        ? lng.toDouble()
        : double.tryParse('$lng');
    final riderUserId = map['user_id'] ?? map['userId'];

    return order.copyWith(
      riderId: (riderUserId ?? order.riderId)?.toString(),
      riderName: map['user_name']?.toString() ??
          map['userName']?.toString() ??
          order.riderName,
      riderPhone: map['user_phone']?.toString() ??
          map['userPhone']?.toString() ??
          order.riderPhone,
      riderLatitude: riderLat ?? order.riderLatitude,
      riderLongitude: riderLng ?? order.riderLongitude,
    );
  }

  OrderModel _parseOrderResponse(dynamic data) {
    if (data is! Map) return _parseOrder(<String, dynamic>{});
    final payload = Map<String, dynamic>.from(data);
    final orderPayload = _extractOrderPayload(payload);
    final eta = payload['eta'];
    if (eta is Map) {
      final etaMap = Map<String, dynamic>.from(eta);
      orderPayload['estimated_delivery_time'] ??=
          etaMap['estimatedTime'] ?? etaMap['estimated_time'];
      orderPayload['eta_minutes'] ??= etaMap['minutes'] ?? etaMap['etaMinutes'];
    }
    final order = _parseOrder(orderPayload);
    return _mergeAssignment(order, payload['assignment']);
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  /// Create order from cart.
  /// [deliveryAddress] must contain an 'id' key (addressId from the addresses list).
  Future<OrderModel> createOrder({
    required CartModel cart,
    required Map<String, dynamic> deliveryAddress,
    required String paymentMethod,
    String? couponCode,
    String? specialInstructions,
  }) async {
    if (cart.isEmpty) throw Exception('Cart is empty');

    // Validate delivery radius (unchanged logic)
    final deliveryLat = deliveryAddress['latitude'] as double? ??
        deliveryAddress['lat'] as double?;
    final deliveryLng = deliveryAddress['longitude'] as double? ??
        deliveryAddress['lng'] as double?;

    if (deliveryLat != null && deliveryLng != null) {
      try {
        await _deliveryService.ensureDeliveryAvailable(
          latitude: deliveryLat,
          longitude: deliveryLng,
        );
      } on DeliveryException catch (e) {
        throw Exception(e.message);
      }
    } else {
      throw Exception(
          'Delivery address coordinates are missing. Please select location on map.');
    }

    try {
      return await placeOrder(
        address: deliveryAddress,
        paymentMethod: paymentMethod,
        couponCode: couponCode,
        specialInstructions: specialInstructions,
      );
    } on DioException catch (e) {
      await ErrorTrackingService.captureException(
        e,
        tag: 'order_creation',
        context: {'cart_items_count': cart.items.length},
      );
      throw Exception(
          'Failed to create order: ${e.response?.data?['message'] ?? e.message}');
    } catch (e, st) {
      await ErrorTrackingService.captureException(e, stackTrace: st, tag: 'order_creation');
      throw Exception('Failed to create order: $e');
    }
  }

  /// Place order via backend.
  /// POST /orders — order items are read from the server Redis cart.
  Future<OrderModel> placeOrder({
    required Map<String, dynamic> address,
    required String paymentMethod,
    String? couponCode,
    String? specialInstructions,
  }) async {
    try {
      final addressId = (address['id'] ?? address['addressId'])?.toString();

      final normalizedPaymentMethod = paymentMethod.trim().toUpperCase();
      if (normalizedPaymentMethod != 'COD' &&
          normalizedPaymentMethod != 'ONLINE') {
        throw Exception('Invalid payment method. Use COD or ONLINE.');
      }

      final lat = address['latitude'] ?? address['lat'];
      final lng = address['longitude'] ?? address['lng'];

      final body = <String, dynamic>{
        if (addressId != null && addressId.isNotEmpty) 'addressId': addressId,
        'deliveryAddress': _formatDeliveryAddress(address),
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        'paymentMethod': normalizedPaymentMethod,
        if (couponCode != null && couponCode.isNotEmpty) 'couponCode': couponCode,
        if (specialInstructions != null && specialInstructions.isNotEmpty)
          'specialInstructions': specialInstructions,
      };

      final res = await _api.post(
        ApiOrderPaths.orders,
        data: body,
        options: Options(
          receiveTimeout: ApiConfig.orderReceiveTimeout,
          sendTimeout: ApiConfig.orderSendTimeout,
        ),
      );
      if (!_isRequestSuccessful(res.data)) {
        throw Exception(res.data['message'] ?? 'Failed to place order');
      }

      final order = _parseOrderResponse(_extractData(res.data));
      if (order.id.isNotEmpty && order.items.isEmpty) {
        try {
          return await getOrderById(order.id);
        } catch (_) {
          return order;
        }
      }
      return order;
    } on DioException catch (e) {
      throw Exception(
          'Failed to place order: ${e.response?.data?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to place order: $e');
    }
  }

  /// Get all orders for the logged-in user.
  Future<List<OrderModel>> getUserOrders() async {
    return getOrders();
  }

  /// Get orders (all pages).
  /// GET /orders?page=&limit=
  Future<List<OrderModel>> getOrders() async {
    try {
      const pageLimit = 50;
      var page = 1;
      final allOrders = <OrderModel>[];

      while (true) {
        final res = await _api.get(
          ApiOrderPaths.orders,
          queryParameters: {'page': page, 'limit': pageLimit},
        );
        if (!_isRequestSuccessful(res.data)) {
          throw Exception(res.data['message'] ?? 'Failed to fetch orders');
        }

        final data = _extractData(res.data);
        final list = _extractOrdersPayload(data);
        allOrders.addAll(
          list.map((e) => _parseOrder(e as Map<String, dynamic>)),
        );

        final total = data is Map ? (data['total'] as num?)?.toInt() : null;
        final pages = data is Map ? (data['pages'] as num?)?.toInt() : null;
        if (list.length < pageLimit) break;
        if (pages != null && page >= pages) break;
        if (total != null && allOrders.length >= total) break;
        page += 1;
      }

      return allOrders;
    } on DioException catch (e) {
      throw Exception(
          'Failed to fetch orders: ${e.response?.data?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to fetch orders: $e');
    }
  }

  /// Get single order by ID.
  Future<OrderModel> getOrderById(String orderId) async {
    try {
      final res = await _api.get('${ApiOrderPaths.orderById}$orderId');
      if (!_isRequestSuccessful(res.data)) {
        throw Exception(
          _responseMessage(res.data, fallback: 'Failed to fetch order'),
        );
      }
      return _parseOrderResponse(_extractData(res.data));
    } on DioException catch (e) {
      throw Exception(
          'Failed to fetch order: ${_responseMessage(e.response?.data, fallback: e.message ?? 'Failed to fetch order')}');
    } catch (e) {
      throw Exception('Failed to fetch order: $e');
    }
  }

  /// After a checkout timeout, the server may have created the order anyway.
  /// Returns the newest matching order placed on/after [since], if any.
  Future<OrderModel?> findRecentlyPlacedOrder({
    required DateTime since,
    required String paymentMethod,
  }) async {
    try {
      final res = await _api.get(
        ApiOrderPaths.orders,
        queryParameters: {'page': 1, 'limit': 3},
        options: Options(
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 12),
        ),
      );
      if (!_isRequestSuccessful(res.data)) return null;

      final data = _extractData(res.data);
      final list = _extractOrdersPayload(data);
      if (list.isEmpty) return null;

      final normalizedPayment = paymentMethod.trim().toUpperCase();
      for (final raw in list) {
        if (raw is! Map<String, dynamic>) continue;
        final order = _parseOrder(raw);
        final createdAt = order.createdAt;
        if (createdAt == null) continue;
        if (createdAt.isBefore(since.subtract(const Duration(seconds: 10)))) {
          continue;
        }
        final orderPayment = order.paymentMethod.toUpperCase();
        if (orderPayment != normalizedPayment) continue;
        final status = order.status.toUpperCase();
        if (status == 'CANCELLED') continue;
        return order;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Cancel order.
  /// PUT /orders/:id/cancel
  Future<void> cancelOrder(String orderId) async {
    try {
      final res = await _api.put('${ApiOrderPaths.cancelOrder}$orderId/cancel');
      if (!_isRequestSuccessful(res.data)) {
        throw Exception(
          _responseMessage(res.data, fallback: 'Failed to cancel order'),
        );
      }
    } on DioException catch (e) {
      throw Exception(
        'Failed to cancel order: ${_responseMessage(e.response?.data, fallback: e.message ?? 'Failed to cancel order')}',
      );
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to cancel order: $e');
    }
  }

  // ── Review / rating stubs ─────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getOrderReview(String orderId) async {
    try {
      final res = await _api.get(ApiUserPaths.reviewForOrder(orderId));
      final data = res.data;
      if (data is Map && data['success'] == true && data['data'] is Map) {
        final payload = Map<String, dynamic>.from(data['data'] as Map);
        final review = payload['review'];
        if (review is Map) return Map<String, dynamic>.from(review);
      }
    } catch (_) {}
    return null;
  }

  Future<void> submitReview({
    required String orderId,
    int? riderRating,
    int? productQualityRating,
    int? deliverySpeedRating,
    String? feedback,
  }) async {
    await _api.post(
      ApiUserPaths.reviews,
      data: {
        'order_id': int.tryParse(orderId) ?? orderId,
        if (riderRating != null) 'rider_rating': riderRating,
        if (productQualityRating != null) 'product_quality_rating': productQualityRating,
        if (deliverySpeedRating != null) 'delivery_speed_rating': deliverySpeedRating,
        if (feedback != null && feedback.trim().isNotEmpty) 'feedback': feedback.trim(),
      },
    );
  }

  @Deprecated('Use submitReview instead')
  Future<void> rateOrder({
    required String orderId,
    required double orderRating,
    String? orderReview,
    double? riderRating,
    String? riderReview,
  }) =>
      submitReview(
        orderId: orderId,
        riderRating: riderRating?.toInt(),
        productQualityRating: orderRating.toInt(),
        feedback: orderReview ?? riderReview,
      );

  Future<OrderModel> getOrderTracking(String orderId) async =>
      getOrderById(orderId);

  /// Fetch delivery OTP for customer (fetch once per dispatch — not polled).
  Future<String?> getDeliveryOtp(String orderId) async {
    try {
      final res = await _api.get(ApiOrderPaths.deliveryOtp(orderId));
      if (!_isRequestSuccessful(res.data)) return null;
      final data = _extractData(res.data);
      if (data is Map) {
        final otp = data['otp'];
        if (otp != null) return otp.toString();
      }
    } on DioException catch (e) {
      debugPrint('getDeliveryOtp failed: ${e.message}');
    } catch (e) {
      debugPrint('getDeliveryOtp failed: $e');
    }
    return null;
  }

  // ── Polling-based tracking ───────────────────────────────────────────────

  /// Fallback polling for active orders (prefer [OrderTrackingSubscription] + socket).
  Stream<OrderModel> trackOrder(String orderId) {
    return Stream.periodic(const Duration(seconds: 15))
        .asyncMap((_) => getOrderById(orderId));
  }
}
