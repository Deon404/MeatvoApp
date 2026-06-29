import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart' show ApiDeliveryPaths;
import '../models/earnings_data.dart';
import '../models/order_model.dart';
import 'api_service.dart';
import 'error_tracking_service.dart';
import 'maps_service.dart';
import 'rider_location_service.dart';
import '../utils/role_access_exception.dart';
import '../utils/address_display_util.dart';

/// Rider / Delivery-partner service — custom Node.js backend
/// Maps to /api/delivery/* endpoints
final riderServiceProvider = Provider<RiderService>((ref) {
  return RiderService(
    ref.read(apiServiceProvider),
    ref.read(riderLocationServiceProvider),
  );
});

class RiderService {
  final ApiService _api;
  final RiderLocationService _locationService;

  RiderService([ApiService? api, RiderLocationService? locationService])
      : _api = api ?? ApiService(),
        _locationService = locationService ?? RiderLocationService();

  StreamSubscription<List<OrderModel>>? _newOrdersSubscription;
  String? _activeOrderId;
  bool _isOnDelivery = false;
  final MapsService _mapsService = MapsService();

  List<Map<String, dynamic>>? _ordersCache;
  DateTime? _ordersCacheAt;
  static const Duration _ordersCacheTtl = Duration(seconds: 8);

  void _invalidateOrdersCache() {
    _ordersCache = null;
    _ordersCacheAt = null;
  }

  bool _isInsufficientPermissions(DioException e) {
    if (e.response?.statusCode != 403) return false;
    final data = e.response?.data;
    if (data is! Map) return false;
    final map = Map<String, dynamic>.from(data);
    final error = map['error'];
    if (error is Map && error['code'] == 'INSUFFICIENT_PERMISSIONS') {
      return true;
    }
    final message = map['message']?.toString() ?? '';
    return message.contains('is not allowed');
  }

  String _extractApiMessage(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map) {
      final message = data['message']?.toString();
      if (message != null && message.isNotEmpty) return message;
    }
    return fallback;
  }

  Never _throwDeliveryApiError(DioException e, String fallback) {
    if (_isInsufficientPermissions(e)) {
      final message = _extractApiMessage(
        e,
        'Delivery partner access required',
      );
      final roleMatch = RegExp(r'Role \(([^)]+)\)').firstMatch(message);
      throw RoleAccessException(
        message,
        role: roleMatch?.group(1),
      );
    }
    throw Exception('${_extractApiMessage(e, fallback)}');
  }

  dynamic _unwrapResponseData(Response res, String fallbackMessage) {
    final payload = res.data;
    if (payload is Map) {
      final map = Map<String, dynamic>.from(payload);
      if (map['success'] == false) {
        throw Exception(map['message'] ?? fallbackMessage);
      }
      if (map.containsKey('data')) {
        return map['data'];
      }
    }
    return payload;
  }

  Map<String, dynamic> _extractMap(Response res, String fallbackMessage) {
    final data = _unwrapResponseData(res, fallbackMessage);
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw Exception(fallbackMessage);
  }

  List<Map<String, dynamic>> _extractList(Response res, String fallbackMessage) {
    final data = _unwrapResponseData(res, fallbackMessage);
    if (data is List) {
      return List<Map<String, dynamic>>.from(
        data.map((e) => Map<String, dynamic>.from(e as Map)),
      );
    }
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final directOrders = map['orders'];
      if (directOrders is List) {
        return List<Map<String, dynamic>>.from(
          directOrders.map((e) => Map<String, dynamic>.from(e as Map)),
        );
      }

      final groupedLists = <Map<String, dynamic>>[];
      final seenIds = <String>{};
      for (final key in const ['pending', 'available', 'active', 'delivered']) {
        final value = map[key];
        if (value is List) {
          for (final entry in value) {
            final order = Map<String, dynamic>.from(entry as Map);
            final id = order['id']?.toString();
            if (id != null && seenIds.contains(id)) continue;
            if (id != null) seenIds.add(id);
            groupedLists.add(order);
          }
        }
      }
      if (groupedLists.isNotEmpty) {
        return groupedLists;
      }
      // Backend returns { available: [], active: [], delivered: [] } when rider has no orders.
      if (map.containsKey('available') ||
          map.containsKey('active') ||
          map.containsKey('delivered')) {
        return [];
      }
    }
    throw Exception(fallbackMessage);
  }

  String _normalizeStatus(dynamic value, {String fallback = 'assigned'}) {
    if (value == null) return fallback;
    return value
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll('-', '_');
  }

  String _toLegacyAssignmentStatus(String status) {
    switch (_normalizeStatus(status)) {
      case 'pending':
      case 'assigned':
      case 'confirmed':
      case 'packed':
        return 'assigned';
      case 'accepted':
      case 'out_for_delivery':
        return 'accepted';
      case 'picked':
      case 'picked_up':
        return 'picked_up';
      case 'on_way':
      case 'on_the_way':
        return 'on_the_way';
      case 'delivered':
        return 'delivered';
      case 'cancelled':
      case 'rejected':
        return 'cancelled';
      default:
        return _normalizeStatus(status);
    }
  }

  Map<String, dynamic> _normalizeOrder(Map<String, dynamic> order) {
    final normalized = Map<String, dynamic>.from(order);
    if (normalized['id'] != null) {
      normalized['id'] = normalized['id'].toString();
    }
    normalized['user_id'] = (normalized['user_id'] ??
            normalized['customer_id'] ??
            normalized['customerUid'] ??
            (normalized['user'] is Map
                ? (normalized['user'] as Map)['id']
                : null))
        ?.toString() ??
        '';
    normalized['status'] = _normalizeStatus(
      normalized['status'],
      fallback: 'assigned',
    );
    normalized['subtotal'] =
        normalized['subtotal'] ?? normalized['total_amount'] ?? normalized['totalAmount'] ?? 0;
    normalized['total_amount'] =
        normalized['total_amount'] ?? normalized['totalAmount'] ?? normalized['subtotal'] ?? 0;
    normalized['final_amount'] = normalized['final_amount'] ??
        normalized['total_price'] ??
        normalized['totalAmount'] ??
        normalized['total_amount'] ??
        0;
    normalized['total_price'] = normalized['total_price'] ??
        normalized['final_amount'] ??
        normalized['totalAmount'] ??
        normalized['total_amount'] ??
        0;
    normalized['payment_method'] = (normalized['payment_method'] ??
            normalized['paymentMethod'] ??
            normalized['payment_mode'] ??
            'cod')
        .toString()
        .toLowerCase();
    if (normalized['created_at'] == null && normalized['createdAt'] is num) {
      normalized['created_at'] = DateTime.fromMillisecondsSinceEpoch(
        (normalized['createdAt'] as num).toInt(),
      ).toIso8601String();
    }
    if (normalized['updated_at'] == null && normalized['updatedAt'] is num) {
      normalized['updated_at'] = DateTime.fromMillisecondsSinceEpoch(
        (normalized['updatedAt'] as num).toInt(),
      ).toIso8601String();
    }
    final customerName =
        (normalized['customerName'] ?? normalized['customer_name'] ?? '')
            .toString()
            .trim();
    final customerPhone = (normalized['phone'] ?? '').toString();
    normalized['user'] = {
      'id': normalized['user_id'],
      if (customerName.isNotEmpty) 'name': customerName,
      'phone': customerPhone,
    };

    final addressRaw = normalized['address'];
    if (addressRaw is String && addressRaw.trim().isNotEmpty) {
      final trimmed = formatAddressForDisplay(addressRaw);
      normalized['delivery_address'] = {
        'formatted': trimmed,
        'text': trimmed,
        'raw': trimmed,
      };
    } else if (addressRaw is Map) {
      final addressMap = Map<String, dynamic>.from(addressRaw);
      final text = formatAddressForDisplay(addressMap);
      normalized['delivery_address'] = {
        ...addressMap,
        if (text != 'Address not available') ...{
          'formatted': text,
          'text': text,
        },
      };
    }

    if (normalized['items'] is List) {
      normalized['items'] = (normalized['items'] as List)
          .map((item) {
            final mappedItem = Map<String, dynamic>.from(item as Map);
            final quantity = (mappedItem['quantity'] as num?)?.toInt() ?? 1;
            final price = (mappedItem['price'] as num?)?.toDouble() ?? 0.0;
            return {
              'product_id': (mappedItem['product_id'] ??
                      mappedItem['productId'] ??
                      mappedItem['id'] ??
                      '')
                  .toString(),
              'product_name':
                  mappedItem['product_name'] ?? mappedItem['name'] ?? 'Product',
              'quantity': quantity,
              'weight_option':
                  mappedItem['weight_option'] ?? mappedItem['unit'] ?? 'unit',
              'unit_price': price,
              'item_price': mappedItem['item_price'] ??
                  (quantity * price),
            };
          })
          .toList();
    }
    return normalized;
  }

  Map<String, dynamic> _normalizeRiderProfile(Map<String, dynamic> data) {
    final nested = data['profile'];
    final profile = nested is Map
        ? Map<String, dynamic>.from(nested)
        : Map<String, dynamic>.from(data);
    final online = profile['online'] == true;
    final name = (profile['name'] ?? '').toString().trim();
    final phone = (profile['phone'] ?? '').toString().trim();
    final displayName = name.isNotEmpty ? name : (phone.isNotEmpty ? phone : 'Rider');
    return {
      ...profile,
      'online': online,
      'status': online ? 'available' : 'offline',
      'name': displayName,
      'phone': phone,
      'user': {
        'name': displayName,
        'phone': phone,
      },
    };
  }

  Future<List<Map<String, dynamic>>> _fetchAssignedOrdersRaw({
    String? status,
    bool forceRefresh = false,
  }) async {
    final cacheFresh = !forceRefresh &&
        _ordersCache != null &&
        _ordersCacheAt != null &&
        DateTime.now().difference(_ordersCacheAt!) < _ordersCacheTtl;

    List<Map<String, dynamic>> orders;
    if (cacheFresh) {
      orders = List<Map<String, dynamic>>.from(_ordersCache!);
    } else {
      orders = _extractList(
        await _api.get(ApiDeliveryPaths.orders),
        'Failed to get rider orders',
      ).map(_normalizeOrder).toList();
      _ordersCache = orders;
      _ordersCacheAt = DateTime.now();
    }

    if (status != null && status.isNotEmpty) {
      final normalizedStatus = _normalizeStatus(status);
      orders = orders.where((order) {
        final orderStatus = _normalizeStatus(order['status']);
        final assignmentStatus = _toLegacyAssignmentStatus(
          order['assignment_status']?.toString() ?? orderStatus,
        );
        return orderStatus == normalizedStatus ||
            assignmentStatus == normalizedStatus;
      }).toList();
    }

    return orders;
  }

  Map<String, dynamic> _toLegacyAssignment(Map<String, dynamic> order) {
    final normalizedOrder = _normalizeOrder(order);
    final orderStatus = _normalizeStatus(normalizedOrder['status']);
    final assignmentStatus = normalizedOrder['assignment_status']?.toString();
    
    // If assignment_status is null, the order hasn't been accepted yet
    // Show as 'assigned' so rider sees Accept/Reject buttons
    String resolvedStatus;
    if (assignmentStatus == null || assignmentStatus.trim().isEmpty) {
      resolvedStatus = 'assigned';
    } else {
      resolvedStatus = _toLegacyAssignmentStatus(assignmentStatus);
      // assignment_status stays PICKED for both PICKED_UP and ON_THE_WAY orders
      if (_normalizeStatus(assignmentStatus) == 'picked') {
        if (orderStatus == 'on_the_way') {
          resolvedStatus = 'on_the_way';
        } else if (orderStatus == 'picked_up') {
          resolvedStatus = 'picked_up';
        }
      }
    }
    
    return {
      'id': normalizedOrder['id']?.toString() ?? '',
      'status': resolvedStatus,
      'assigned_at': normalizedOrder['assigned_at'] ?? normalizedOrder['created_at'],
      'rider': normalizedOrder['rider'],
      'order': normalizedOrder,
    };
  }

  // ── Profile ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getRiderProfile() async {
    try {
      final raw = _extractMap(
        await _api.get(ApiDeliveryPaths.profile),
        'Failed to get rider profile',
      );
      return _normalizeRiderProfile(raw);
    } on DioException catch (e) {
      await ErrorTrackingService.captureException(e, tag: 'rider_profile');
      _throwDeliveryApiError(e, 'Failed to get rider profile');
    } on RoleAccessException {
      rethrow;
    } catch (e, st) {
      await ErrorTrackingService.captureException(e, stackTrace: st, tag: 'rider_profile');
      throw Exception('Failed to get rider profile: $e');
    }
  }

  Future<void> updateRiderStatus(
    String status, {
    double? lat,
    double? lng,
  }) async {
    final normalized = status.toLowerCase().trim();
    if (normalized != 'available' && normalized != 'offline') {
      throw Exception('Invalid status. Use available or offline.');
    }
    final online = normalized == 'available';
    try {
      final res = await _api.post(
        ApiDeliveryPaths.toggleOnline,
        data: {
          'online': online,
          if (lat != null && lng != null) ...{
            'lat': lat,
            'lng': lng,
          },
        },
      );
      final payload = res.data;
      if (payload is Map && payload['success'] == false) {
        throw Exception(payload['message'] ?? 'Failed to update status');
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map) {
        final errorData = data['error'] is Map
            ? Map<String, dynamic>.from(data['error'] as Map)
            : data;
        final activeCount = errorData['activeOrderCount'];
        if (activeCount != null) {
          throw Exception(
            data['message']?.toString() ??
                'Cannot go offline with $activeCount active deliveries',
          );
        }
      }
      throw Exception(
        'Failed to update status: ${e.response?.data?['message'] ?? e.message}',
      );
    }
  }

  Future<void> reportOperationalException(
    String orderId,
    String exceptionType, {
    String? notes,
  }) async {
    try {
      final res = await _api.post(
        ApiDeliveryPaths.orderOperationalException(orderId),
        data: {
          'exceptionType': exceptionType,
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
      );
      if (res.data['success'] != true) {
        throw Exception(res.data['message'] ?? 'Failed to report exception');
      }
    } on DioException catch (e) {
      throw Exception(
        _extractApiMessage(e, 'Failed to report operational exception'),
      );
    }
  }

  // ── Orders ────────────────────────────────────────────────────────────────

  /// Get orders assigned to the logged-in delivery partner.
  Future<List<Map<String, dynamic>>> getRiderOrders({String? status}) async {
    final orders = await _fetchAssignedOrdersRaw(status: status);
    return orders.map(_toLegacyAssignment).toList();
  }

  Future<List<OrderModel>> getAssignedOrders({String? status}) async {
    try {
      final orders = await _fetchAssignedOrdersRaw(status: status);
      return orders.map(OrderModel.fromJson).toList();
    } on DioException catch (e) {
      await ErrorTrackingService.captureException(e, tag: 'rider_get_orders');
      _throwDeliveryApiError(e, 'Failed to get rider orders');
    } on RoleAccessException {
      rethrow;
    } catch (e, st) {
      await ErrorTrackingService.captureException(e, stackTrace: st, tag: 'rider_get_orders');
      throw Exception('Failed to get rider orders: $e');
    }
  }

  // ── Accept / Status updates ───────────────────────────────────────────────

  /// Accept an order assignment.
  /// [assignmentId] is treated as the orderId for the backend endpoint.
  Future<void> acceptOrder(String assignmentId) async {
    await acceptOrders([assignmentId]);
  }

  /// Accept one or more order assignments (batch delivery).
  ///
  /// Uses legacy [ApiDeliveryPaths.orderAccept] — PACKED → OUT_FOR_DELIVERY in one
  /// step. Enhanced `/orders/enhanced/:id/accept` (RIDER_ASSIGNED → RIDER_ACCEPTED)
  /// is not used.
  Future<void> acceptOrders(List<String> orderIds) async {
    if (orderIds.isEmpty) {
      throw Exception('No orders to accept');
    }

    final accepted = <String>[];
    try {
      for (final orderId in orderIds) {
        final res = await _api.post(ApiDeliveryPaths.orderAccept(orderId));
        if (res.data['success'] != true) {
          throw Exception(res.data['message'] ?? 'Failed to accept order $orderId');
        }
        accepted.add(orderId);
      }
      _activeOrderId = orderIds.first;
      _updateDeliveryState('OUT_FOR_DELIVERY');
      _invalidateOrdersCache();
    } on DioException catch (e) {
      if (accepted.isNotEmpty) {
        _invalidateOrdersCache();
      }
      throw Exception(
          'Failed to accept order: ${e.response?.data?['message'] ?? e.message}');
    } catch (e) {
      if (accepted.isNotEmpty) {
        _invalidateOrdersCache();
      }
      throw Exception('Failed to accept order: $e');
    }
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    final normalized = status.trim().toUpperCase().replaceAll(' ', '_');
    const allowed = {
      'OUT_FOR_DELIVERY',
      'PICKED_UP',
      'ON_THE_WAY',
      'DELIVERED',
    };
    if (!allowed.contains(normalized)) {
      throw Exception('Unsupported order status update: $status');
    }

    try {
      final res = await _api.patch(
        ApiDeliveryPaths.orderStatus(orderId),
        data: {'status': normalized},
      );
      if (res.data['success'] != true) {
        throw Exception(res.data['message'] ?? 'Failed to update order status');
      }
      _updateDeliveryState(normalized);
      _invalidateOrdersCache();
    } on DioException catch (e) {
      throw Exception(
          'Failed to update order status: ${e.response?.data?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to update order status: $e');
    }
  }

  Future<void> updateStatus(String orderId, String status) async {
    await updateOrderStatus(orderId, status);
  }

  Future<void> rejectOrder(String assignmentId, [String reason = '']) async {
    await rejectOrders([assignmentId], reason);
  }

  Future<void> rejectOrders(List<String> orderIds, [String reason = '']) async {
    if (orderIds.isEmpty) {
      throw Exception('No orders to reject');
    }

    for (final orderId in orderIds) {
      try {
        final res = await _api.post(
          ApiDeliveryPaths.orderReject(orderId),
          data: {
            if (reason.trim().isNotEmpty) 'reason': reason.trim(),
          },
        );
        if (res.data['success'] != true) {
          throw Exception(res.data['message'] ?? 'Failed to reject order $orderId');
        }
      } on DioException catch (e) {
        throw Exception(
            'Failed to reject order: ${e.response?.data?['message'] ?? e.message}');
      }
    }
    _updateDeliveryState('CANCELLED');
    _invalidateOrdersCache();
  }

  Future<void> markOrderPickedUp(String assignmentId) async {
    _activeOrderId = assignmentId;
    await updateOrderStatus(assignmentId, 'PICKED_UP');
  }

  Future<void> markOrderOnTheWay(String assignmentId) async {
    _activeOrderId = assignmentId;
    await updateOrderStatus(assignmentId, 'ON_THE_WAY');
  }

  Future<void> markOrderDelivered(
    String orderId, {
    required String otp,
  }) async {
    final trimmedOtp = otp.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(trimmedOtp)) {
      throw Exception('Please enter the 6-digit delivery OTP from the customer');
    }

    try {
      final res = await _api.patch(
        ApiDeliveryPaths.orderStatus(orderId),
        data: {'status': 'DELIVERED', 'otp': trimmedOtp},
      );
      if (res.data['success'] != true) {
        throw Exception(res.data['message'] ?? 'Failed to mark delivered');
      }
      _updateDeliveryState('DELIVERED');
      _invalidateOrdersCache();
    } on DioException catch (e) {
      _throwDeliveryApiError(e, 'Failed to mark delivered');
    }
  }

  Future<void> markFailedDelivery(
    String orderId,
    String reason,
  ) async {
    try {
      final res = await _api.post(
        ApiDeliveryPaths.orderFailedDelivery(orderId),
        data: {'reason': reason},
      );
      if (res.data['success'] != true) {
        throw Exception(res.data['message'] ?? 'Failed to mark failed delivery');
      }
      _locationService.stopSendingLocation();
      _invalidateOrdersCache();
    } on DioException catch (e) {
      throw Exception(
        _extractApiMessage(e, 'Failed to mark failed delivery'),
      );
    }
  }

  Future<void> confirmReturnToStore(
    String orderId,
    String returnCondition,
  ) async {
    try {
      final res = await _api.post(
        ApiDeliveryPaths.orderReturnToStore(orderId),
        data: {'returnCondition': returnCondition},
      );
      if (res.data['success'] != true) {
        throw Exception(res.data['message'] ?? 'Failed to confirm return');
      }
      _invalidateOrdersCache();
    } on DioException catch (e) {
      throw Exception(
        _extractApiMessage(e, 'Failed to confirm return to store'),
      );
    }
  }

  // ── Earnings ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _fetchEarningsPeriod(String period) async {
    return _extractMap(
      await _api.get(
        ApiDeliveryPaths.earnings,
        queryParameters: {'period': period},
      ),
      'Failed to get rider earnings',
    );
  }

  Future<EarningsData> getEarnings({String period = 'today'}) async {
    try {
      final data = await _fetchEarningsPeriod(period);
      return EarningsData.fromApi(
        todayData: data,
        weekData: data,
        monthData: data,
      );
    } on DioException catch (e) {
      await ErrorTrackingService.captureException(e, tag: 'rider_earnings');
      throw Exception(
        'Failed to get rider earnings: ${e.response?.data?['message'] ?? e.message}',
      );
    } catch (e, st) {
      await ErrorTrackingService.captureException(e, stackTrace: st, tag: 'rider_earnings');
      throw Exception('Failed to get rider earnings: $e');
    }
  }

  Future<EarningsData> getRiderEarnings({double? lifetimeTotal}) async {
    try {
      final results = await Future.wait([
        _fetchEarningsPeriod('today'),
        _fetchEarningsPeriod('week'),
        _fetchEarningsPeriod('month'),
      ]);
      return EarningsData.fromApi(
        todayData: results[0],
        weekData: results[1],
        monthData: results[2],
        lifetimeTotal: lifetimeTotal,
      );
    } on DioException catch (e) {
      await ErrorTrackingService.captureException(e, tag: 'rider_earnings');
      throw Exception(
        'Failed to get rider earnings: ${e.response?.data?['message'] ?? e.message}',
      );
    } catch (e, st) {
      await ErrorTrackingService.captureException(e, stackTrace: st, tag: 'rider_earnings');
      throw Exception('Failed to get rider earnings: $e');
    }
  }

  // ── Vehicle details ───────────────────────────────────────────────────────

  Future<void> updateVehicleDetails({
    required String vehicleType,
    required String vehicleNumber,
    required String licenseNumber,
  }) async {
    try {
      final res = await _api.patch(
        ApiDeliveryPaths.updateProfile,
        data: {
          'vehicle': vehicleType.trim(),
          'vehicleNumber': vehicleNumber.trim(),
          'licenceNumber': licenseNumber.trim(),
        },
      );
      final payload = res.data;
      if (payload is Map && payload['success'] == false) {
        throw Exception(payload['message'] ?? 'Failed to update vehicle details');
      }
    } on DioException catch (e) {
      throw Exception(
        'Failed to update vehicle details: ${e.response?.data?['message'] ?? e.message}',
      );
    }
  }

  Future<void> updateRiderLocation({
    required double latitude,
    required double longitude,
  }) async {
    await updateLocation(latitude, longitude);
  }

  Future<void> updateLocation(
    double lat,
    double lng, {
    String? orderId,
  }) async {
    if (orderId != null) {
      _activeOrderId = orderId;
    }
    try {
      final parsedOrderId = orderId != null ? int.tryParse(orderId) : null;
      await _api.put(
        ApiDeliveryPaths.location,
        data: {
          'lat': lat,
          'lng': lng,
          if (parsedOrderId != null)
            'orderId': parsedOrderId
          else if (orderId != null)
            'orderId': orderId,
        },
      );
    } on DioException catch (e) {
      debugPrint(
        'Failed to update rider location: ${e.response?.data?['message'] ?? e.message}',
      );
    } catch (e) {
      debugPrint('Failed to update rider location: $e');
    }
  }

  // ── Assignment detail ──────────────────────────────────────────────────────

  /// Whether the order is packed and ready for rider acceptance.
  Future<bool> isOrderReadyForAccept(
    String orderId, {
    bool forceRefresh = false,
  }) async {
    try {
      final assignment = await getOrderAssignment(
        orderId,
        forceRefresh: forceRefresh,
      );
      final order = assignment['order'] as Map<String, dynamic>?;
      final status = _normalizeStatus(order?['status'], fallback: '');
      return status == 'packed';
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getOrderAssignment(
    String assignmentId, {
    bool forceRefresh = false,
  }) async {
    try {
      final raw = _extractMap(
        await _api.get(ApiDeliveryPaths.orderById(assignmentId)),
        'Failed to fetch order',
      );
      return _toLegacyAssignment(_normalizeOrder(raw));
    } on DioException catch (e) {
      if (e.response?.statusCode != 404 && e.response?.statusCode != 403) {
        _throwDeliveryApiError(e, 'Failed to fetch order');
      }
    } on RoleAccessException {
      rethrow;
    } catch (e) {
      if (e is Exception && e.toString().contains('Failed to fetch order')) {
        rethrow;
      }
    }

    final orders = await _fetchAssignedOrdersRaw(forceRefresh: forceRefresh);
    final matchedOrder =
        orders.where((o) => o['id']?.toString() == assignmentId);
    if (matchedOrder.isNotEmpty) {
      return _toLegacyAssignment(matchedOrder.first);
    }

    throw Exception('Order not found or not assigned to you');
  }

  // ── Realtime polling ──────────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> watchNewOrdersRaw() {
    return Stream.periodic(const Duration(seconds: 10)).asyncMap((_) async {
      try {
        return await _fetchAssignedOrdersRaw();
      } on RoleAccessException {
        rethrow;
      } catch (_) {
        return <Map<String, dynamic>>[];
      }
    });
  }

  Stream<List<OrderModel>> watchNewOrders() {
    return Stream.periodic(const Duration(seconds: 10)).asyncMap((_) async {
      try {
        return await getAssignedOrders();
      } on RoleAccessException {
        rethrow;
      } catch (_) {
        return <OrderModel>[];
      }
    });
  }

  Future<void> subscribeToOrderAssignments({
    required Function(Map<String, dynamic> assignment) onNewAssignment,
    Function()? onAssignmentUpdated,
    void Function(RoleAccessException error)? onRoleAccessDenied,
  }) async {
    await _newOrdersSubscription?.cancel();

    final seenOrderIds = <String>{};
    void handleOrders(List<Map<String, dynamic>> orders) {
      final currentIds = orders
          .map((order) => order['id']?.toString())
          .whereType<String>()
          .toSet();
      final hasChanges =
          seenOrderIds.isNotEmpty && !setEquals(seenOrderIds, currentIds);

      if (seenOrderIds.isNotEmpty) {
        for (final order in orders.where(
          (item) => !seenOrderIds.contains(item['id']?.toString()),
        )) {
          onNewAssignment(_toLegacyAssignment(order));
        }
        if (hasChanges) {
          onAssignmentUpdated?.call();
        }
      }

      seenOrderIds
        ..clear()
        ..addAll(currentIds);
    }

    try {
      final initialOrders = await _fetchAssignedOrdersRaw();
      handleOrders(initialOrders);
    } on RoleAccessException catch (error) {
      onRoleAccessDenied?.call(error);
      return;
    } catch (error) {
      debugPrint('Initial order assignment sync failed: $error');
    }

    _newOrdersSubscription = watchNewOrdersRaw().listen(
      handleOrders,
      onError: (Object error) {
        if (error is RoleAccessException) {
          unsubscribeFromOrderAssignments();
          onRoleAccessDenied?.call(error);
          return;
        }
        debugPrint('Order assignment stream error: $error');
      },
    );
  }

  void unsubscribeFromOrderAssignments() {
    _newOrdersSubscription?.cancel();
    _newOrdersSubscription = null;
  }

  // Location tracking now handled by RiderLocationService
  // Using smart batching: updates on 50m movement OR 30s max interval

  void _updateDeliveryState(String status) {
    final normalized = status.trim().toUpperCase();
    _isOnDelivery = normalized == 'OUT_FOR_DELIVERY' ||
        normalized == 'PICKED_UP' ||
        normalized == 'ON_THE_WAY';
    if (!_isOnDelivery) {
      _activeOrderId = null;
      _locationService.stopSendingLocation();
    } else if (_activeOrderId != null) {
      _locationService.startSendingLocation(_activeOrderId!);
    }
  }

  void disposeRealtime() {
    unsubscribeFromOrderAssignments();
    _locationService.stopSendingLocation();
    _ordersCache = null;
    _ordersCacheAt = null;
  }
}
