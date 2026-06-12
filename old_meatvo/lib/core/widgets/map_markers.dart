import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:widget_to_marker/widget_to_marker.dart';

class OrderStop {
  final double lat;
  final double lng;
  final String orderId;
  final String customerName;
  final String address;
  final String status;
  final Map<String, dynamic> originalData;

  OrderStop({
    required this.lat,
    required this.lng,
    required this.orderId,
    required this.customerName,
    required this.address,
    required this.status,
    required this.originalData,
  });
}

class OrderCluster {
  final double lat;
  final double lng;
  final List<OrderStop> orders;
  final int count;

  OrderCluster({
    required this.lat,
    required this.lng,
    required this.orders,
    required this.count,
  });
}

class MapMarkers {
  // Store marker — red circle, storefront icon
  static Future<BitmapDescriptor> storeMarker() async {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFC8102E),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: const Icon(Icons.storefront, color: Colors.white, size: 24),
    ).toBitmapDescriptor(
      logicalSize: const Size(48, 48),
      imageSize: const Size(96, 96),
    );
  }

  // Delivery partner — red circle, scooter icon
  static Future<BitmapDescriptor> riderMarker() async {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFC8102E),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: const Icon(Icons.delivery_dining, color: Colors.white, size: 26),
    ).toBitmapDescriptor(
      logicalSize: const Size(48, 48),
      imageSize: const Size(96, 96),
    );
  }

  // Home destination — green circle
  static Future<BitmapDescriptor> homeMarker() async {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF2ECC71),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: const Icon(Icons.home_rounded, color: Colors.white, size: 22),
    ).toBitmapDescriptor(
      logicalSize: const Size(44, 44),
      imageSize: const Size(88, 88),
    );
  }

  // Numbered stop — white circle, red border + number
  static Future<BitmapDescriptor> numberedStop(
    int number, {
    bool delivered = false,
  }) async {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: delivered ? const Color(0xFFE0E0E0) : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: delivered ? const Color(0xFF9E9E9E) : const Color(0xFFC8102E),
          width: 2,
        ),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Center(
        child: Text(
          '$number',
          style: TextStyle(
            color: delivered ? const Color(0xFF9E9E9E) : const Color(0xFFC8102E),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ).toBitmapDescriptor(
      logicalSize: const Size(40, 40),
      imageSize: const Size(80, 80),
    );
  }

  // Density dot — small filled circle, color by order count in area
  static Future<BitmapDescriptor> densityDot({
    required Color color,
    required int orderCount,
  }) async {
    final size = orderCount == 1
        ? 20.0
        : orderCount <= 3
            ? 28.0
            : orderCount <= 6
                ? 36.0
                : 44.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.85),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4),
        ],
      ),
      child: orderCount > 1
          ? Center(
              child: Text(
                '$orderCount',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    ).toBitmapDescriptor(
      logicalSize: Size(size, size),
      imageSize: Size(size * 2, size * 2),
    );
  }

  // Get color based on order count (density)
  static Color densityColor(int count) {
    if (count == 1) return const Color(0xFF4CAF50); // green
    if (count <= 3) return const Color(0xFFFF9800); // orange
    if (count <= 6) return const Color(0xFFF44336); // red
    return const Color(0xFF9C27B0); // purple (hot zone)
  }

  // Group orders within 500m radius into clusters
  static List<OrderCluster> clusterOrders(List<OrderStop> stops) {
    List<OrderCluster> clusters = [];
    List<bool> assigned = List.filled(stops.length, false);

    for (int i = 0; i < stops.length; i++) {
      if (assigned[i]) continue;

      List<OrderStop> group = [stops[i]];
      assigned[i] = true;

      for (int j = i + 1; j < stops.length; j++) {
        if (assigned[j]) continue;
        double dist = haversineMeters(
          stops[i].lat,
          stops[i].lng,
          stops[j].lat,
          stops[j].lng,
        );
        if (dist <= 500) {
          group.add(stops[j]);
          assigned[j] = true;
        }
      }

      double centerLat =
          group.map((s) => s.lat).reduce((a, b) => a + b) / group.length;
      double centerLng =
          group.map((s) => s.lng).reduce((a, b) => a + b) / group.length;

      clusters.add(OrderCluster(
        lat: centerLat,
        lng: centerLng,
        orders: group,
        count: group.length,
      ));
    }
    return clusters;
  }

  // Calculate distance between two points in meters using Haversine formula
  static double haversineMeters(
      double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000; // Earth radius in meters
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }
}
