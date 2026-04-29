import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order_model.dart';
import '../services/order_service.dart';

final ordersPageProvider = StateProvider<int>((ref) => 1);

final ordersProvider = FutureProvider<PaginatedOrders>((ref) async {
  final page = ref.watch(ordersPageProvider);
  return ref.read(orderServiceProvider).getOrders(page: page, limit: 20);
});

final orderDetailProvider = FutureProvider.family<OrderModel, int>((ref, orderId) async {
  return ref.read(orderServiceProvider).getOrderById(orderId);
});

final liveOrderProvider = StreamProvider.family<OrderModel, int>((ref, orderId) async* {
  while (true) {
    final order = await ref.read(orderServiceProvider).getOrderById(orderId);
    yield order;
    await Future<void>.delayed(const Duration(seconds: 5));
  }
});
