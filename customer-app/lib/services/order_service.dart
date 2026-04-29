import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order_model.dart';
import 'api_service.dart';

final orderServiceProvider = Provider<OrderService>((ref) {
  return OrderService(ref);
});

class OrderService {
  final Ref _ref;
  OrderService(this._ref);

  Future<PaginatedOrders> getOrders({int page = 1, int limit = 20}) async {
    final response = await _ref.read(apiServiceProvider).get(
      '/v1/orders',
      params: {
        'page': page,
        'limit': limit,
      },
    );
    final payload = response.data as Map<String, dynamic>;
    final data = (payload['data'] ?? payload) as Map<String, dynamic>;
    final list = (data['orders'] ?? const <dynamic>[]) as List<dynamic>;
    return PaginatedOrders(
      orders: list.map((e) => OrderModel.fromListJson(e as Map<String, dynamic>)).toList(),
      page: ((data['page'] ?? page) as num).toInt(),
      pages: ((data['pages'] ?? 1) as num).toInt(),
    );
  }

  Future<OrderModel> getOrderById(int id) async {
    final response = await _ref.read(apiServiceProvider).get('/v1/orders/$id');
    final payload = response.data as Map<String, dynamic>;
    final data = (payload['data'] ?? payload) as Map<String, dynamic>;

    final order = (data['order'] ?? <String, dynamic>{}) as Map<String, dynamic>;
    final itemsRaw = (data['items'] ?? const <dynamic>[]) as List<dynamic>;
    final assignmentRaw = data['assignment'] as Map<String, dynamic>?;

    final items = itemsRaw.map((e) => OrderItemModel.fromJson(e as Map<String, dynamic>)).toList();
    final assignment = assignmentRaw == null ? null : OrderAssignmentModel.fromJson(assignmentRaw);
    return OrderModel.fromDetailJson(order, items, assignment);
  }
}

class PaginatedOrders {
  final List<OrderModel> orders;
  final int page;
  final int pages;

  const PaginatedOrders({
    required this.orders,
    required this.page,
    required this.pages,
  });
}
