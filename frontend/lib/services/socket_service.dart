import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/api_config.dart';
import 'storage_service.dart';

/// Socket.IO service — connects to backend/src/socket/socket.js.
///
/// The backend mounts Socket.IO at path `/ws` (NOT the default `/socket.io`).
/// JWT token is passed as socket auth credential on handshake.
///
/// Room model (backend/src/socket/socket.js):
///   Auto-joined on connect: `user:{id}`, `role:{ROLE}`, `public`
///   Manual joins:           `customer_{id}`, `admin_room`, `delivery_{id}`
///
/// Server → client events (by room):
///   customer_{id} room : `order:status_updated`, `order:status_update`, `order:partner_assigned`, `rider:location_update`, `eta:updated`
///   user:{id} room     : `order:assigned`, `order:assignment_cancelled`, `route:zone_assigned`, `delivery:location`, `partner:location_update`
///   admin_room         : `order:new`, `order:updated`, `order:assignment_failed`, `order:partner_assigned`
///   public room        : `catalog:categories_changed`, `catalog:products_changed`,
///                        `settings:theme`, `settings:banner`,
///                        `store:status_changed`, `store:delivery_zone_updated`
///
/// NOTE: Rider location update goes via REST (PUT /api/delivery/location), NOT socket.
class SocketService {
  static SocketService? _instance;
  factory SocketService() => _instance ??= SocketService._();
  SocketService._();

  io.Socket? _socket;
  bool _connecting = false;
  Future<void>? _connectFuture;
  Completer<void>? _connectCompleter;
  bool _roleRoomJoined = false;
  final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();

  bool get isConnected => _socket?.connected == true;
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  // ── Connection ─────────────────────────────────────────────────────────────

  Future<void> connect() {
    if (isConnected) return Future.value();
    if (_connectFuture != null) return _connectFuture!;

    _connectFuture = _connectInternal().whenComplete(() {
      _connectFuture = null;
    });
    return _connectFuture!;
  }

  Future<void> _connectInternal() async {
    if (isConnected) return;
    if (_connecting && _connectCompleter != null) {
      return _connectCompleter!.future;
    }

    _connecting = true;
    _connectCompleter = Completer<void>();

    try {
      final token = await StorageService().getAccessToken();

      _socket?.dispose();
      _socket = io.io(
        ApiConfig.socketUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .setPath('/ws')                          // backend mounts at /ws, not /socket.io
            .setAuth({'token': token ?? ''})
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(5)
            .setReconnectionDelay(2000)
            .build(),
      );

      _socket!
        ..onConnect((_) {
          debugPrint('[Socket] Connected: ${ApiConfig.socketUrl}/ws');
          _connecting = false;
          _connectionStateController.add(true);
          _joinRoleRoom();                           // join manual room after connect
          if (!(_connectCompleter?.isCompleted ?? true)) {
            _connectCompleter?.complete();
          }
        })
        ..onDisconnect((reason) {
          debugPrint('[Socket] Disconnected: $reason');
          _connecting = false;
          _roleRoomJoined = false;
          _connectionStateController.add(false);
        })
        ..onConnectError((err) {
          debugPrint('[Socket] Connection error: $err');
          _connecting = false;
          _roleRoomJoined = false;
          if (!(_connectCompleter?.isCompleted ?? true)) {
            _connectCompleter?.completeError(err);
          }
        })
        ..onError((err) => debugPrint('[Socket] Error: $err'));

      await _connectCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('[Socket] Connection timed out — listeners will attach when ready');
        },
      );
    } catch (e) {
      _connecting = false;
      _roleRoomJoined = false;
      debugPrint('[Socket] Failed to initialize: $e');
      if (!(_connectCompleter?.isCompleted ?? true)) {
        _connectCompleter?.complete();
      }
    } finally {
      _connectCompleter = null;
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connecting = false;
    _connectFuture = null;
    _roleRoomJoined = false;
  }

  // ── Room join helpers ──────────────────────────────────────────────────────

  /// Emit the appropriate room-join event based on the stored user's role.
  /// Called automatically after every successful connection.
  void _joinRoleRoom() {
    if (_roleRoomJoined || _socket == null) return;

    StorageService().getUser().then((user) {
      if (user == null || _socket == null || _roleRoomJoined) return;
      final parsed = int.tryParse(user.id);
      final userId = parsed ?? user.id;
      final role = user.role.toLowerCase();
      if (role == 'customer') {
        _socket?.emit('join_customer_room', userId);
        _roleRoomJoined = true;
        debugPrint('[Socket] Joined customer room for user $userId');
      } else if (role == 'admin') {
        _socket?.emit('join_admin_room');
        _roleRoomJoined = true;
        debugPrint('[Socket] Joined admin_room');
      } else if (role == 'staff') {
        _socket?.emit('join_staff_room');
        _roleRoomJoined = true;
        debugPrint('[Socket] Joined staff_room');
      } else if (role == 'rider' ||
          role == 'delivery' ||
          role == 'delivery_partner') {
        _socket?.emit('join_delivery_room', userId);
        _roleRoomJoined = true;
        debugPrint('[Socket] Joined delivery room for rider $userId');
      }
    }).catchError((e) {
      debugPrint('[Socket] Failed to join role room: $e');
    });
  }

  // ── Order events ───────────────────────────────────────────────────────────

  /// Join order-specific tracking room (canonical `order:{id}` on backend).
  void joinOrderRoom(String orderId) {
    _socket?.emit('join_order_room', orderId);
  }

  /// Listen for order status changes (customer-facing).
  /// Backend emits `order:status_updated` to `customer_{id}` room.
  void onOrderUpdate(void Function(dynamic data) cb) {
    _socket?.on('order:status_updated', cb);
    _socket?.on('order:status_update', cb);      // legacy alias backend also emits
  }

  void offOrderUpdate() {
    _socket?.off('order:status_updated');
    _socket?.off('order:status_update');
  }

  /// Listen for delivery partner assigned event (customer-facing).
  /// Backend emits `order:partner_assigned` to `customer_{id}` room.
  void onOrderConfirmed(void Function(dynamic data) cb) {
    _socket?.on('order:partner_assigned', cb);
  }

  void offOrderConfirmed() => _socket?.off('order:partner_assigned');

  /// Delivery partner: new order assigned to this rider.
  void onOrderAssigned(void Function(dynamic data) cb) {
    _socket?.on('order:assigned', cb);
    _socket?.on('order:broadcast', cb);
  }

  void offOrderAssigned() {
    _socket?.off('order:assigned');
    _socket?.off('order:broadcast');
  }

  /// Delivery partner: order auto-accepted after popup timeout (nearest store rider).
  void onOrderAutoAccepted(void Function(dynamic data) cb) {
    _socket?.on('order:auto_accepted', cb);
  }

  void offOrderAutoAccepted() => _socket?.off('order:auto_accepted');

  /// Delivery partner: admin assigned a full delivery zone/route.
  void onRouteZoneAssigned(void Function(dynamic data) cb) {
    _socket?.on('route:zone_assigned', cb);
  }

  void offRouteZoneAssigned() => _socket?.off('route:zone_assigned');

  /// Delivery partner: assignment cancelled or order cancelled.
  void onOrderAssignmentCancelled(void Function(dynamic data) cb) {
    _socket?.on('order:assignment_cancelled', cb);
  }

  void offOrderAssignmentCancelled() =>
      _socket?.off('order:assignment_cancelled');

  /// Listen for new order arrival (admin-facing).
  /// Backend emits `order:new` to `admin_room`.
  void onNewOrder(void Function(dynamic data) cb) {
    _socket?.on('order:new', cb);
  }

  void offNewOrder() => _socket?.off('order:new');

  /// Listen for order updates (admin-facing).
  /// Backend emits `order:updated` to `admin_room`.
  void onAdminOrderUpdate(void Function(dynamic data) cb) {
    _socket?.on('order:updated', cb);
  }

  void offAdminOrderUpdate() => _socket?.off('order:updated');

  /// Listen for rider assignment failures (admin-facing).
  /// Backend emits `order:assignment_failed` to `admin_room`.
  void onAssignmentFailed(void Function(dynamic data) cb) {
    _socket?.on('order:assignment_failed', cb);
  }

  void offAssignmentFailed() => _socket?.off('order:assignment_failed');

  /// Kitchen staff: new confirmed order or status change in kitchen queue.
  void onKitchenOrderUpdated(void Function(dynamic data) cb) {
    _socket?.on('order:updated', cb);
    _socket?.on('order:new', cb);
  }

  void offKitchenOrderUpdated() {
    _socket?.off('order:updated');
    _socket?.off('order:new');
  }

  // ── Rider location events ─────────────────────────────────────────────────

  /// Listen for rider location updates (customer-facing order tracking).
  /// Backend emits `rider:location_update` to `customer_{id}` room (tracking.service.js),
  /// and legacy `delivery:location` / `partner:location_update` to `user:{id}` room.
  void onLocationUpdate(void Function(dynamic data) cb) {
    _socket?.on('rider:location_update', cb);
    _socket?.on('delivery:location', cb);
    _socket?.on('partner:location_update', cb);
  }

  void offLocationUpdate() {
    _socket?.off('rider:location_update');
    _socket?.off('delivery:location');
    _socket?.off('partner:location_update');
  }

  /// Listen for live ETA recalculations (customer-facing order tracking).
  /// Backend emits `eta:updated` to `customer_{id}` room (eta.service.js).
  void onEtaUpdate(void Function(dynamic data) cb) {
    _socket?.on('eta:updated', cb);
  }

  void offEtaUpdate() => _socket?.off('eta:updated');

  /// Listen for partner acceptance event (customer-facing).
  /// Backend emits `partner:accepted` when delivery partner accepts the order.
  void onPartnerAccepted(void Function(dynamic data) cb) {
    _socket?.on('partner:accepted', cb);
  }

  void offPartnerAccepted() {
    _socket?.off('partner:accepted');
  }

  /// Subscribe to customer location updates (rider-facing).
  /// Rider can request customer location updates for navigation.
  void subscribeToCustomerLocation(String orderId) {
    if (isConnected) {
      _socket?.emit('subscribe:customer_location', {'orderId': orderId});
    }
  }

  /// Listen for customer location updates (rider-facing).
  /// Backend emits `customer:location` when customer location changes.
  void onCustomerLocation(void Function(dynamic data) cb) {
    _socket?.on('customer:location', cb);
  }

  void offCustomerLocation() {
    _socket?.off('customer:location');
  }

  // ── Catalog / Store broadcast events (public room) ─────────────────────────

  void onCatalogChange(void Function(dynamic data) cb) {
    _socket?.on('catalog:categories_changed', cb);
    _socket?.on('catalog:products_changed', cb);
  }

  void offCatalogChange() {
    _socket?.off('catalog:categories_changed');
    _socket?.off('catalog:products_changed');
  }

  void onStoreStatusChange(void Function(dynamic data) cb) {
    _socket?.on('store:status_changed', cb);
  }

  void offStoreStatusChange() => _socket?.off('store:status_changed');

  // ── Notification events ───────────────────────────────────────────────────

  void onNotification(void Function(dynamic data) cb) {
    _socket?.on('notification', cb);
    _socket?.on('notification:new', cb);
  }

  void offNotification() {
    _socket?.off('notification');
    _socket?.off('notification:new');
  }

  // ── Generic event helpers ─────────────────────────────────────────────────

  void on(String event, void Function(dynamic) cb) => _socket?.on(event, cb);
  void off(String event) => _socket?.off(event);
  void emit(String event, dynamic data) {
    if (isConnected) _socket?.emit(event, data);
  }
}
