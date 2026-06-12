import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order_model.dart';
import '../services/order_service.dart';
import '../utils/order_status_util.dart';

class OrderState {
  const OrderState({
    required this.isLoading,
    required this.activeOrders,
    required this.history,
    required this.error,
  });

  factory OrderState.initial() => const OrderState(
        isLoading: true,
        activeOrders: [],
        history: [],
        error: null,
      );

  final bool isLoading;
  final List<OrderModel> activeOrders;
  final List<OrderModel> history;
  final String? error;

  OrderState copyWith({
    bool? isLoading,
    List<OrderModel>? activeOrders,
    List<OrderModel>? history,
    Object? error = _sentinel,
  }) {
    return OrderState(
      isLoading: isLoading ?? this.isLoading,
      activeOrders: activeOrders ?? this.activeOrders,
      history: history ?? this.history,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

const Object _sentinel = Object();

final orderProvider = StateNotifierProvider<OrderNotifier, OrderState>((ref) {
  return OrderNotifier(OrderService())..loadOrders();
});

class OrderNotifier extends StateNotifier<OrderState> {
  OrderNotifier(this._orderService) : super(OrderState.initial());

  final OrderService _orderService;
  StreamSubscription<OrderModel>? _trackingSubscription;

  Future<void> loadOrders() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final orders = await _orderService.getOrders();
      final active = orders
          .where((order) => isOrderActive(order.status))
          .toList(growable: false);
      final history = orders
          .where(
            (order) =>
                isOrderCompleted(order.status) ||
                isOrderCancelled(order.status),
          )
          .toList(growable: false);
      state = state.copyWith(
        isLoading: false,
        activeOrders: active,
        history: history,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> trackOrder(String orderId) async {
    await _trackingSubscription?.cancel();
    _trackingSubscription = _orderService.trackOrder(orderId).listen((_) {
      loadOrders();
    });
  }

  Future<void> cancelOrder(String orderId) async {
    try {
      await _orderService.cancelOrder(orderId);
      await loadOrders();
    } catch (error) {
      state = state.copyWith(
        error: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  @override
  void dispose() {
    _trackingSubscription?.cancel();
    super.dispose();
  }
}
