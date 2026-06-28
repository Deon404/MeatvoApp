import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../config/api_config.dart';
import 'api_service.dart';
import 'maps_service.dart';
import 'socket_service.dart';

/// Sends rider GPS to the backend during an active delivery.
/// Backend broadcasts `delivery:location` to the customer's socket room.
/// Uses smart updates: location change (50m) OR max 30s interval.
class RiderLocationService {
  static final RiderLocationService _instance =
      RiderLocationService._internal();
  factory RiderLocationService() => _instance;

  final ApiService _api;
  final MapsService _mapsService;
  final SocketService _socketService;

  RiderLocationService._internal()
      : _api = ApiService(),
        _mapsService = MapsService(),
        _socketService = SocketService();

  StreamSubscription<Position>? _positionSubscription;
  Timer? _backupTimer;
  Position? _lastSentPosition;
  String? _activeOrderId;

  /// Start tracking with smart updates
  void startSendingLocation(String orderId) {
    if (orderId.isEmpty) return;
    if (_activeOrderId == orderId && _positionSubscription != null) return;

    _activeOrderId = orderId;
    stopSendingLocation();

    // Primary: geolocator stream with 50m distance filter
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50, // Update on 50m movement
      ),
    ).listen(
      (Position position) => unawaited(_handleLocationUpdate(position)),
      onError: (e) {
        debugPrint('[RiderLocation] Stream error: $e');
      },
    );

    // Backup: 30s max interval timer
    _backupTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_forceLocationUpdate()),
    );

    // Send initial location immediately
    unawaited(_forceLocationUpdate());
  }

  Future<void> _handleLocationUpdate(Position position) async {
    _lastSentPosition = position;
    await _sendLocationToBackend(position);
  }

  Future<void> _forceLocationUpdate() async {
    try {
      final position = await _mapsService.getCurrentLocation(
        forceRequest: false,
        timeLimit: const Duration(seconds: 10),
      );
      if (position != null) {
        _lastSentPosition = position;
        await _sendLocationToBackend(position);
      }
    } catch (e) {
      debugPrint('[RiderLocation] Force update failed: $e');
    }
  }

  Future<void> _sendLocationToBackend(Position position) async {
    final orderId = _activeOrderId;
    if (orderId == null) return;

    try {
      final lat = position.latitude;
      final lng = position.longitude;
      final parsedOrderId = int.tryParse(orderId);
      final payload = <String, dynamic>{
        'lat': lat,
        'lng': lng,
        if (parsedOrderId != null) 'orderId': parsedOrderId else 'orderId': orderId,
      };

      try {
        await _api.put(ApiDeliveryPaths.location, data: payload);
      } on DioException catch (e) {
        debugPrint(
          '[RiderLocation] PUT failed: ${e.response?.data?['message'] ?? e.message}',
        );
      } catch (e) {
        debugPrint('[RiderLocation] PUT failed: $e');
      }

      await _socketService.connect();
      if (_socketService.isConnected) {
        _socketService.emit('rider_location', {
          'orderId': parsedOrderId ?? orderId,
          'lat': lat,
          'lng': lng,
        });
      }
    } catch (e) {
      debugPrint('[RiderLocation] GPS unavailable (silent): $e');
    }
  }

  void stopSendingLocation() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _backupTimer?.cancel();
    _backupTimer = null;
    _lastSentPosition = null;
    _activeOrderId = null;
  }
}

final riderLocationServiceProvider = Provider<RiderLocationService>((ref) {
  return RiderLocationService();
});
