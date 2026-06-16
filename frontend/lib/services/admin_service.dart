import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart' show ApiAdminPaths, ApiDeliveryPaths;
import 'api_service.dart';
import 'error_tracking_service.dart';
import 'product_service.dart';

/// Admin service — custom Node.js backend (role: ADMIN required)
final adminServiceProvider = Provider<AdminService>((ref) {
  return AdminService(ref.read(apiServiceProvider));
});

class AdminService {
  final ApiService _api;

  AdminService([ApiService? api]) : _api = api ?? ApiService();

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
      for (final key in const ['orders', 'products', 'users', 'items']) {
        final value = map[key];
        if (value is List) {
          return List<Map<String, dynamic>>.from(
            value.map((e) => Map<String, dynamic>.from(e as Map)),
          );
        }
      }
      if (map.isEmpty) return [];
    }
    throw Exception(fallbackMessage);
  }

  String _formatApiDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  dynamic _firstNonNull(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value != null) return value;
    }
    return null;
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _normalizeRole(dynamic role) {
    final normalized = (role ?? 'customer').toString().toLowerCase();
    if (normalized == 'delivery' || normalized == 'rider') {
      return 'delivery_partner';
    }
    return normalized;
  }

  bool _roleMatchesFilter(String userRole, String filterRole) {
    final normalizedUserRole = _normalizeRole(userRole);
    final normalizedFilter = _normalizeRole(filterRole);
    return normalizedUserRole == normalizedFilter;
  }

  Map<String, dynamic> normalizeUser(Map<String, dynamic> raw) {
    final role = _normalizeRole(raw['role']);
    final createdAt = raw['created_at'] ?? raw['createdAt'];
    String? createdAtIso;
    if (createdAt is String) {
      createdAtIso = createdAt;
    } else if (createdAt is int) {
      createdAtIso = DateTime.fromMillisecondsSinceEpoch(createdAt).toIso8601String();
    } else if (createdAt != null) {
      createdAtIso = DateTime.tryParse(createdAt.toString())?.toIso8601String();
    }

    return {
      ...raw,
      'id': (raw['id'] ?? raw['uid'] ?? '').toString(),
      'role': role,
      'is_active': raw['is_active'] == true ||
          raw['isActive'] == true ||
          (raw['is_active'] == null && raw['isActive'] == null),
      'order_count': _asInt(raw['order_count'] ?? raw['orderCount']),
      'lifetime_value': _asDouble(raw['lifetime_value'] ?? raw['lifetimeValue']),
      if (createdAtIso != null) 'created_at': createdAtIso,
    };
  }

  String _normalizeOrderStatusForUi(dynamic status) {
    final value = (status ?? '').toString().trim().toUpperCase();
    if (value.isEmpty) return '';
    switch (value) {
      case 'CONFIRMED':
        return 'accepted';
      case 'OUT_FOR_DELIVERY':
        return 'on_way';
      case 'ASSIGNED':
        return 'assigned';
      default:
        return value.toLowerCase();
    }
  }

  String _mapOrderStatusToBackend(String status) {
    switch (status.toLowerCase()) {
      case 'placed':
        return 'PLACED';
      case 'accepted':
      case 'confirmed':
        return 'CONFIRMED';
      case 'assigned':
        return 'ASSIGNED';
      case 'on_way':
      case 'out_for_delivery':
        return 'OUT_FOR_DELIVERY';
      case 'delivered':
        return 'DELIVERED';
      case 'cancelled':
        return 'CANCELLED';
      case 'packed':
        return 'PACKED';
      default:
        return status.toUpperCase();
    }
  }

  Map<String, dynamic> normalizeOrder(Map<String, dynamic> raw) {
    final createdAtRaw = raw['created_at'] ?? raw['createdAt'];
    String createdAtIso;
    if (createdAtRaw is String && createdAtRaw.isNotEmpty) {
      createdAtIso = DateTime.tryParse(createdAtRaw)?.toIso8601String() ??
          createdAtRaw;
    } else if (createdAtRaw is int) {
      createdAtIso =
          DateTime.fromMillisecondsSinceEpoch(createdAtRaw).toIso8601String();
    } else if (createdAtRaw is num) {
      createdAtIso =
          DateTime.fromMillisecondsSinceEpoch(createdAtRaw.toInt()).toIso8601String();
    } else {
      createdAtIso = DateTime.now().toIso8601String();
    }

    final customerName =
        (raw['customerName'] ?? raw['customer_name'] ?? '').toString();
    final phone = (raw['phone'] ?? '').toString();
    final deliveryUid =
        (raw['deliveryUid'] ?? raw['delivery_uid'] ?? '').toString();

    Map<String, dynamic>? assignment;
    final assignmentData = raw['assignment'];
    if (assignmentData is Map) {
      assignment = Map<String, dynamic>.from(assignmentData);
    } else if (deliveryUid.isNotEmpty) {
      assignment = {
        'rider': {
          'id': deliveryUid,
          'user': {
            'name': 'Rider',
            'phone': '',
          },
        },
      };
    }

    final user = raw['user'] is Map
        ? Map<String, dynamic>.from(raw['user'] as Map)
        : <String, dynamic>{
            'name': customerName.isNotEmpty ? customerName : 'Customer',
            'phone': phone.isNotEmpty ? phone : 'N/A',
          };

    return {
      ...raw,
      'id': (raw['id'] ?? '').toString(),
      'status': _normalizeOrderStatusForUi(raw['status']),
      'total_price': _asDouble(raw['total_price'] ?? raw['totalAmount'] ?? raw['total_amount']),
      'created_at': createdAtIso,
      'user': user,
      'items': raw['items'] is List
          ? List<Map<String, dynamic>>.from(
              (raw['items'] as List).map((item) {
                final map = Map<String, dynamic>.from(item as Map);
                final product = map['product'];
                if (product is! Map && map['name'] != null) {
                  map['product'] = {'name': map['name']};
                }
                return map;
              }),
            )
          : <Map<String, dynamic>>[],
      if (assignment != null) 'assignment': assignment,
    };
  }

  // ── Image upload ──────────────────────────────────────────────────────────

  Future<String> uploadImage(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Image file nahi mili');
      }

      final filename = filePath.replaceAll('\\', '/').split('/').last;

      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          filePath,
          filename: filename.isEmpty ? 'image.jpg' : filename,
        ),
      });

      final data = _extractMap(
        await _api.postMultipart(ApiAdminPaths.uploadImage, formData),
        'Image upload fail hua',
      );

      final url = (data['url'] ?? data['path'] ?? '').toString().trim();
      if (url.isEmpty) {
        throw Exception('Upload response mein URL nahi mila');
      }
      return url;
    } on DioException catch (e) {
      throw Exception(
        'Image upload fail: ${e.response?.data?['message'] ?? e.message}',
      );
    } catch (e) {
      throw Exception('Image upload fail: $e');
    }
  }

  // ── Dashboard ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDashboard() async {
    try {
      final payload = _extractMap(
        await _api.get(ApiAdminPaths.dashboard),
        'Failed to get dashboard',
      );
      final data = payload['stats'] is Map
          ? Map<String, dynamic>.from(payload['stats'] as Map)
          : payload;
      final todayOrders =
          _asInt(_firstNonNull(data, ['todayOrders', 'today_orders']));
      final totalOrders =
          _asInt(_firstNonNull(data, ['totalOrders', 'total_orders']));
      final activeRiders = _asInt(_firstNonNull(
        data,
        ['activeRiders', 'active_riders', 'totalDeliveryPartners', 'total_delivery_partners'],
      ));
      final totalProducts =
          _asInt(_firstNonNull(data, ['totalProducts', 'total_products']));
      final totalUsers = _asInt(_firstNonNull(
        data,
        ['totalUsers', 'total_users', 'totalCustomers', 'total_customers'],
      ));
      final liveOrders =
          _asInt(_firstNonNull(data, ['liveOrders', 'live_orders']));
      final totalCustomers =
          _asInt(_firstNonNull(data, ['totalCustomers', 'total_customers']));
      final totalDeliveryPartners = _asInt(_firstNonNull(
        data,
        ['totalDeliveryPartners', 'total_delivery_partners'],
      ));
      final todayRevenue =
          _asDouble(_firstNonNull(data, ['todayRevenue', 'today_revenue']));
      final totalRevenue = _asDouble(_firstNonNull(
        data,
        ['totalRevenue', 'total_revenue', 'revenue', 'deliveredRevenue', 'delivered_revenue'],
      ));
      final revenue = _asDouble(_firstNonNull(
        data,
        ['revenue', 'totalRevenue', 'total_revenue', 'deliveredRevenue', 'delivered_revenue'],
      ));
      final deliveredRevenue = _asDouble(_firstNonNull(
        data,
        ['deliveredRevenue', 'delivered_revenue', 'totalRevenue', 'total_revenue', 'revenue'],
      ));

      // Normalize field names for existing UI
      return {
        ...data,
        'todayOrders': todayOrders,
        'today_orders': todayOrders,
        'totalOrders': totalOrders,
        'total_orders': totalOrders,
        'activeRiders': activeRiders,
        'active_riders': activeRiders,
        'totalProducts': totalProducts,
        'total_products': totalProducts,
        'totalUsers': totalUsers,
        'total_users': totalUsers,
        'liveOrders': liveOrders,
        'live_orders': liveOrders,
        'totalCustomers': totalCustomers,
        'total_customers': totalCustomers,
        'totalDeliveryPartners': totalDeliveryPartners,
        'total_delivery_partners': totalDeliveryPartners,
        'todayRevenue': todayRevenue,
        'today_revenue': todayRevenue,
        'totalRevenue': totalRevenue,
        'total_revenue': totalRevenue,
        'revenue': revenue,
        'deliveredRevenue': deliveredRevenue,
        'delivered_revenue': deliveredRevenue,
      };
    } on DioException catch (e) {
      await ErrorTrackingService.captureException(e, tag: 'admin_dashboard');
      throw Exception(
          'Failed to get dashboard: ${e.response?.data?['message'] ?? e.message}');
    } catch (e, st) {
      await ErrorTrackingService.captureException(e, stackTrace: st, tag: 'admin_dashboard');
      throw Exception('Failed to get dashboard: $e');
    }
  }

  Future<Map<String, dynamic>> getDashboardStats() => getDashboard();

  // ── Orders ────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getOrders([
    DateTime? fromDate,
    DateTime? toDate,
  ]) async {
    try {
      final params = <String, dynamic>{};
      if (fromDate != null) params['from'] = _formatApiDate(fromDate);
      if (toDate != null) params['to'] = _formatApiDate(toDate);

      return _extractList(
        await _api.get(
          ApiAdminPaths.orders,
          queryParameters: params.isEmpty ? null : params,
        ),
        'Failed to get orders',
      ).map(normalizeOrder).toList();
    } on DioException catch (e) {
      await ErrorTrackingService.captureException(e, tag: 'admin_get_orders');
      throw Exception(
          'Failed to get orders: ${e.response?.data?['message'] ?? e.message}');
    } catch (e, st) {
      await ErrorTrackingService.captureException(e, stackTrace: st, tag: 'admin_get_orders');
      throw Exception('Failed to get orders: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAllOrders({
    String? status,
    int? page,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      var orders = await getOrders(fromDate, toDate);
      if (status != null && status.isNotEmpty) {
        final normalizedStatus = status.toLowerCase();
        orders = orders
            .where((order) =>
                (order['status'] ?? '').toString().toLowerCase() ==
                normalizedStatus)
            .toList();
      }
      if (page != null && page > 0) {
        const pageSize = 20;
        final start = (page - 1) * pageSize;
        if (start >= orders.length) return [];
        final end = (start + pageSize) > orders.length
            ? orders.length
            : start + pageSize;
        orders = orders.sublist(start, end);
      }
      return orders;
    } on DioException catch (e) {
      await ErrorTrackingService.captureException(e, tag: 'admin_get_all_orders');
      throw Exception(
          'Failed to get orders: ${e.response?.data?['message'] ?? e.message}');
    } catch (e, st) {
      await ErrorTrackingService.captureException(e, stackTrace: st, tag: 'admin_get_all_orders');
      throw Exception('Failed to get orders: $e');
    }
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      final backendStatus = _mapOrderStatusToBackend(status);
      final res = await _api.patch(
        '${ApiAdminPaths.orders}/$orderId/status',
        data: {'status': backendStatus},
      );
      if (res.data['success'] != true) {
        throw Exception(res.data['message'] ?? 'Failed to update order status');
      }
    } on DioException catch (e) {
      throw Exception(
          'Failed to update order status: ${e.response?.data?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to update order status: $e');
    }
  }

  // ── Riders / Partners ─────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAllRiders() async {
    try {
      final res = await _api.get(ApiAdminPaths.deliveryPartners);
      if (res.data['success'] != true) {
        throw Exception(res.data['message'] ?? 'Failed to get riders');
      }
      final data = res.data['data'];
      final rawList = data is List
          ? data
          : (data is Map ? (data['partners'] as List?) : null) ?? [];
      return List<Map<String, dynamic>>.from(
        rawList.map((e) {
          final partner = Map<String, dynamic>.from(e as Map);
          final profile = partner['profile'] is Map
              ? Map<String, dynamic>.from(partner['profile'] as Map)
              : <String, dynamic>{};
          return {
            'id': partner['id']?.toString() ?? '',
            'phone': partner['phone'] ?? profile['phone'] ?? '',
            'profile': profile,
            'user': {
              'name': profile['name'] ?? partner['name'] ?? 'Rider',
              'phone': partner['phone'] ?? profile['phone'] ?? '',
            },
          };
        }),
      );
    } on DioException catch (e) {
      throw Exception(
          'Failed to get riders: ${e.response?.data?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to get riders: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getDeliveryPartners() async {
    try {
      final res = await _api.get(ApiAdminPaths.deliveryPartners);
      if (res.data['success'] != true) {
        throw Exception(res.data['message'] ?? 'Failed to get delivery partners');
      }
      final data = res.data['data'];
      final rawList = data is List
          ? data
          : (data is Map ? (data['partners'] as List?) : null) ?? [];
      return List<Map<String, dynamic>>.from(
        rawList.map((e) => Map<String, dynamic>.from(e as Map)),
      );
    } on DioException catch (e) {
      throw Exception(
          'Failed to get delivery partners: ${e.response?.data?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to get delivery partners: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAvailableRiders() async =>
      getAllRiders();

  Future<List<Map<String, dynamic>>> getAllPartners() async =>
      getAllRiders();

  // ── Users / Customers ─────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      final users = _extractList(
        await _api.get(ApiAdminPaths.users),
        'Failed to get users',
      );
      return users.map(normalizeUser).toList();
    } on DioException catch (e) {
      await ErrorTrackingService.captureException(e, tag: 'admin_get_users');
      throw Exception(
          'Failed to get users: ${e.response?.data?['message'] ?? e.message}');
    } catch (e, st) {
      await ErrorTrackingService.captureException(e, stackTrace: st, tag: 'admin_get_users');
      throw Exception('Failed to get users: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAllUsers({
    String? role,
    String? search,
    bool? isActive,
  }) async {
    try {
      var users = await getUsers();

      // Client-side filtering (backend may not support all params)
      if (role != null && role.isNotEmpty) {
        users = users
            .where((u) => _roleMatchesFilter(u['role']?.toString() ?? '', role))
            .toList();
      }
      if (search != null && search.isNotEmpty) {
        final q = search.toLowerCase();
        users = users
            .where((u) =>
                (u['name'] ?? '').toString().toLowerCase().contains(q) ||
                (u['phone'] ?? '').toString().contains(q) ||
                (u['email'] ?? '').toString().toLowerCase().contains(q))
            .toList();
      }
      if (isActive != null) {
        users = users
            .where((u) => (u['is_active'] as bool?) == isActive)
            .toList();
      }
      return users;
    } on DioException catch (e) {
      await ErrorTrackingService.captureException(e, tag: 'admin_get_all_users');
      throw Exception(
          'Failed to get users: ${e.response?.data?['message'] ?? e.message}');
    } catch (e, st) {
      await ErrorTrackingService.captureException(e, stackTrace: st, tag: 'admin_get_all_users');
      throw Exception('Failed to get users: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAllCustomers() async {
    return getAllUsers();
  }

  // ── Products ──────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getProducts() async {
    try {
      return _extractList(
        await _api.get(ApiAdminPaths.products),
        'Failed to load products',
      );
    } on DioException catch (e) {
      await ErrorTrackingService.captureException(e, tag: 'admin_get_products');
      throw Exception(
          'Failed to load products: ${e.response?.data?['message'] ?? e.message}');
    } catch (e, st) {
      await ErrorTrackingService.captureException(e, stackTrace: st, tag: 'admin_get_products');
      throw Exception('Failed to load products: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAdminProducts({
    String? search,
    String? category,
    bool showOnlyActive = false,
  }) async {
    try {
      var products = await getProducts();
      if (search != null && search.isNotEmpty) {
        final q = search.toLowerCase();
        products = products
            .where((product) =>
                (product['name'] ?? '').toString().toLowerCase().contains(q))
            .toList();
      }
      if (category != null && category.isNotEmpty) {
        final normalizedCategory = category.toLowerCase();
        products = products
            .where((product) =>
                (product['category'] ?? '').toString().toLowerCase() ==
                normalizedCategory)
            .toList();
      }
      if (showOnlyActive) {
        products = products
            .where((product) => product['is_active'] == true)
            .toList();
      }
      return products;
    } on DioException catch (e) {
      await ErrorTrackingService.captureException(e, tag: 'admin_get_products');
      throw Exception(
          'Failed to load products: ${e.response?.data?['message'] ?? e.message}');
    } catch (e, st) {
      await ErrorTrackingService.captureException(e, stackTrace: st, tag: 'admin_get_products');
      throw Exception('Failed to load products: $e');
    }
  }

  Map<String, dynamic> normalizeAdminProduct(Map<String, dynamic> raw) {
    final stock = raw['stockQty'] ?? raw['stock'] ?? raw['stock_qty'] ?? 0;
    return {
      'id': (raw['id'] ?? '').toString(),
      'name': raw['name'] ?? '',
      'categoryId': (raw['categoryId'] ?? raw['category_id'] ?? '').toString(),
      'price': _asDouble(raw['price'] ?? raw['basePricePerKg'] ?? raw['base_price_per_kg']),
      'stockQty': _asInt(stock),
      'imageUrl': (raw['imageUrl'] ?? raw['image_url'] ?? '').toString(),
      'description': (raw['description'] ?? '').toString(),
      'unit': (raw['unit'] ?? 'kg').toString(),
      'isActive': raw['isActive'] == true ||
          raw['active'] == true ||
          raw['is_active'] == true,
      'inStock': raw['inStock'] == true ||
          raw['in_stock'] == true ||
          _asInt(stock) > 0,
    };
  }

  Future<List<Map<String, dynamic>>> getAdminProductsNormalized() async {
    final rows = await getProducts();
    return rows.map(normalizeAdminProduct).toList();
  }

  Future<Map<String, dynamic>> createProduct({
    Map<String, dynamic>? data,
    required String name,
    required double price,
    String? categoryId,
    String unit = 'kg',
    int? stockQty,
    String? description,
    String? imageUrl,
    bool isActive = true,
  }) async {
    try {
      final payload = data ??
          <String, dynamic>{
            'name': name,
            'price': price,
            if (categoryId != null && categoryId.isNotEmpty) 'categoryId': categoryId,
            'unit': unit,
            if (stockQty != null) 'stockQty': stockQty,
            if (description != null && description.isNotEmpty) 'description': description,
            if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
            'isActive': isActive,
          };

      final createdProduct = normalizeAdminProduct(_extractMap(
        await _api.post(ApiAdminPaths.products, data: payload),
        'Failed to create product',
      ));
      await ProductService.clearProductCache();
      return createdProduct;
    } on DioException catch (e) {
      throw Exception(
          'Failed to create product: ${e.response?.data?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to create product: $e');
    }
  }

  Future<void> updateProduct(
    String productId, {
    Map<String, dynamic>? data,
    String? name,
    double? price,
    String? categoryId,
    String? description,
    String? unit,
    int? stockQty,
    String? imageUrl,
    bool? isActive,
  }) async {
    try {
      final updates = data != null ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (price != null) updates['price'] = price;
      if (categoryId != null) updates['categoryId'] = categoryId;
      if (description != null) updates['description'] = description;
      if (unit != null) updates['unit'] = unit;
      if (stockQty != null) updates['stockQty'] = stockQty;
      if (imageUrl != null) updates['imageUrl'] = imageUrl;
      if (isActive != null) updates['isActive'] = isActive;

      if (updates.isEmpty) throw Exception('No fields to update');

      _extractMap(
        await _api.patch('${ApiAdminPaths.products}/$productId', data: updates),
        'Failed to update product',
      );
      await ProductService.clearProductCache();
    } on DioException catch (e) {
      throw Exception(
          'Failed to update product: ${e.response?.data?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to update product: $e');
    }
  }

  Future<void> updateProductStock(String productId, int stock) async {
    try {
      _extractMap(
        await _api.patch(
          '${ApiAdminPaths.products}/$productId/stock',
          data: {'stock': stock},
        ),
        'Failed to update stock',
      );
      await ProductService.clearProductCache();
    } on DioException catch (e) {
      throw Exception(
          'Failed to update stock: ${e.response?.data?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to update stock: $e');
    }
  }

  Future<void> setProductAvailability(String productId, bool isActive) =>
      updateProduct(productId, isActive: isActive);

  Future<void> deleteProduct(String productId) async {
    try {
      _unwrapResponseData(
        await _api.delete('${ApiAdminPaths.products}/$productId'),
        'Failed to delete product',
      );
      await ProductService.clearProductCache();
    } on DioException catch (e) {
      throw Exception(
          'Failed to delete product: ${e.response?.data?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to delete product: $e');
    }
  }

  // ── Categories ────────────────────────────────────────────────────────────

  Map<String, dynamic> normalizeAdminCategory(Map<String, dynamic> raw) {
    return {
      'id': (raw['id'] ?? '').toString(),
      'name': raw['name'] ?? '',
      'imageUrl': (raw['imageUrl'] ?? raw['image_url'] ?? '').toString(),
      'isActive': raw['isActive'] == true ||
          raw['active'] == true ||
          raw['is_active'] == true,
      'sortOrder': _asInt(raw['sortOrder'] ?? raw['sort_order'] ?? 0),
    };
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final rows = _extractList(
        await _api.get(ApiAdminPaths.categories),
        'Failed to load categories',
      );
      return rows.map(normalizeAdminCategory).toList()
        ..sort((a, b) => _asInt(a['sortOrder']).compareTo(_asInt(b['sortOrder'])));
    } on DioException catch (e) {
      throw Exception(
          'Failed to load categories: ${e.response?.data?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to load categories: $e');
    }
  }

  Future<Map<String, dynamic>> createCategory({
    required String name,
    String? imageUrl,
    bool isActive = true,
    int sortOrder = 0,
  }) async {
    try {
      final created = normalizeAdminCategory(_extractMap(
        await _api.post(
          ApiAdminPaths.categories,
          data: {
            'name': name,
            if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
            'isActive': isActive,
            'sortOrder': sortOrder,
          },
        ),
        'Failed to create category',
      ));
      await ProductService.clearProductCache();
      return created;
    } on DioException catch (e) {
      throw Exception(
          'Failed to create category: ${e.response?.data?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to create category: $e');
    }
  }

  Future<void> updateCategory(
    String categoryId, {
    String? name,
    String? imageUrl,
    bool? isActive,
    int? sortOrder,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (name != null) payload['name'] = name;
      if (imageUrl != null) payload['imageUrl'] = imageUrl;
      if (isActive != null) payload['isActive'] = isActive;
      if (sortOrder != null) payload['sortOrder'] = sortOrder;
      if (payload.isEmpty) throw Exception('No fields to update');

      _extractMap(
        await _api.patch('${ApiAdminPaths.categories}/$categoryId', data: payload),
        'Failed to update category',
      );
      await ProductService.clearProductCache();
    } on DioException catch (e) {
      throw Exception(
          'Failed to update category: ${e.response?.data?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to update category: $e');
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    try {
      _unwrapResponseData(
        await _api.delete('${ApiAdminPaths.categories}/$categoryId'),
        'Failed to delete category',
      );
      await ProductService.clearProductCache();
    } on DioException catch (e) {
      throw Exception(
          'Failed to delete category: ${e.response?.data?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to delete category: $e');
    }
  }

  // ── Banners ───────────────────────────────────────────────────────────────

  Map<String, dynamic> normalizeAdminBanner(Map<String, dynamic> raw) {
    return {
      'id': (raw['id'] ?? '').toString(),
      'imageUrl': (raw['imageUrl'] ?? raw['image_url'] ?? '').toString(),
      'title': (raw['title'] ?? '').toString(),
      'subtitle': (raw['subtitle'] ?? '').toString(),
      'linkUrl': (raw['linkUrl'] ?? raw['link_url'] ?? '').toString(),
      'isActive': raw['isActive'] == true ||
          raw['is_active'] == true ||
          raw['active'] == true,
      'sortOrder': _asInt(raw['sortOrder'] ?? raw['sort_order'] ?? 0),
    };
  }

  Future<List<Map<String, dynamic>>> getBanners() async {
    try {
      final rows = _extractList(
        await _api.get(ApiAdminPaths.banners),
        'Failed to get banners',
      );
      final normalized = rows.map(normalizeAdminBanner).toList();
      normalized.sort(
        (a, b) => _asInt(a['sortOrder']).compareTo(_asInt(b['sortOrder'])),
      );
      return normalized;
    } on DioException catch (e) {
      throw Exception(
          'Failed to get banners: ${e.response?.data?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to get banners: $e');
    }
  }

  Future<Map<String, dynamic>> createBanner({
    required String imageUrl,
    String? title,
    String? subtitle,
    String? linkUrl,
    bool isActive = true,
    int sortOrder = 0,
  }) async {
    try {
      final payload = <String, dynamic>{
        'imageUrl': imageUrl,
        if (title != null && title.isNotEmpty) 'title': title,
        if (subtitle != null && subtitle.isNotEmpty) 'subtitle': subtitle,
        if (linkUrl != null && linkUrl.isNotEmpty) 'linkUrl': linkUrl,
        'isActive': isActive,
        'sortOrder': sortOrder,
      };
      return normalizeAdminBanner(_extractMap(
        await _api.post(ApiAdminPaths.banners, data: payload),
        'Failed to create banner',
      ));
    } on DioException catch (e) {
      throw Exception(
          'Failed to create banner: ${e.response?.data?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to create banner: $e');
    }
  }

  Future<void> updateBanner(
    String bannerId, {
    String? imageUrl,
    String? title,
    String? subtitle,
    String? linkUrl,
    bool? isActive,
    int? sortOrder,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (imageUrl != null) payload['imageUrl'] = imageUrl;
      if (title != null) payload['title'] = title;
      if (subtitle != null) payload['subtitle'] = subtitle;
      if (linkUrl != null) payload['linkUrl'] = linkUrl;
      if (isActive != null) payload['isActive'] = isActive;
      if (sortOrder != null) payload['sortOrder'] = sortOrder;
      if (payload.isEmpty) throw Exception('No fields to update');

      _extractMap(
        await _api.patch('${ApiAdminPaths.banners}/$bannerId', data: payload),
        'Failed to update banner',
      );
    } on DioException catch (e) {
      throw Exception(
          'Failed to update banner: ${e.response?.data?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to update banner: $e');
    }
  }

  Future<void> deleteBanner(String bannerId) async {
    try {
      _unwrapResponseData(
        await _api.delete('${ApiAdminPaths.banners}/$bannerId'),
        'Failed to delete banner',
      );
    } on DioException catch (e) {
      throw Exception(
          'Failed to delete banner: ${e.response?.data?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to delete banner: $e');
    }
  }

  Future<void> reorderBanners(List<String> orderedIds) async {
    for (var i = 0; i < orderedIds.length; i++) {
      await updateBanner(orderedIds[i], sortOrder: i);
    }
  }

  // ── Store settings ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getStoreSettings() async {
    try {
      return _extractMap(
        await _api.get(ApiAdminPaths.settings),
        'Failed to load settings',
      );
    } on DioException catch (e) {
      throw Exception(
          'Failed to load settings: ${e.response?.data?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to load settings: $e');
    }
  }

  Future<Map<String, dynamic>> updateStoreSettings({
    double? deliveryCharge,
    double? minOrderAmount,
    bool? storeOpen,
    String? storeOpenTime,
    String? storeCloseTime,
    double? deliveryRadiusKm,
  }) async {
    try {
      final payload = <String, dynamic>{
        if (deliveryCharge != null) 'delivery_charge': deliveryCharge,
        if (minOrderAmount != null) 'min_order_amount': minOrderAmount,
        if (storeOpen != null) 'store_open': storeOpen,
        if (storeOpenTime != null) 'store_open_time': storeOpenTime,
        if (storeCloseTime != null) 'store_close_time': storeCloseTime,
        if (deliveryRadiusKm != null) 'delivery_radius_km': deliveryRadiusKm,
      };
      return _extractMap(
        await _api.patch(ApiAdminPaths.settings, data: payload),
        'Failed to update settings',
      );
    } on DioException catch (e) {
      throw Exception(
          'Failed to update settings: ${e.response?.data?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to update settings: $e');
    }
  }

  // ── Rider assignment (stub — not a dedicated endpoint in spec) ────────────

  Future<Map<String, dynamic>> getOptimizedDeliveryRoute({String? date}) async {
    try {
      final dateParam = date ?? 'today';
      return _extractMap(
        await _api.get(
          ApiAdminPaths.deliveryRouteOptimize,
          queryParameters: {'date': dateParam},
        ),
        'Failed to get optimized route',
      );
    } on DioException catch (e) {
      throw Exception(
        'Failed to get optimized route: ${e.response?.data?['message'] ?? e.message}',
      );
    } catch (e) {
      throw Exception('Failed to get optimized route: $e');
    }
  }

  Future<Map<String, dynamic>> assignMultiRiderRoutes({
    required int numRiders,
    String? date,
  }) async {
    try {
      return _extractMap(
        await _api.post(
          ApiAdminPaths.deliveryAssignRoutes,
          data: {
            'date': date ?? 'today',
            'numRiders': numRiders,
          },
        ),
        'Failed to split orders into zones',
      );
    } on DioException catch (e) {
      throw Exception(
        'Failed to split orders into zones: ${e.response?.data?['message'] ?? e.message}',
      );
    } catch (e) {
      throw Exception('Failed to split orders into zones: $e');
    }
  }

  Future<void> bulkAssignZones({
    required List<String> riderIds,
    required List<Map<String, dynamic>> zones,
    String? date,
  }) async {
    try {
      final res = await _api.put(
        ApiDeliveryPaths.bulkAssign,
        data: {
          if (date != null) 'date': date,
          'riderIds': riderIds,
          'zones': zones,
        },
      );
      final payload = res.data;
      if (payload is Map && payload['success'] == false) {
        throw Exception(payload['message'] ?? 'Failed to assign zones');
      }
    } on DioException catch (e) {
      throw Exception(
        'Failed to assign zones: ${e.response?.data?['message'] ?? e.message}',
      );
    } catch (e) {
      throw Exception('Failed to assign zones: $e');
    }
  }

  Future<void> assignRouteToRider({
    required List<String> orderIds,
    required String riderId,
    List<String>? routeOrder,
  }) async {
    final ordered = routeOrder ?? orderIds;
    for (final orderId in ordered) {
      if (!orderIds.contains(orderId)) continue;
      await assignRiderToOrder(orderId, riderId);
    }
  }

  Future<void> assignRiderToOrder(String orderId, String riderId) async {
    try {
      final res = await _api.patch(
        '${ApiAdminPaths.orders}/$orderId',
        data: {
          'orderStatus': 'ASSIGNED',
          'deliveryUserId': int.tryParse(riderId) ?? riderId,
        },
      );
      if (res.data['success'] != true) {
        throw Exception(res.data['message'] ?? 'Failed to assign rider');
      }
    } on DioException catch (e) {
      throw Exception(
          'Failed to assign rider: ${e.response?.data?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to assign rider: $e');
    }
  }

  Future<void> cancelOrder(String orderId) async {
    try {
      final res = await _api.patch(
        '${ApiAdminPaths.orders}/$orderId',
        data: {'orderStatus': 'CANCELLED'},
      );
      if (res.data['success'] != true) {
        throw Exception(res.data['message'] ?? 'Failed to cancel order');
      }
    } on DioException catch (e) {
      throw Exception(
          'Failed to cancel order: ${e.response?.data?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to cancel order: $e');
    }
  }

  // ── Variant management (not yet in backend spec) ──────────────────────────

  Future<List<Map<String, dynamic>>> getProductVariants(String productId) async =>
      [];

  Future<Map<String, dynamic>> createProductVariant({
    required String productId,
    required String weight,
    required double weightValue,
    int? stock,
    bool isAvailable = true,
  }) async {
    throw UnimplementedError(
        'createProductVariant: not yet supported by backend');
  }

  Future<void> updateProductVariant(
    String variantId, {
    String? weight,
    double? weightValue,
    int? stock,
    bool? isAvailable,
  }) async {
    throw UnimplementedError(
        'updateProductVariant: not yet supported by backend');
  }

  Future<void> deleteProductVariant(String variantId) async {
    throw UnimplementedError(
        'deleteProductVariant: not yet supported by backend');
  }

  // ── User management (limited — uses customers endpoint) ───────────────────

  Future<Map<String, dynamic>> getUserDetails(String userId) async {
    try {
      return _extractMap(
        await _api.get(ApiAdminPaths.userById(userId)),
        'Failed to get user details',
      );
    } on DioException catch (e) {
      await ErrorTrackingService.captureException(e, tag: 'admin_get_user_details');
      throw Exception(
          'Failed to get user details: ${e.response?.data?['message'] ?? e.message}');
    } catch (e, st) {
      await ErrorTrackingService.captureException(e, stackTrace: st, tag: 'admin_get_user_details');
      throw Exception('Failed to get user details: $e');
    }
  }

  Future<void> updateUserStatus(String userId, bool isActive) async {
    try {
      final res = await _api.patch(
        ApiAdminPaths.userStatus(userId),
        data: {'isActive': isActive},
      );
      if (res.data['success'] != true) {
        throw Exception(res.data['message'] ?? 'Failed to update user status');
      }
    } on DioException catch (e) {
      throw Exception(
          'Failed to update user status: ${e.response?.data?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to update user status: $e');
    }
  }

  Future<void> updateUserRole(String userId, String role) async {
    try {
      final backendRole = _normalizeRole(role);
      final res = await _api.patch(
        ApiAdminPaths.userRole(userId),
        data: {'role': backendRole},
      );
      if (res.data['success'] != true) {
        throw Exception(res.data['message'] ?? 'Failed to update user role');
      }
    } on DioException catch (e) {
      throw Exception(
          'Failed to update user role: ${e.response?.data?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to update user role: $e');
    }
  }

  Future<void> createRiderProfile({
    required String userId,
    String? vehicleType,
    String? vehicleNumber,
    String? licenseNumber,
  }) async {
    try {
      await updateUserRole(userId, 'delivery_partner');
      final partners = await getDeliveryPartners();
      Map<String, dynamic>? partner;
      for (final item in partners) {
        final profile = item['profile'];
        if (profile is Map && profile['name'] != null) {
          partner = item;
          break;
        }
      }
      partner ??= partners.isNotEmpty ? partners.first : null;
      if (partner == null) {
        return;
      }
      await _api.patch(
        ApiAdminPaths.deliveryPartnerById(partner['id'].toString()),
        data: {
          if (vehicleType != null && vehicleType.isNotEmpty) 'vehicle': vehicleType,
          if (vehicleNumber != null && vehicleNumber.isNotEmpty)
            'vehicleNumber': vehicleNumber,
          if (licenseNumber != null && licenseNumber.isNotEmpty)
            'licenceNumber': licenseNumber,
          'approved': false,
        },
      );
    } on DioException catch (e) {
      throw Exception(
          'Failed to create rider profile: ${e.response?.data?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to create rider profile: $e');
    }
  }

  Future<void> updateRiderKYC(String riderId, bool kycVerified) async {
    try {
      final res = await _api.patch(
        ApiAdminPaths.deliveryPartnerById(riderId),
        data: {'approved': kycVerified},
      );
      if (res.data['success'] != true) {
        throw Exception(res.data['message'] ?? 'Failed to update rider KYC');
      }
    } on DioException catch (e) {
      throw Exception(
          'Failed to update rider KYC: ${e.response?.data?['message'] ?? e.message}');
    } catch (e) {
      throw Exception('Failed to update rider KYC: $e');
    }
  }
}
