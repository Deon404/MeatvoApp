import 'package:dio/dio.dart';

import '../config/store_config.dart';
import 'api_service.dart';

/// Delivery Service
/// Handles delivery radius validation and distance calculations
class DeliveryService {
  final ApiService _api = ApiService();

  /// Validate if delivery address is within store delivery zone (backend).
  /// Falls back to [StoreConfig] on network errors.
  Future<DeliveryValidationResult> validateDeliveryAddress({
    required double latitude,
    required double longitude,
    bool skipGeocoding = false,
  }) async {
    try {
      final res = await _api.post(
        '/store/check-delivery',
        data: {'lat': latitude, 'lng': longitude},
      );
      final data = res.data;
      if (data is Map && (data['success'] == true || data['ok'] == true)) {
        final payload = data['data'];
        final distanceKm = payload is Map
            ? (payload['distanceKm'] as num?)?.toDouble()
            : null;
        return DeliveryValidationResult(
          isValid: true,
          distance: distanceKm ?? 0,
          distanceFormatted: distanceKm != null
              ? '${distanceKm.toStringAsFixed(1)} km'
              : '',
          message: 'Delivery available',
        );
      }

      final body =
          data is Map ? data.cast<String, dynamic>() : <String, dynamic>{};
      final distanceKm = (body['distanceKm'] as num?)?.toDouble() ?? 0;
      return DeliveryValidationResult(
        isValid: false,
        distance: distanceKm,
        distanceFormatted: distanceKm > 0
            ? '${distanceKm.toStringAsFixed(1)} km'
            : '',
        message: body['message']?.toString() ??
            'Delivery not available in your area',
        errorType: DeliveryErrorType.outOfRadius,
      );
    } on DioException catch (e) {
      final body = e.response?.data;
      if (body is Map && body['success'] != true) {
        final map = body.cast<String, dynamic>();
        final distanceKm = (map['distanceKm'] as num?)?.toDouble() ?? 0;
        return DeliveryValidationResult(
          isValid: false,
          distance: distanceKm,
          distanceFormatted: distanceKm > 0
              ? '${distanceKm.toStringAsFixed(1)} km'
              : '',
          message: map['message']?.toString() ??
              'Delivery not available in your area',
          errorType: DeliveryErrorType.outOfRadius,
        );
      }

      final distance = StoreConfig.getDistanceFromStore(latitude, longitude);
      final isWithinRadius =
          StoreConfig.isWithinDeliveryRadius(latitude, longitude);
      return DeliveryValidationResult(
        isValid: isWithinRadius,
        distance: distance,
        distanceFormatted:
            StoreConfig.getFormattedDistance(latitude, longitude),
        message: isWithinRadius
            ? 'Delivery available'
            : 'Outside delivery zone',
        errorType: isWithinRadius ? null : DeliveryErrorType.outOfRadius,
      );
    } catch (e) {
      final distance = StoreConfig.getDistanceFromStore(latitude, longitude);
      final isWithinRadius =
          StoreConfig.isWithinDeliveryRadius(latitude, longitude);
      return DeliveryValidationResult(
        isValid: isWithinRadius,
        distance: distance,
        distanceFormatted:
            StoreConfig.getFormattedDistance(latitude, longitude),
        message: isWithinRadius
            ? 'Delivery available'
            : 'Outside delivery zone',
        errorType: isWithinRadius ? null : DeliveryErrorType.outOfRadius,
      );
    }
  }

  /// Validate delivery address from address model
  Future<DeliveryValidationResult> validateDeliveryAddressFromModel({
    required double? latitude,
    required double? longitude,
  }) async {
    if (latitude == null || longitude == null) {
      return DeliveryValidationResult(
        isValid: false,
        distance: 0.0,
        distanceFormatted: 'N/A',
        message: 'Delivery address coordinates are missing. Please select location on map.',
        errorType: DeliveryErrorType.missingCoordinates,
      );
    }

    return await validateDeliveryAddress(
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// Check if order can be placed at given address
  /// Throws exception if address is out of delivery radius
  Future<void> ensureDeliveryAvailable({
    required double latitude,
    required double longitude,
  }) async {
    final validation = await validateDeliveryAddress(
      latitude: latitude,
      longitude: longitude,
    );

    if (!validation.isValid) {
      throw DeliveryException(
        validation.message,
        validation.errorType ?? DeliveryErrorType.outOfRadius,
        validation.distance,
      );
    }
  }

  /// Get estimated delivery time based on distance
  /// Returns time in minutes
  int getEstimatedDeliveryTime(double distanceKm) {
    // Base time: 10 minutes
    // Additional time: 2 minutes per km
    // Maximum: 30 minutes
    final baseTime = 10;
    final additionalTime = (distanceKm * 2).round();
    final totalTime = baseTime + additionalTime;
    
    return totalTime > StoreConfig.maxDeliveryTimeMinutes
        ? StoreConfig.maxDeliveryTimeMinutes
        : totalTime;
  }

  /// Get delivery charge based on distance
  /// Returns delivery charge in rupees
  double getDeliveryCharge(double distanceKm) {
    // Free delivery for orders above ₹500
    // Otherwise: ₹30 base + ₹5 per km (max ₹50)
    const double baseCharge = 30.0;
    const double perKmCharge = 5.0;
    const double maxCharge = 50.0;
    
    final charge = baseCharge + (distanceKm * perKmCharge);
    return charge > maxCharge ? maxCharge : charge;
  }
}

/// Delivery Validation Result
class DeliveryValidationResult {
  final bool isValid;
  final double distance;
  final String distanceFormatted;
  final String? address;
  final String message;
  final DeliveryErrorType? errorType;

  DeliveryValidationResult({
    required this.isValid,
    required this.distance,
    required this.distanceFormatted,
    this.address,
    required this.message,
    this.errorType,
  });
}

/// Delivery Exception
class DeliveryException implements Exception {
  final String message;
  final DeliveryErrorType errorType;
  final double distance;

  DeliveryException(this.message, this.errorType, this.distance);

  @override
  String toString() => message;
}

/// Delivery Error Types
enum DeliveryErrorType {
  outOfRadius,
  missingCoordinates,
  serviceUnavailable,
}
