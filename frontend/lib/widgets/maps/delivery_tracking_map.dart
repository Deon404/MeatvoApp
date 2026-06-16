import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../config/env_config.dart';
import '../../config/store_config.dart';
import '../../core/constants/app_constants.dart';
import '../../services/maps_service.dart';
import 'map_marker_helper.dart';

typedef RouteInfoCallback = void Function({
  required String? eta,
  required String? distance,
  required int? etaMinutes,
});

/// Full-screen live delivery map with road routes and animated rider marker.
class DeliveryTrackingMap extends StatefulWidget {
  final double? riderLatitude;
  final double? riderLongitude;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final String? deliveryAddress;
  final String? riderName;
  final String orderStatus;
  final bool expandToFill;
  final double? fixedHeight;
  final bool hideTopBanner;
  final RouteInfoCallback? onRouteInfo;

  const DeliveryTrackingMap({
    super.key,
    this.riderLatitude,
    this.riderLongitude,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.deliveryAddress,
    this.riderName,
    required this.orderStatus,
    this.expandToFill = false,
    this.fixedHeight,
    this.hideTopBanner = false,
    this.onRouteInfo,
  });

  @override
  State<DeliveryTrackingMap> createState() => _DeliveryTrackingMapState();
}

class _DeliveryTrackingMapState extends State<DeliveryTrackingMap>
    with TickerProviderStateMixin {
  final MapsService _mapsService = MapsService();
  GoogleMapController? _mapController;

  LatLng? _storeLocation;
  LatLng? _deliveryLocation;
  LatLng? _animatedRiderPosition;
  LatLng? _previousRiderTarget;

  BitmapDescriptor? _storeIcon;
  BitmapDescriptor? _deliveryIcon;
  BitmapDescriptor? _riderIcon;

  AnimationController? _moveController;
  AnimationController? _pulseController;
  Animation<double>? _moveAnimation;

  List<LatLng> _primaryRoutePoints = [];
  List<LatLng> _riderRoutePoints = [];
  double _riderBearing = 0;
  String? _etaText;
  String? _distanceText;
  int? _etaMinutes;
  bool _iconsReady = false;
  bool _loadingRoute = false;
  Timer? _autoCameraTimer;

  static final LatLng _fallback = LatLng(
    StoreConfig.storeLatitude,
    StoreConfig.storeLongitude,
  );

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    
    _autoCameraTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _smartCameraAdjust(),
    );
    
    _initMap();
  }

  @override
  void didUpdateWidget(covariant DeliveryTrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final riderMoved = widget.riderLatitude != oldWidget.riderLatitude ||
        widget.riderLongitude != oldWidget.riderLongitude;
    final deliveryMoved = widget.deliveryLatitude != oldWidget.deliveryLatitude ||
        widget.deliveryLongitude != oldWidget.deliveryLongitude;

    if (riderMoved) _handleRiderUpdate();
    if (deliveryMoved) {
      _setDeliveryLocation();
      _fetchRoutes();
    }
  }

  Future<void> _initMap() async {
    _storeLocation = LatLng(StoreConfig.storeLatitude, StoreConfig.storeLongitude);
    _setDeliveryLocation();

    final icons = await Future.wait([
      MapMarkerHelper.storePin(),
      MapMarkerHelper.homePin(),
      MapMarkerHelper.riderPin(),
    ]);

    if (!mounted) return;
    setState(() {
      _storeIcon = icons[0];
      _deliveryIcon = icons[1];
      _riderIcon = icons[2];
      _iconsReady = true;
    });

    _handleRiderUpdate();
    await _fetchRoutes();
  }

  void _setDeliveryLocation() {
    if (widget.deliveryLatitude != null && widget.deliveryLongitude != null) {
      _deliveryLocation = LatLng(
        widget.deliveryLatitude!,
        widget.deliveryLongitude!,
      );
    }
  }

  Future<void> _fetchRoutes() async {
    final delivery = _deliveryLocation;
    if (delivery == null) return;

    setState(() => _loadingRoute = true);

    final storeRoute = _storeLocation != null
        ? await _mapsService.getDrivingRoute(
            originLat: _storeLocation!.latitude,
            originLng: _storeLocation!.longitude,
            destLat: delivery.latitude,
            destLng: delivery.longitude,
          )
        : null;

    DrivingRouteResult? activeRoute = storeRoute;
    List<LatLng> riderPts = [];

    if (_animatedRiderPosition != null) {
      final riderRoute = await _mapsService.getDrivingRoute(
        originLat: _animatedRiderPosition!.latitude,
        originLng: _animatedRiderPosition!.longitude,
        destLat: delivery.latitude,
        destLng: delivery.longitude,
      );
      if (riderRoute != null) {
        activeRoute = riderRoute;
        riderPts = riderRoute.points
            .map((p) => LatLng(p.lat, p.lng))
            .toList();
      }
    }

    if (activeRoute == null) {
      final origin = _animatedRiderPosition ?? _storeLocation;
      if (origin != null) {
        final fallback = _mapsService.calculateRouteInfo(
          startLatitude: origin.latitude,
          startLongitude: origin.longitude,
          endLatitude: delivery.latitude,
          endLongitude: delivery.longitude,
        );
        activeRoute = DrivingRouteResult(
          points: [],
          distanceKm: fallback['distance'] as double,
          durationMinutes: fallback['eta'] as int,
          distanceFormatted: fallback['distanceFormatted'] as String,
          durationFormatted: fallback['etaFormatted'] as String,
        );
      }
    }

    if (!mounted) return;

    setState(() {
      _loadingRoute = false;
      
      // Build primary route with exact start/end points
      if (storeRoute != null && storeRoute.points.isNotEmpty) {
        _primaryRoutePoints = [
          if (_storeLocation != null) _storeLocation!,
          ...storeRoute.points.map((p) => LatLng(p.lat, p.lng)),
          delivery,
        ];
        // Remove duplicates that are very close (within ~5 meters)
        _primaryRoutePoints = _removeDuplicatePoints(_primaryRoutePoints);
      } else if (_storeLocation != null && _animatedRiderPosition == null) {
        // Fallback: draw straight line from store to delivery
        _primaryRoutePoints = [_storeLocation!, delivery];
      } else {
        _primaryRoutePoints = [];
      }
      
      // Build rider route with exact start/end points
      if (riderPts.isNotEmpty) {
        _riderRoutePoints = [
          if (_animatedRiderPosition != null) _animatedRiderPosition!,
          ...riderPts,
          delivery,
        ];
        _riderRoutePoints = _removeDuplicatePoints(_riderRoutePoints);
      } else if (_animatedRiderPosition != null) {
        // Fallback: draw straight line from rider to delivery
        _riderRoutePoints = [_animatedRiderPosition!, delivery];
      } else {
        _riderRoutePoints = [];
      }
      
      if (activeRoute != null) {
        _etaText = activeRoute.durationFormatted;
        _distanceText = activeRoute.distanceFormatted;
        _etaMinutes = activeRoute.durationMinutes;
      }
    });

    widget.onRouteInfo?.call(
      eta: _etaText,
      distance: _distanceText,
      etaMinutes: _etaMinutes,
    );

    _fitCamera();
  }

  void _handleRiderUpdate() {
    if (widget.riderLatitude == null || widget.riderLongitude == null) {
      return;
    }

    final target = LatLng(widget.riderLatitude!, widget.riderLongitude!);
    if (_animatedRiderPosition == null) {
      setState(() => _animatedRiderPosition = target);
      _previousRiderTarget = target;
      _fetchRoutes();
      return;
    }

    if (_previousRiderTarget != null &&
        _previousRiderTarget!.latitude == target.latitude &&
        _previousRiderTarget!.longitude == target.longitude) {
      return;
    }

    _animateRiderTo(target);
    _previousRiderTarget = target;
  }

  void _animateRiderTo(LatLng target) {
    final start = _animatedRiderPosition ?? target;
    final distance = _calculateDistance(start, target);
    _riderBearing = _bearing(start, target);

    _moveController?.dispose();
    
    // Dynamic duration based on distance - faster for short moves, slower for long
    final baseDuration = (distance * 2000).clamp(800, 2500).toInt();
    
    _moveController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: baseDuration),
    );

    // Elastic curve for more realistic movement
    _moveAnimation = CurvedAnimation(
      parent: _moveController!,
      curve: Curves.easeInOutCubic,
    );

    _moveAnimation!.addListener(() {
      if (!mounted) return;
      final t = _moveAnimation!.value;
      setState(() {
        _animatedRiderPosition = LatLng(
          start.latitude + (target.latitude - start.latitude) * t,
          start.longitude + (target.longitude - start.longitude) * t,
        );
      });
      
      // Smooth camera follow during animation
      if (t > 0.3 && t < 0.7) {
        _smoothCameraFollow();
      }
    });

    _moveController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _fetchRoutes();
        _smartCameraAdjust();
      }
    });

    _moveController!.forward();
  }

  double _calculateDistance(LatLng from, LatLng to) {
    const earthRadius = 6371.0;
    final dLat = (to.latitude - from.latitude) * math.pi / 180;
    final dLng = (to.longitude - from.longitude) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(from.latitude * math.pi / 180) *
            math.cos(to.latitude * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _bearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLon = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  /// Remove duplicate points that are very close to each other (within ~5 meters)
  List<LatLng> _removeDuplicatePoints(List<LatLng> points) {
    if (points.isEmpty) return points;
    
    final result = <LatLng>[points.first];
    const minDistanceKm = 0.005; // ~5 meters
    
    for (int i = 1; i < points.length; i++) {
      final distance = _calculateDistance(result.last, points[i]);
      if (distance > minDistanceKm) {
        result.add(points[i]);
      }
    }
    
    return result;
  }

  void _fitCamera() {
    if (_mapController == null) return;

    final activeRoute = _riderRoutePoints.isNotEmpty
        ? _riderRoutePoints
        : _primaryRoutePoints;

    final points = <LatLng>[
      if (_storeLocation != null) _storeLocation!,
      if (_deliveryLocation != null) _deliveryLocation!,
      if (_animatedRiderPosition != null) _animatedRiderPosition!,
      ...activeRoute,
    ];
    if (points.isEmpty) return;

    if (points.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(points.first, 14),
      );
      return;
    }

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }

  /// Smart camera adjustment - keeps route visible while following rider
  void _smartCameraAdjust() {
    if (_mapController == null || !mounted) return;

    final activeRoute = _riderRoutePoints.isNotEmpty
        ? _riderRoutePoints
        : _primaryRoutePoints;

    // Collect all important points
    final points = <LatLng>[
      if (_storeLocation != null) _storeLocation!,
      if (_deliveryLocation != null) _deliveryLocation!,
      if (_animatedRiderPosition != null) _animatedRiderPosition!,
      ...activeRoute,
    ];

    if (points.isEmpty) {
      return;
    }

    // Calculate bounds
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }

    // Add 35% padding for breathing room
    final latPadding = (maxLat - minLat) * 0.35;
    final lngPadding = (maxLng - minLng) * 0.35;

    final bounds = LatLngBounds(
      southwest: LatLng(
        minLat - latPadding,
        minLng - lngPadding,
      ),
      northeast: LatLng(
        maxLat + latPadding,
        maxLng + lngPadding,
      ),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 90),
    );
  }

  /// Smooth camera follow during rider animation - uses bounds-based approach
  void _smoothCameraFollow() {
    // Use the same logic as smart camera adjust to always show full route
    _smartCameraAdjust();
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    if (_storeLocation != null && _storeIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('store'),
          position: _storeLocation!,
          icon: _storeIcon!,
          anchor: const Offset(0.5, 0.977),
          infoWindow: InfoWindow(
            title: StoreConfig.storeName,
            snippet: 'Pickup store',
          ),
        ),
      );
    }

    if (_deliveryLocation != null && _deliveryIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('delivery'),
          position: _deliveryLocation!,
          icon: _deliveryIcon!,
          anchor: const Offset(0.5, 0.977),
          infoWindow: InfoWindow(
            title: 'Your address',
            snippet: widget.deliveryAddress ?? 'Delivery location',
          ),
        ),
      );
    }

    if (_animatedRiderPosition != null && _riderIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('rider'),
          position: _animatedRiderPosition!,
          icon: _riderIcon!,
          anchor: const Offset(0.5, 0.5),
          rotation: _riderBearing,
          flat: true,
          zIndexInt: 3,
          infoWindow: InfoWindow(
            title: widget.riderName ?? 'Delivery Partner',
            snippet: 'Live location',
          ),
        ),
      );
    }

    return markers;
  }

  Set<Polyline> _buildPolylines() {
    final lines = <Polyline>{};

    // Show primary route (store to delivery) when no rider or as background
    if (_primaryRoutePoints.length >= 2 && _riderRoutePoints.isEmpty) {
      lines.add(
        Polyline(
          polylineId: const PolylineId('store_route'),
          points: _primaryRoutePoints,
          color: AppColors.primary,
          width: 5,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );
    }

    // Show rider route (rider to delivery) when rider is active
    if (_riderRoutePoints.length >= 2) {
      lines.add(
        Polyline(
          polylineId: const PolylineId('rider_route'),
          points: _riderRoutePoints,
          color: AppColors.success,
          width: 6,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );
    }

    return lines;
  }

  String _statusHeadline() {
    final status = widget.orderStatus.toLowerCase();
    switch (status) {
      case 'out_for_delivery':
      case 'on_way':
        return 'On the way to you';
      case 'assigned':
      case 'accepted':
        return widget.riderName != null
            ? '${widget.riderName} is assigned'
            : 'Rider assigned';
      case 'picked_up':
        return 'Order picked up';
      case 'preparing':
      case 'packed':
        return 'Preparing your order';
      case 'confirmed':
        return 'Order confirmed';
      default:
        return 'Tracking your order';
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiKey = EnvConfig.googleMapsApiKey;
    final mapHeight = widget.expandToFill ? null : (widget.fixedHeight ?? 220.0);

    if (apiKey.isEmpty) {
      return _placeholder(
        height: mapHeight,
        icon: Icons.map_outlined,
        message: 'Map unavailable — API key required',
      );
    }

    if (!_iconsReady) {
      return _placeholder(
        height: mapHeight,
        child: const CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final initialTarget = _deliveryLocation ?? _storeLocation ?? _fallback;

    final map = GoogleMap(
      initialCameraPosition: CameraPosition(target: initialTarget, zoom: 14),
      onMapCreated: (controller) {
        _mapController = controller;
        _fitCamera();
      },
      markers: _buildMarkers(),
      polylines: _buildPolylines(),
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
    );

    final content = Stack(
      fit: widget.expandToFill ? StackFit.expand : StackFit.loose,
      children: [
        Positioned.fill(child: map),
        if (!widget.hideTopBanner) ...[
          Positioned(
            top: 8,
            left: 12,
            right: 12,
            child: _EtaDistanceBanner(
              eta: _etaText,
              distance: _distanceText,
              loading: _loadingRoute && _etaText == null,
              label: _animatedRiderPosition != null
                  ? 'Partner to you'
                  : 'Store to you',
            ),
          ),
        ],
        if (_animatedRiderPosition != null && !widget.hideTopBanner)
          Positioned(
            top: 72,
            right: 12,
            child: _LiveBadge(pulse: _pulseController!),
          ),
        if (!widget.hideTopBanner)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _MapInfoCard(
              headline: _statusHeadline(),
              hasRider: _animatedRiderPosition != null,
            ),
          ),
      ],
    );

    if (widget.expandToFill) return content;
    return SizedBox(height: mapHeight, child: content);
  }

  Widget _placeholder({
    double? height,
    IconData? icon,
    String? message,
    Widget? child,
  }) {
    return Container(
      height: height ?? 220,
      decoration: BoxDecoration(
        color: AppColors.greyLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: child ??
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 40, color: AppColors.textMuted),
                if (message != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
      ),
    );
  }

  @override
  void dispose() {
    _moveController?.dispose();
    _pulseController?.dispose();
    _autoCameraTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}

class _EtaDistanceBanner extends StatelessWidget {
  final String? eta;
  final String? distance;
  final bool loading;
  final String label;

  const _EtaDistanceBanner({
    required this.eta,
    required this.distance,
    required this.loading,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: loading
          ? const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text(
                  'Calculating route...',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            )
          : Row(
              children: [
                _stat(
                  icon: Icons.schedule_rounded,
                  value: eta ?? '--',
                  caption: 'Arrival',
                  color: AppColors.success,
                ),
                Container(
                  width: 1,
                  height: 36,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  color: AppColors.divider,
                ),
                _stat(
                  icon: Icons.route_rounded,
                  value: distance ?? '--',
                  caption: label,
                  color: AppColors.info,
                ),
              ],
            ),
    );
  }

  Widget _stat({
    required IconData icon,
    required String value,
    required String caption,
    required Color color,
  }) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  caption,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  final AnimationController pulse;

  const _LiveBadge({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.85 + pulse.value * 0.15),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.success.withValues(alpha: 0.3),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 8, color: Colors.white),
              SizedBox(width: 6),
              Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MapInfoCard extends StatelessWidget {
  final String headline;
  final bool hasRider;

  const _MapInfoCard({
    required this.headline,
    required this.hasRider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            hasRider ? Icons.delivery_dining : Icons.storefront,
            color: hasRider ? AppColors.success : AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              headline,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
