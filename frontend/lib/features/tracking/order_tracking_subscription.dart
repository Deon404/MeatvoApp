import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../../services/order_tracking_notification_service.dart';
import '../../services/socket_service.dart';
import '../../utils/order_status_util.dart';

/// Live ETA payload from backend `eta:updated` socket event.
class LiveEtaUpdate {
  final int etaMinutes;
  final double? distanceKm;
  final double? riderLat;
  final double? riderLng;

  const LiveEtaUpdate({
    required this.etaMinutes,
    this.distanceKm,
    this.riderLat,
    this.riderLng,
  });
}

/// Realtime + fallback polling for active customer orders.
class OrderTrackingSubscription {
  final OrderService _orderService = OrderService();
  final SocketService _socket = SocketService();

  StreamSubscription<OrderModel>? _pollSub;
  StreamSubscription<bool>? _socketReconnectSub;
  void Function(OrderModel)? _onOrderUpdate;
  void Function(double lat, double lng)? _onRiderLocation;
  void Function(LiveEtaUpdate update)? _onEtaUpdate;
  void Function(bool connected)? _onConnectionState;
  void Function(dynamic)? _statusHandler;
  void Function(dynamic)? _locationHandler;
  void Function(dynamic)? _etaHandler;
  String? _orderId;
  bool _socketConnected = true;

  static const _terminalStatuses = {'delivered', 'cancelled', 'failed_delivery'};
  static const _pollInterval = Duration(seconds: 30);

  void start({
    required String orderId,
    required void Function(OrderModel order) onOrderUpdate,
    void Function(double lat, double lng)? onRiderLocation,
    void Function(LiveEtaUpdate update)? onEtaUpdate,
    void Function(bool connected)? onConnectionState,
  }) {
    stop();
    _orderId = orderId;
    _onOrderUpdate = onOrderUpdate;
    _onRiderLocation = onRiderLocation;
    _onEtaUpdate = onEtaUpdate;
    _onConnectionState = onConnectionState;

    _statusHandler = _handleStatusEvent;
    _locationHandler = _handleLocationEvent;
    _etaHandler = _handleEtaEvent;

    _socket.connect();
    _socket.joinOrderRoom(orderId);
    _socket.onOrderUpdate(_statusHandler!);
    _socket.onLocationUpdate(_locationHandler!);
    _socket.onEtaUpdate(_etaHandler!);

    // UX FIX: 30s REST fallback when socket is disconnected
    _pollSub = Stream.periodic(_pollInterval)
        .asyncMap((_) => _orderService.getOrderById(orderId))
        .listen(
      (order) {
        _onOrderUpdate?.call(order);
        _syncNotification(order);
        if (_terminalStatuses.contains(normalizeOrderStatus(order.status))) {
          stop();
        }
      },
      onError: (e) => debugPrint('[OrderTracking] poll error: $e'),
    );

    _socketReconnectSub = _socket.connectionStateStream.listen((connected) {
      _socketConnected = connected;
      _onConnectionState?.call(connected);
    });
    _onConnectionState?.call(_socket.isConnected);

    _orderService.getOrderById(orderId).then((order) {
      _onOrderUpdate?.call(order);
      _syncNotification(order);
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
      _syncNotification(order);
      if (_terminalStatuses.contains(normalizeOrderStatus(order.status))) {
        stop();
      }
    }).catchError((_) {});
  }

  void _syncNotification(OrderModel order) {
    if (_orderId == null) return;
    if (_terminalStatuses.contains(normalizeOrderStatus(order.status))) {
      OrderTrackingNotificationService.instance.dismiss();
      return;
    }
    OrderTrackingNotificationService.instance.update(
      orderId: _orderId!,
      status: order.status,
      etaMinutes: order.etaMinutes,
      estimatedDeliveryTime: order.estimatedDeliveryTime,
    );
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

  void _handleEtaEvent(dynamic data) {
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);
    final eventOrderId = map['orderId']?.toString();
    if (eventOrderId != null && eventOrderId != _orderId) return;

    final etaRaw = map['eta'] ?? map['etaMinutes'] ?? map['eta_minutes'];
    final etaMinutes = etaRaw is num
        ? etaRaw.round()
        : int.tryParse(etaRaw?.toString() ?? '');
    if (etaMinutes == null) return;

    final distanceRaw = map['distance'] ?? map['distanceKm'];
    final distanceKm = _toDouble(distanceRaw);

    double? riderLat;
    double? riderLng;
    final riderLocation = map['riderLocation'] ?? map['rider_location'];
    if (riderLocation is Map) {
      final loc = Map<String, dynamic>.from(riderLocation);
      riderLat = _toDouble(loc['lat'] ?? loc['latitude']);
      riderLng = _toDouble(loc['lng'] ?? loc['longitude']);
    }

    _onEtaUpdate?.call(
      LiveEtaUpdate(
        etaMinutes: etaMinutes,
        distanceKm: distanceKm,
        riderLat: riderLat,
        riderLng: riderLng,
      ),
    );

    if (riderLat != null && riderLng != null) {
      _onRiderLocation?.call(riderLat, riderLng);
    }
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  void stop() {
    _pollSub?.cancel();
    _pollSub = null;
    _socketReconnectSub?.cancel();
    _socketReconnectSub = null;

    if (_statusHandler != null) {
      _socket.offOrderUpdate();
      _statusHandler = null;
    }
    if (_locationHandler != null) {
      _socket.offLocationUpdate();
      _locationHandler = null;
    }
    if (_etaHandler != null) {
      _socket.offEtaUpdate();
      _etaHandler = null;
    }

    _orderId = null;
    _onOrderUpdate = null;
    _onRiderLocation = null;
    _onEtaUpdate = null;
    _onConnectionState = null;
    OrderTrackingNotificationService.instance.dismiss();
  }

  void dispose() => stop();
}
