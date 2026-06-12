import '../config/store_config.dart';
import '../services/maps_service.dart';

/// Delivery Service
/// Handles delivery radius validation and distance calculations
class DeliveryService {
  final MapsService _mapsService = MapsService();

  /// Validate if delivery address is within 8km radius
  /// Returns validation result with detailed information
  Future<DeliveryValidationResult> validateDeliveryAddress({
    required double latitude,
    required double longitude,
  }) async {
    // Calculate distance from store
    final distance = StoreConfig.getDistanceFromStore(latitude, longitude);
    final isWithinRadius = StoreConfig.isWithinDeliveryRadius(latitude, longitude);
    
    // Get formatted address for better error messages
    String? addressString;
    try {
      final address = await _mapsService.getAddressFromCoordinates(
        latitude: latitude,
        longitude: longitude,
      );
      if (address != null) {
        addressString = _buildAddressString(address);
      }
    } catch (e) {
      // Address fetch failed, but we can still validate distance
    }

    return DeliveryValidationResult(
      isValid: isWithinRadius,
      distance: distance,
      distanceFormatted: StoreConfig.getFormattedDistance(latitude, longitude),
      address: addressString,
      message: isWithinRadius
          ? 'Delivery available at this location'
          : 'Delivery not available. This location is ${distance.toStringAsFixed(1)}km away from our store. We deliver within ${StoreConfig.deliveryRadiusKm}km radius only. Please select a different address.',
      errorType: isWithinRadius ? null : DeliveryErrorType.outOfRadius,
    );
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

  String _buildAddressString(Map<String, dynamic> address) {
    final parts = <String>[];
    
    if (address['address_line1'] != null) {
      parts.add(address['address_line1'] as String);
    }
    if (address['address_line2'] != null) {
      parts.add(address['address_line2'] as String);
    }
    if (address['city'] != null) {
      parts.add(address['city'] as String);
    }
    if (address['state'] != null) {
      parts.add(address['state'] as String);
    }

    return parts.join(', ');
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
