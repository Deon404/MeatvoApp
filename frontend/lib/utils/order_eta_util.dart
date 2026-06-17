import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

/// Matches backend [EXPRESS_AVG_SPEED_KMH] — realistic city delivery speed.
const double expressAvgSpeedKmh = 22.0;

/// True when the rider is en route to the customer (travel-only ETA applies).
bool isOrderOutForDelivery(String status) {
  switch (status.toLowerCase()) {
    case 'out_for_delivery':
    case 'on_the_way':
    case 'on_way':
    case 'picked_up':
    case 'rider_nearby':
      return true;
    default:
      return false;
  }
}

/// Remaining kitchen / handoff time before the rider can leave for delivery.
int remainingPrepMinutes(String status) {
  switch (status.toLowerCase()) {
    case 'packed':
    case 'rider_assigned':
    case 'accepted':
    case 'rider_accepted':
      return 3;
    case 'preparing':
    case 'packing_started':
    case 'packing':
      return 8;
    case 'placed':
    case 'confirmed':
    case 'payment_pending':
    case 'payment_verified':
    default:
      return 12;
  }
}

/// Minimum travel minutes for a given road distance at express delivery speed.
int minimumTravelMinutes(double distanceKm, [int? routeMinutes]) {
  if (distanceKm <= 0) {
    return routeMinutes ?? 1;
  }
  final speedBased = (distanceKm / expressAvgSpeedKmh * 60).ceil();
  if (routeMinutes == null) return math.max(1, speedBased);
  return math.max(routeMinutes, speedBased);
}

/// Customer-facing ETA: prep (if applicable) + travel + small buffer.
int composeCustomerEtaMinutes({
  required String status,
  required int travelMinutes,
  double distanceKm = 0,
  int bufferMinutes = 5,
}) {
  if (isOrderOutForDelivery(status)) {
    final travel = minimumTravelMinutes(distanceKm, travelMinutes);
    return travel + 2;
  }

  final prep = remainingPrepMinutes(status);
  final travel = minimumTravelMinutes(distanceKm, travelMinutes);
  return prep + travel + bufferMinutes;
}

String formatEtaMinutesLabel(int minutes) {
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rem = minutes % 60;
  if (rem == 0) return '$hours hr';
  return '$hours hr $rem min';
}

/// Parse "11.8 km" / "850 m" strings from route callbacks.
double? parseRouteDistanceKm(String? distanceText) {
  if (distanceText == null || distanceText.trim().isEmpty) return null;
  final normalized = distanceText.trim().toLowerCase();
  final kmMatch = RegExp(r'([\d.]+)\s*km').firstMatch(normalized);
  if (kmMatch != null) {
    return double.tryParse(kmMatch.group(1)!);
  }
  final mMatch = RegExp(r'([\d.]+)\s*m').firstMatch(normalized);
  if (mMatch != null) {
    final meters = double.tryParse(mMatch.group(1)!);
    if (meters != null) return meters / 1000;
  }
  return null;
}

/// Straight-line distance in km between two GPS points.
double distanceKmBetween({
  required double startLat,
  required double startLng,
  required double endLat,
  required double endLng,
}) {
  return Geolocator.distanceBetween(startLat, startLng, endLat, endLng) / 1000;
}

String formatDistanceKm(double distanceKm) {
  if (distanceKm < 1) {
    return '${(distanceKm * 1000).round()} m';
  }
  return '${distanceKm.toStringAsFixed(1)} km';
}

/// Rider → customer ETA using GPS (works before Google Directions returns).
int? computeRiderCustomerEta({
  required String status,
  required double riderLat,
  required double riderLng,
  required double customerLat,
  required double customerLng,
}) {
  final distanceKm = distanceKmBetween(
    startLat: riderLat,
    startLng: riderLng,
    endLat: customerLat,
    endLng: customerLng,
  );
  if (distanceKm <= 0) return null;

  // Road distance is typically ~20% longer than straight-line.
  final roadDistanceKm = distanceKm * 1.2;
  final travelMinutes = minimumTravelMinutes(roadDistanceKm, null);

  return composeCustomerEtaMinutes(
    status: status,
    travelMinutes: travelMinutes,
    distanceKm: roadDistanceKm,
  );
}
