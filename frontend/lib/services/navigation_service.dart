import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'maps_service.dart';

/// Navigation route data
class NavigationRoute {
  final List<LatLng> polylinePoints;
  final String duration;
  final String distance;
  final int durationValue;
  final int distanceValue;
  final String? nextTurn;

  const NavigationRoute({
    required this.polylinePoints,
    required this.duration,
    required this.distance,
    required this.durationValue,
    required this.distanceValue,
    this.nextTurn,
  });
}

/// Service for navigation and route calculations
class NavigationService {
  final MapsService _mapsService = MapsService();

  /// Calculate route from origin to destination
  Future<NavigationRoute?> calculateRoute({
    required LatLng origin,
    required LatLng destination,
    bool avoidTolls = false,
  }) async {
    try {
      final result = await _mapsService.getDrivingRoute(
        originLat: origin.latitude,
        originLng: origin.longitude,
        destLat: destination.latitude,
        destLng: destination.longitude,
      );

      if (result == null) return null;

      // Convert points to LatLng
      final polylinePoints = result.points
          .map((point) => LatLng(point.lat, point.lng))
          .toList();

      return NavigationRoute(
        polylinePoints: polylinePoints,
        duration: result.durationFormatted,
        distance: result.distanceFormatted,
        durationValue: result.durationMinutes * 60,
        distanceValue: (result.distanceKm * 1000).toInt(),
        nextTurn: null, // Can be extracted from detailed directions if needed
      );
    } catch (e) {
      return null;
    }
  }

  /// Format ETA for display
  String formatETA(int durationSeconds) {
    if (durationSeconds < 60) {
      return 'Less than a minute';
    }

    final minutes = (durationSeconds / 60).round();
    
    if (minutes < 60) {
      return '$minutes min${minutes > 1 ? 's' : ''}';
    }

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    
    if (remainingMinutes == 0) {
      return '$hours hour${hours > 1 ? 's' : ''}';
    }
    
    return '$hours hour${hours > 1 ? 's' : ''} $remainingMinutes min${remainingMinutes > 1 ? 's' : ''}';
  }

  /// Format distance for display
  String formatDistance(int distanceMeters) {
    if (distanceMeters < 1000) {
      return '$distanceMeters m';
    }

    final km = distanceMeters / 1000;
    
    if (km < 10) {
      return '${km.toStringAsFixed(1)} km';
    }
    
    return '${km.toStringAsFixed(0)} km';
  }

  /// Launch Google Maps app for turn-by-turn navigation
  Future<bool> launchGoogleMapsNavigation({
    required LatLng destination,
    LatLng? origin,
    TravelMode mode = TravelMode.driving,
  }) async {
    try {
      String modeParam;
      switch (mode) {
        case TravelMode.driving:
          modeParam = 'd';
          break;
        case TravelMode.walking:
          modeParam = 'w';
          break;
        case TravelMode.bicycling:
          modeParam = 'b';
          break;
        case TravelMode.transit:
          modeParam = 'r';
          break;
      }

      // Build Google Maps URL
      String url;
      if (origin != null) {
        url = 'https://www.google.com/maps/dir/?api=1'
            '&origin=${origin.latitude},${origin.longitude}'
            '&destination=${destination.latitude},${destination.longitude}'
            '&travelmode=$modeParam';
      } else {
        url = 'https://www.google.com/maps/dir/?api=1'
            '&destination=${destination.latitude},${destination.longitude}'
            '&travelmode=$modeParam';
      }

      final uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        return await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        // Fallback to browser if Google Maps app is not installed
        return await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
      }
    } catch (e) {
      return false;
    }
  }

  /// Get estimated arrival time based on current time and duration
  DateTime getEstimatedArrivalTime(int durationSeconds) {
    return DateTime.now().add(Duration(seconds: durationSeconds));
  }

  /// Format arrival time for display
  String formatArrivalTime(DateTime arrivalTime) {
    final now = DateTime.now();
    final difference = arrivalTime.difference(now);

    if (difference.inMinutes < 1) {
      return 'Arriving now';
    }

    if (difference.inMinutes < 60) {
      return 'Arriving in ${difference.inMinutes} min';
    }

    final hours = arrivalTime.hour;
    final minutes = arrivalTime.minute;
    final period = hours >= 12 ? 'PM' : 'AM';
    final displayHour = hours > 12 ? hours - 12 : (hours == 0 ? 12 : hours);

    return 'Arriving at $displayHour:${minutes.toString().padLeft(2, '0')} $period';
  }
}

enum TravelMode {
  driving,
  walking,
  bicycling,
  transit,
}
