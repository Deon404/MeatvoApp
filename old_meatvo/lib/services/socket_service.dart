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
///   customer_{id} room : `order:status_updated`, `order:status_update`, `order:partner_assigned`, `rider:location_update`
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

  bool get isConnected => _socket?.connected == true;

  // ── Connection ─────────────────────────────────────────────────────────────

  Future<void> connect() async {
    if (isConnected || _connecting) return;
    _connecting = true;

    try {
      final token = await StorageService().getAccessToken();

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
          _joinRoleRoom();                           // join manual room after connect
        })
        ..onDisconnect((reason) {
          debugPrint('[Socket] Disconnected: $reason');
          _connecting = false;
        })
        ..onConnectError((err) {
          debugPrint('[Socket] Connection error: $err');
          _connecting = false;
        })
        ..onError((err) => debugPrint('[Socket] Error: $err'));
    } catch (e) {
      _connecting = false;
      debugPrint('[Socket] Failed to initialize: $e');
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connecting = false;
  }

  // ── Room join helpers ──────────────────────────────────────────────────────

  /// Emit the appropriate room-join event based on the stored user's role.
  /// Called automatically after every successful connection.
  void _joinRoleRoom() {
    StorageService().getUser().then((user) {
      if (user == null || _socket == null) return;
      final parsed = int.tryParse(user.id);
      final userId = parsed ?? user.id;
      final role = user.role.toLowerCase();
      if (role == 'customer') {
        _socket?.emit('join_customer_room', userId);
        debugPrint('[Socket] Joined customer room for user $userId');
      } else if (role == 'admin') {
        _socket?.emit('join_admin_room');
        debugPrint('[Socket] Joined admin_room');
      } else if (role == 'rider' ||
          role == 'delivery' ||
          role == 'delivery_partner') {
        _socket?.emit('join_delivery_room', userId);
        debugPrint('[Socket] Joined delivery room for rider $userId');
      }
    }).catchError((e) {
      debugPrint('[Socket] Failed to join role room: $e');
    });
  }

  // ── Order events ───────────────────────────────────────────────────────────

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
  }

  void offOrderAssigned() => _socket?.off('order:assigned');

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
  }

  void offNotification() => _socket?.off('notification');

  // ── Generic event helpers ─────────────────────────────────────────────────

  void on(String event, void Function(dynamic) cb) => _socket?.on(event, cb);
  void off(String event) => _socket?.off(event);
  void emit(String event, dynamic data) {
    if (isConnected) _socket?.emit(event, data);
  }
}
