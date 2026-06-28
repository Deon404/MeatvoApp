import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/earnings_data.dart';
import '../services/rider_location_service.dart';
import '../services/rider_service.dart';
import '../services/socket_service.dart';

/// Rider state for delivery partner domain
class RiderState {
  final bool isOnline;
  final Map<String, dynamic>? profile;
  final EarningsData? earnings;
  final List<Map<String, dynamic>> activeOrders;
  final List<Map<String, dynamic>> orderHistory;
  final Map<String, dynamic>? currentRoute;
  final Position? currentLocation;
  final bool isLoading;
  final String? error;
  final bool isLocationTracking;

  const RiderState({
    this.isOnline = false,
    this.profile,
    this.earnings,
    this.activeOrders = const [],
    this.orderHistory = const [],
    this.currentRoute,
    this.currentLocation,
    this.isLoading = false,
    this.error,
    this.isLocationTracking = false,
  });

  RiderState copyWith({
    bool? isOnline,
    Map<String, dynamic>? profile,
    EarningsData? earnings,
    List<Map<String, dynamic>>? activeOrders,
    List<Map<String, dynamic>>? orderHistory,
    Map<String, dynamic>? currentRoute,
    Position? currentLocation,
    bool? isLoading,
    String? error,
    bool? isLocationTracking,
  }) {
    return RiderState(
      isOnline: isOnline ?? this.isOnline,
      profile: profile ?? this.profile,
      earnings: earnings ?? this.earnings,
      activeOrders: activeOrders ?? this.activeOrders,
      orderHistory: orderHistory ?? this.orderHistory,
      currentRoute: currentRoute ?? this.currentRoute,
      currentLocation: currentLocation ?? this.currentLocation,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isLocationTracking: isLocationTracking ?? this.isLocationTracking,
    );
  }

  // Helper to get active order by ID
  Map<String, dynamic>? getOrderById(String orderId) {
    try {
      return activeOrders.firstWhere(
        (order) => order['id']?.toString() == orderId,
      );
    } catch (e) {
      return null;
    }
  }

  // Get total earnings today
  double get todayEarnings => earnings?.today ?? 0.0;

  // Get weekly earnings
  double get weeklyEarnings => earnings?.thisWeek ?? 0.0;

  // Get monthly earnings
  double get monthlyEarnings => earnings?.thisMonth ?? 0.0;

  // Get delivery count
  int get deliveryCount => earnings?.totalDeliveries ?? 0;

  // Get rider rating
  double get rating => earnings?.rating ?? 0.0;
}

/// Rider state notifier
class RiderNotifier extends StateNotifier<RiderState> {
  final RiderService _riderService;
  final SocketService _socketService;
  final RiderLocationService _locationService;

  StreamSubscription? _socketSubscription;
  StreamSubscription? _orderSubscription;
  Timer? _pollTimer;

  RiderNotifier(
    this._riderService,
    this._socketService,
    this._locationService,
  ) : super(const RiderState());

  /// Initialize rider data and real-time subscriptions
  Future<void> initialize() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Load profile, orders, and earnings in parallel
      await Future.wait([
        _loadProfile(),
        _loadActiveOrders(),
        _loadEarnings(),
      ]);

      // Setup real-time subscriptions
      _setupSocketListeners();
      _startPolling();

      state = state.copyWith(isLoading: false);
    } catch (e) {
      debugPrint('[RiderProvider] Initialize error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load rider data: $e',
      );
    }
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _riderService.getRiderProfile();
      final isOnline = profile['online'] == true;
      state = state.copyWith(profile: profile, isOnline: isOnline);
    } catch (e) {
      debugPrint('[RiderProvider] Load profile error: $e');
      rethrow;
    }
  }

  Future<void> _loadActiveOrders() async {
    try {
      final orders = await _riderService.getRiderOrders();
      state = state.copyWith(activeOrders: orders);
    } catch (e) {
      debugPrint('[RiderProvider] Load orders error: $e');
      rethrow;
    }
  }

  Future<void> _loadEarnings() async {
    try {
      final earnings = await _riderService.getRiderEarnings();
      state = state.copyWith(earnings: earnings);
    } catch (e) {
      debugPrint('[RiderProvider] Load earnings error: $e');
      rethrow;
    }
  }

  /// Toggle online/offline status
  Future<void> toggleOnlineStatus() async {
    final newStatus = !state.isOnline;
    
    try {
      await _riderService.updateRiderStatus(
        newStatus ? 'available' : 'offline',
      );
      state = state.copyWith(isOnline: newStatus);

      if (!newStatus) {
        // Stop location tracking when going offline
        stopLocationTracking();
      }
    } catch (e) {
      debugPrint('[RiderProvider] Toggle online error: $e');
      state = state.copyWith(error: 'Failed to update status: $e');
      rethrow;
    }
  }

  /// Accept an order
  Future<void> acceptOrder(String orderId) async {
    try {
      await _riderService.acceptOrder(orderId);
      
      // Reload active orders
      await _loadActiveOrders();
      
      // Start location tracking for this order
      startLocationTracking(orderId);
    } catch (e) {
      debugPrint('[RiderProvider] Accept order error: $e');
      state = state.copyWith(error: 'Failed to accept order: $e');
      rethrow;
    }
  }

  /// Reject an order
  Future<void> rejectOrder(String orderId) async {
    try {
      await _riderService.rejectOrder(orderId);
      
      // Reload active orders
      await _loadActiveOrders();
    } catch (e) {
      debugPrint('[RiderProvider] Reject order error: $e');
      state = state.copyWith(error: 'Failed to reject order: $e');
      rethrow;
    }
  }

  /// Update order status
  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      await _riderService.updateOrderStatus(orderId, status);
      
      // Reload active orders and earnings
      await Future.wait([
        _loadActiveOrders(),
        _loadEarnings(),
      ]);

      // Stop tracking if delivered
      if (status == 'DELIVERED') {
        stopLocationTracking();
      }
    } catch (e) {
      debugPrint('[RiderProvider] Update status error: $e');
      state = state.copyWith(error: 'Failed to update order status: $e');
      rethrow;
    }
  }

  /// Load optimized route
  Future<void> loadRoute() async {
    state = state.copyWith(isLoading: true);
    
    try {
      // Route payload is delivered via socket (`route:zone_assigned`).
      state = state.copyWith(isLoading: false);
    } catch (e) {
      debugPrint('[RiderProvider] Load route error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load route: $e',
      );
    }
  }

  /// Start location tracking for an order
  void startLocationTracking(String orderId) {
    if (state.isLocationTracking) {
      _locationService.stopSendingLocation();
    }
    
    _locationService.startSendingLocation(orderId);
    state = state.copyWith(isLocationTracking: true);
  }

  /// Stop location tracking
  void stopLocationTracking() {
    _locationService.stopSendingLocation();
    state = state.copyWith(isLocationTracking: false);
  }

  /// Update current location
  void updateLocation(Position position) {
    state = state.copyWith(currentLocation: position);
  }

  /// Refresh all data
  Future<void> refresh() async {
    await Future.wait([
      _loadProfile(),
      _loadActiveOrders(),
      _loadEarnings(),
    ]);
  }

  /// Setup socket listeners for real-time updates
  void _setupSocketListeners() {
    _socketService.onOrderAssigned((data) {
      debugPrint('[RiderProvider] New order assigned: $data');
      _loadActiveOrders();
    });

    _socketService.onRouteZoneAssigned((data) {
      debugPrint('[RiderProvider] Route zone assigned: $data');
      _loadActiveOrders();
      loadRoute();
    });

    _socketService.onOrderAssignmentCancelled((data) {
      debugPrint('[RiderProvider] Assignment cancelled: $data');
      _loadActiveOrders();
    });
  }

  /// Start polling for updates (fallback)
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadActiveOrders(),
    );
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    _orderSubscription?.cancel();
    _pollTimer?.cancel();
    stopLocationTracking();
    super.dispose();
  }
}

/// Tracks assignment alert sheets shown on the dashboard (cleared on logout).
class _AlertsState {
  final Set<String> alertedOrderIds;
  final Set<String> alertedAssignmentKeys;

  const _AlertsState({
    this.alertedOrderIds = const {},
    this.alertedAssignmentKeys = const {},
  });

  _AlertsState copyWith({
    Set<String>? alertedOrderIds,
    Set<String>? alertedAssignmentKeys,
  }) {
    return _AlertsState(
      alertedOrderIds: alertedOrderIds ?? this.alertedOrderIds,
      alertedAssignmentKeys:
          alertedAssignmentKeys ?? this.alertedAssignmentKeys,
    );
  }
}

/// Public alias — cache in [initState] when used from [dispose] or async callbacks.
typedef RiderAssignmentAlerts = _AlertsNotifier;

class _AlertsNotifier extends StateNotifier<_AlertsState> {
  _AlertsNotifier() : super(const _AlertsState());

  void clear() {
    state = const _AlertsState();
  }

  void addOrder(String id) {
    state = state.copyWith(
      alertedOrderIds: {...state.alertedOrderIds, id},
    );
  }

  void removeOrder(String id) {
    final next = {...state.alertedOrderIds}..remove(id);
    state = state.copyWith(alertedOrderIds: next);
  }

  void addAssignment(String key) {
    state = state.copyWith(
      alertedAssignmentKeys: {...state.alertedAssignmentKeys, key},
    );
  }

  void removeAssignment(String key) {
    final next = {...state.alertedAssignmentKeys}..remove(key);
    state = state.copyWith(alertedAssignmentKeys: next);
  }

  bool containsOrder(String id) => state.alertedOrderIds.contains(id);

  bool containsAssignment(String key) =>
      state.alertedAssignmentKeys.contains(key);
}

final riderAssignmentAlertsProvider =
    StateNotifierProvider<_AlertsNotifier, _AlertsState>(
  (ref) => _AlertsNotifier(),
);

/// Rider provider instance
final riderProvider = StateNotifierProvider<RiderNotifier, RiderState>((ref) {
  return RiderNotifier(
    RiderService(),
    SocketService(),
    ref.read(riderLocationServiceProvider),
  );
});

/// Convenience providers for specific state slices
final riderProfileProvider = Provider<Map<String, dynamic>?>((ref) {
  return ref.watch(riderProvider).profile;
});

final riderEarningsProvider = Provider<EarningsData?>((ref) {
  return ref.watch(riderProvider).earnings;
});

final riderActiveOrdersProvider = Provider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(riderProvider).activeOrders;
});

final riderIsOnlineProvider = Provider<bool>((ref) {
  return ref.watch(riderProvider).isOnline;
});

final riderCurrentRouteProvider = Provider<Map<String, dynamic>?>((ref) {
  return ref.watch(riderProvider).currentRoute;
});
