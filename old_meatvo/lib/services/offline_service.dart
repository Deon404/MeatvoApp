import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'rider_service.dart';

/// Offline action types
enum OfflineActionType {
  statusUpdate,
  locationUpdate,
  acceptOrder,
  rejectOrder,
  updateProfile,
}

/// Offline action model
class OfflineAction {
  final String id;
  final OfflineActionType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final int retryCount;

  OfflineAction({
    required this.id,
    required this.type,
    required this.data,
    required this.timestamp,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
        'retryCount': retryCount,
      };

  factory OfflineAction.fromJson(Map<String, dynamic> json) {
    return OfflineAction(
      id: json['id'] as String,
      type: OfflineActionType.values.byName(json['type'] as String),
      data: Map<String, dynamic>.from(json['data'] as Map),
      timestamp: DateTime.parse(json['timestamp'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
    );
  }

  OfflineAction copyWith({int? retryCount}) {
    return OfflineAction(
      id: id,
      type: type,
      data: data,
      timestamp: timestamp,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}

/// Offline queue service
/// Queues actions when offline and syncs when connection is restored
class OfflineService {
  static const String _queueKey = 'offline_queue';
  static const int _maxRetries = 3;
  static const Duration _syncDebounce = Duration(seconds: 2);

  final RiderService _riderService;
  final Connectivity _connectivity;

  List<OfflineAction> _queue = [];
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _syncTimer;
  bool _isSyncing = false;
  bool _isOnline = true;

  OfflineService({
    RiderService? riderService,
    Connectivity? connectivity,
  })  : _riderService = riderService ?? RiderService(),
        _connectivity = connectivity ?? Connectivity();

  /// Initialize the service
  Future<void> initialize() async {
    await _loadQueue();
    _listenToConnectivity();
    
    // Check initial connectivity
    final result = await _connectivity.checkConnectivity();
    _isOnline = result != ConnectivityResult.none;
    
    if (_isOnline && _queue.isNotEmpty) {
      _scheduleSyncDebounced();
    }
  }

  /// Check if device is currently online
  bool get isOnline => _isOnline;

  /// Get queued actions count
  int get queuedCount => _queue.length;

  /// Listen to connectivity changes
  void _listenToConnectivity() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (ConnectivityResult result) {
        final wasOffline = !_isOnline;
        _isOnline = result != ConnectivityResult.none;

        debugPrint('[OfflineService] Connectivity changed: ${result.name}');

        // Connection restored
        if (wasOffline && _isOnline) {
          debugPrint('[OfflineService] Connection restored. Queue size: ${_queue.length}');
          _scheduleSyncDebounced();
        }
      },
    );
  }

  /// Schedule sync with debounce
  void _scheduleSyncDebounced() {
    _syncTimer?.cancel();
    _syncTimer = Timer(_syncDebounce, () {
      if (_isOnline && !_isSyncing) {
        syncQueuedActions();
      }
    });
  }

  /// Queue a status update
  void queueStatusUpdate(String orderId, String status) {
    final action = OfflineAction(
      id: '${DateTime.now().millisecondsSinceEpoch}_status',
      type: OfflineActionType.statusUpdate,
      data: {'orderId': orderId, 'status': status},
      timestamp: DateTime.now(),
    );
    _addToQueue(action);
  }

  /// Queue a location update
  void queueLocationUpdate(Position position, {String? orderId}) {
    final action = OfflineAction(
      id: '${DateTime.now().millisecondsSinceEpoch}_location',
      type: OfflineActionType.locationUpdate,
      data: {
        'lat': position.latitude,
        'lng': position.longitude,
        if (orderId != null) 'orderId': orderId,
      },
      timestamp: DateTime.now(),
    );
    _addToQueue(action);
  }

  /// Queue accept order action
  void queueAcceptOrder(String orderId) {
    final action = OfflineAction(
      id: '${DateTime.now().millisecondsSinceEpoch}_accept',
      type: OfflineActionType.acceptOrder,
      data: {'orderId': orderId},
      timestamp: DateTime.now(),
    );
    _addToQueue(action);
  }

  /// Queue reject order action
  void queueRejectOrder(String orderId) {
    final action = OfflineAction(
      id: '${DateTime.now().millisecondsSinceEpoch}_reject',
      type: OfflineActionType.rejectOrder,
      data: {'orderId': orderId},
      timestamp: DateTime.now(),
    );
    _addToQueue(action);
  }

  /// Add action to queue
  void _addToQueue(OfflineAction action) {
    _queue.add(action);
    _saveQueue();
    
    debugPrint('[OfflineService] Queued action: ${action.type.name}');
    
    // Try to sync immediately if online
    if (_isOnline) {
      _scheduleSyncDebounced();
    }
  }

  /// Sync queued actions
  Future<void> syncQueuedActions() async {
    if (_isSyncing || _queue.isEmpty) {
      return;
    }

    // Double-check connectivity
    final result = await _connectivity.checkConnectivity();
    if (result == ConnectivityResult.none) {
      debugPrint('[OfflineService] Still offline, cannot sync');
      return;
    }

    _isSyncing = true;
    debugPrint('[OfflineService] Starting sync. Queue size: ${_queue.length}');

    final actionsToSync = List<OfflineAction>.from(_queue);
    final syncedActions = <String>[];
    final failedActions = <OfflineAction>[];

    for (final action in actionsToSync) {
      try {
        final success = await _executeAction(action);
        
        if (success) {
          syncedActions.add(action.id);
          debugPrint('[OfflineService] Synced: ${action.type.name}');
        } else {
          // Increment retry count
          if (action.retryCount < _maxRetries) {
            failedActions.add(action.copyWith(retryCount: action.retryCount + 1));
            debugPrint('[OfflineService] Retry ${action.retryCount + 1}/$_maxRetries: ${action.type.name}');
          } else {
            debugPrint('[OfflineService] Max retries exceeded, discarding: ${action.type.name}');
          }
        }
      } catch (e) {
        debugPrint('[OfflineService] Sync error: $e');
        // Connection lost during sync
        if (e.toString().contains('SocketException') || 
            e.toString().contains('TimeoutException')) {
          break; // Stop syncing
        }
        
        // Other errors - retry if under limit
        if (action.retryCount < _maxRetries) {
          failedActions.add(action.copyWith(retryCount: action.retryCount + 1));
        }
      }
    }

    // Update queue: remove synced, keep failed for retry
    _queue.removeWhere((action) => syncedActions.contains(action.id));
    _queue.addAll(failedActions);
    await _saveQueue();

    _isSyncing = false;

    debugPrint('[OfflineService] Sync completed. Synced: ${syncedActions.length}, Failed: ${failedActions.length}, Remaining: ${_queue.length}');
  }

  /// Execute a queued action
  Future<bool> _executeAction(OfflineAction action) async {
    try {
      switch (action.type) {
        case OfflineActionType.statusUpdate:
          final orderId = action.data['orderId'] as String;
          final status = action.data['status'] as String;
          await _riderService.updateOrderStatus(orderId, status);
          return true;

        case OfflineActionType.locationUpdate:
          final lat = action.data['lat'] as double;
          final lng = action.data['lng'] as double;
          final orderId = action.data['orderId'] as String?;
          await _riderService.updateLocation(lat, lng, orderId: orderId);
          return true;

        case OfflineActionType.acceptOrder:
          final orderId = action.data['orderId'] as String;
          await _riderService.acceptOrder(orderId);
          return true;

        case OfflineActionType.rejectOrder:
          final orderId = action.data['orderId'] as String;
          await _riderService.rejectOrder(orderId);
          return true;

        case OfflineActionType.updateProfile:
          // Implement profile update
          return true;

        default:
          return false;
      }
    } catch (e) {
      debugPrint('[OfflineService] Action execution failed: $e');
      return false;
    }
  }

  /// Load queue from storage
  Future<void> _loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_queueKey);
      
      if (queueJson != null) {
        final List<dynamic> decoded = jsonDecode(queueJson);
        _queue = decoded
            .map((item) => OfflineAction.fromJson(item as Map<String, dynamic>))
            .toList();
        
        debugPrint('[OfflineService] Loaded ${_queue.length} queued actions');
      }
    } catch (e) {
      debugPrint('[OfflineService] Failed to load queue: $e');
      _queue = [];
    }
  }

  /// Save queue to storage
  Future<void> _saveQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = jsonEncode(_queue.map((a) => a.toJson()).toList());
      await prefs.setString(_queueKey, queueJson);
    } catch (e) {
      debugPrint('[OfflineService] Failed to save queue: $e');
    }
  }

  /// Clear all queued actions
  Future<void> clearQueue() async {
    _queue.clear();
    await _saveQueue();
    debugPrint('[OfflineService] Queue cleared');
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
  }
}
