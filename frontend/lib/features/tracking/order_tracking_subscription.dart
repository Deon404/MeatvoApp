import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../../services/socket_service.dart';

/// Realtime + fallback polling for active customer orders.
class OrderTrackingSubscription {
  final OrderService _orderService = OrderService();
  final SocketService _socket = SocketService();

  StreamSubscription<OrderModel>? _pollSub;
  void Function(OrderModel)? _onOrderUpdate;
  void Function(double lat, double lng)? _onRiderLocation;
  String? _orderId;

  static const _terminalStatuses = {'delivered', 'cancelled'};

  void start({
    required String orderId,
    required void Function(OrderModel order) onOrderUpdate,
    void Function(double lat, double lng)? onRiderLocation,
  }) {
    stop();
    _orderId = orderId;
    _onOrderUpdate = onOrderUpdate;
    _onRiderLocation = onRiderLocation;

    _socket.connect();
    _socket.onOrderUpdate(_handleStatusEvent);
    _socket.onLocationUpdate(_handleLocationEvent);

    _pollSub = Stream.periodic(const Duration(seconds: 5))
        .asyncMap((_) => _orderService.getOrderById(orderId))
        .listen(
      (order) {
        _onOrderUpdate?.call(order);
        if (_terminalStatuses.contains(order.status.toLowerCase())) {
          stop();
        }
      },
      onError: (e) => debugPrint('[OrderTracking] poll error: $e'),
    );

    _orderService.getOrderById(orderId).then((order) {
      _onOrderUpdate?.call(order);
    }).catchError((e) {
      debugPrint('[OrderTracking] initial load: $e');
      return null;
    });
  }

  void _handleStatusEvent(dynamic data) {
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);
    final eventOrderId = map['orderId']?.toString();
    if (eventOrderId == null || eventOrderId != _orderId) return;

    _orderService.getOrderById(_orderId!).then((order) {
      _onOrderUpdate?.call(order);
      if (_terminalStatuses.contains(order.status.toLowerCase())) {
        stop();
      }
    }).catchError((_) {});
  }

  void _handleLocationEvent(dynamic data) {
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);
    final eventOrderId = map['orderId']?.toString();
    if (eventOrderId != null && eventOrderId != _orderId) return;

    final lat = _toDouble(map['lat'] ?? map['latitude']);
    final lng = _toDouble(map['lng'] ?? map['longitude']);
    if (lat == null || lng == null) return;
    _onRiderLocation?.call(lat, lng);
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  void stop() {
    _pollSub?.cancel();
    _pollSub = null;
    _socket.offOrderUpdate();
    _socket.offLocationUpdate();
    _orderId = null;
    _onOrderUpdate = null;
    _onRiderLocation = null;
  }

  void dispose() => stop();
}
