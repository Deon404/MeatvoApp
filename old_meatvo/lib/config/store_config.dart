import 'dart:math' as math;

/// Store Configuration
/// Contains store location and delivery settings for Chira Chas, Bokaro store
class StoreConfig {
  // Store Location - Chira Chas, Bokaro, Jharkhand, India
  static const double storeLatitude = 23.6583;
  static const double storeLongitude = 86.1764;

  // Store Address (for display)
  static const String storeAddress = 'Chira Chas, Bokaro, Jharkhand 827013';
  static const String storeName = 'Meatvo';
  
  // Delivery Configuration
  static const double deliveryRadiusKm = 8.0; // 8 kilometers delivery radius
  static const int maxDeliveryTimeMinutes = 120; // Express delivery window (1-2 hours)
  
  // Business Hours (Optional - for future use)
  static const String openingTime = '08:00'; // 8 AM
  static const String closingTime = '22:00'; // 10 PM
  
  /// Check if coordinates are within delivery radius
  static bool isWithinDeliveryRadius(double latitude, double longitude) {
    final distance = _calculateDistance(
      storeLatitude,
      storeLongitude,
      latitude,
      longitude,
    );
    return distance <= deliveryRadiusKm;
  }
  
  /// Calculate distance from store to given coordinates (in kilometers)
  static double getDistanceFromStore(double latitude, double longitude) {
    return _calculateDistance(
      storeLatitude,
      storeLongitude,
      latitude,
      longitude,
    );
  }
  
  /// Calculate distance between two coordinates using Haversine formula
  /// Returns distance in kilometers
  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // Earth radius in kilometers
    
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    
    final double c = 2 * math.asin(math.sqrt(a));
    
    return earthRadius * c;
  }
  
  static double _degreesToRadians(double degrees) {
    return degrees * (3.141592653589793 / 180);
  }
  
  /// Get formatted distance string
  static String getFormattedDistance(double latitude, double longitude) {
    final distance = getDistanceFromStore(latitude, longitude);
    if (distance < 1.0) {
      return '${(distance * 1000).round()} m';
    } else {
      return '${distance.toStringAsFixed(1)} km';
    }
  }
  
  /// Validate if address is within delivery radius
  /// Returns validation result with message
  static Map<String, dynamic> validateDeliveryAddress(
    double latitude,
    double longitude,
  ) {
    final distance = getDistanceFromStore(latitude, longitude);
    final isWithin = distance <= deliveryRadiusKm;
    
    return {
      'isValid': isWithin,
      'distance': distance,
      'distanceFormatted': getFormattedDistance(latitude, longitude),
      'message': isWithin
          ? 'Delivery available at this location'
          : 'Delivery not available. This location is ${distance.toStringAsFixed(1)}km away. We deliver within ${deliveryRadiusKm}km radius only.',
    };
  }
}

