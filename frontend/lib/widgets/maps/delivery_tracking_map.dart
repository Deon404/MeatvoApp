import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../config/env_config.dart';
import '../../config/google_maps_setup.dart';
import '../../config/store_config.dart';
import '../../core/constants/app_constants.dart';
import '../../services/maps_platform_config.dart';
import '../../services/maps_service.dart';
import '../../utils/order_eta_util.dart';
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
  bool _isMapReady = false;
  String? _mapError;
  Timer? _autoCameraTimer;
  Timer? _mapTimeoutTimer;

  static final LatLng _fallback = LatLng(
    StoreConfig.storeLatitude,
    StoreConfig.storeLongitude,
  );

  bool get _isTerminalStatus {
    final s = widget.orderStatus.toLowerCase();
    return s == 'delivered' || s == 'cancelled';
  }

  LatLng? get _effectiveRiderPosition {
    if (widget.riderLatitude != null && widget.riderLongitude != null) {
      return LatLng(widget.riderLatitude!, widget.riderLongitude!);
    }
    return _animatedRiderPosition;
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (!_isTerminalStatus) {
      _pulseController!.repeat(reverse: true);
      _autoCameraTimer = Timer.periodic(
        const Duration(seconds: 8),
        (_) => _smartCameraAdjust(),
      );
    }

    _initMap();
  }

  @override
  void didUpdateWidget(covariant DeliveryTrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderStatus != widget.orderStatus && _isTerminalStatus) {
      _autoCameraTimer?.cancel();
      _autoCameraTimer = null;
      _moveController?.dispose();
      _moveController = null;
      setState(() => _animatedRiderPosition = null);
    }

    final riderMoved = !_isTerminalStatus &&
        (widget.riderLatitude != oldWidget.riderLatitude ||
            widget.riderLongitude != oldWidget.riderLongitude);
    final riderAppeared = !_isTerminalStatus &&
        oldWidget.riderLatitude == null &&
        widget.riderLatitude != null;
    final deliveryMoved = widget.deliveryLatitude != oldWidget.deliveryLatitude ||
        widget.deliveryLongitude != oldWidget.deliveryLongitude;
    final statusChanged = widget.orderStatus != oldWidget.orderStatus;

    if (riderMoved || riderAppeared) _handleRiderUpdate();
    if (deliveryMoved || riderMoved || riderAppeared || statusChanged) {
      if (deliveryMoved) _setDeliveryLocation();
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

  DrivingRouteResult _routeInfoAsResult({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) {
    final info = _mapsService.calculateRouteInfo(
      startLatitude: originLat,
      startLongitude: originLng,
      endLatitude: destLat,
      endLongitude: destLng,
    );
    return DrivingRouteResult(
      points: const [],
      distanceKm: info['distance'] as double,
      durationMinutes: info['eta'] as int,
      distanceFormatted: info['distanceFormatted'] as String,
      durationFormatted: info['etaFormatted'] as String,
    );
  }

  /// Store → customer metrics for header ETA before pickup.
  Future<DrivingRouteResult?> _resolveStoreToCustomerMetrics(
    LatLng delivery,
  ) async {
    final store = _storeLocation;
    if (store == null) return null;

    final apiRoute = await _mapsService.getDrivingRoute(
      originLat: store.latitude,
      originLng: store.longitude,
      destLat: delivery.latitude,
      destLng: delivery.longitude,
    );
    return apiRoute ??
        _routeInfoAsResult(
          originLat: store.latitude,
          originLng: store.longitude,
          destLat: delivery.latitude,
          destLng: delivery.longitude,
        );
  }

  Future<void> _fetchRoutes() async {
    final delivery = _deliveryLocation;
    if (delivery == null) return;

    setState(() => _loadingRoute = true);

    final storeMetrics = await _resolveStoreToCustomerMetrics(delivery);
    final storeRoute = storeMetrics != null && storeMetrics.points.isNotEmpty
        ? storeMetrics
        : null;

    DrivingRouteResult? riderRoute;
    List<LatLng> riderPts = [];
    final riderPos = _effectiveRiderPosition;

    if (riderPos != null) {
      riderRoute = await _mapsService.getDrivingRoute(
        originLat: riderPos.latitude,
        originLng: riderPos.longitude,
        destLat: delivery.latitude,
        destLng: delivery.longitude,
      );
      if (riderRoute == null) {
        riderRoute = _routeInfoAsResult(
          originLat: riderPos.latitude,
          originLng: riderPos.longitude,
          destLat: delivery.latitude,
          destLng: delivery.longitude,
        );
      } else {
        riderPts = riderRoute.points
            .map((p) => LatLng(p.lat, p.lng))
            .toList();
      }
    }

    // Header ETA/distance: rider → customer (fallback: store → customer).
    final routeForEta = riderRoute ?? storeMetrics;

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
      } else if (_storeLocation != null) {
        _primaryRoutePoints = [_storeLocation!, delivery];
      } else {
        _primaryRoutePoints = [];
      }

      // Build rider route with exact start/end points
      if (riderPts.isNotEmpty) {
        _riderRoutePoints = [
          if (riderPos != null) riderPos,
          ...riderPts,
          delivery,
        ];
        _riderRoutePoints = _removeDuplicatePoints(_riderRoutePoints);
      } else if (riderPos != null) {
        // Fallback: draw straight line from rider to delivery
        _riderRoutePoints = [riderPos, delivery];
      } else {
        _riderRoutePoints = [];
      }

      if (routeForEta != null) {
        _distanceText = routeForEta.distanceFormatted;
        _etaMinutes = composeCustomerEtaMinutes(
          status: widget.orderStatus,
          travelMinutes: routeForEta.durationMinutes,
          distanceKm: routeForEta.distanceKm,
        );
        _etaText = formatEtaMinutesLabel(_etaMinutes!);
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
    if (_isTerminalStatus) return;
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
    if (_mapController == null || !mounted || _isTerminalStatus) return;

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
          anchor: const Offset(0.5, 0.97),
          zIndexInt: 1,
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
          anchor: const Offset(0.5, 0.97),
          zIndexInt: 2,
          infoWindow: InfoWindow(
            title: 'Your address',
            snippet: widget.deliveryAddress ?? 'Delivery location',
          ),
        ),
      );
    }

    if (_animatedRiderPosition != null && _riderIcon != null && !_isTerminalStatus) {
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
    const cap = Cap.roundCap;
    const joint = JointType.round;

    // Faint store → customer path (background when rider is active)
    if (_primaryRoutePoints.length >= 2 && _riderRoutePoints.isNotEmpty) {
      lines.addAll(_layeredRoute(
        id: 'store_route_bg',
        points: _primaryRoutePoints,
        borderColor: AppColors.primary.withValues(alpha: 0.18),
        glowColor: AppColors.primary.withValues(alpha: 0.08),
        glowWidth: 7,
        lineColor: AppColors.primary.withValues(alpha: 0.34),
        lineWidth: 3,
        dashed: true,
        cap: cap,
        joint: joint,
      ));
    }

    // Store → customer (before rider is assigned)
    if (_primaryRoutePoints.length >= 2 && _riderRoutePoints.isEmpty) {
      lines.addAll(_layeredRoute(
        id: 'store_route',
        points: _primaryRoutePoints,
        borderColor: const Color(0xFF7F0A1E).withValues(alpha: 0.45),
        glowColor: AppColors.primary.withValues(alpha: 0.16),
        glowWidth: 9,
        lineColor: AppColors.primary.withValues(alpha: 0.92),
        lineWidth: 5,
        highlightColor: Colors.white.withValues(alpha: 0.28),
        dashed: true,
        cap: cap,
        joint: joint,
      ));
    }

    // Active rider → customer route
    if (_riderRoutePoints.length >= 2) {
      lines.addAll(_layeredRoute(
        id: 'rider_route',
        points: _riderRoutePoints,
        borderColor: const Color(0xFF065F46).withValues(alpha: 0.72),
        glowColor: AppColors.success.withValues(alpha: 0.22),
        glowWidth: 11,
        lineColor: const Color(0xFF10B981),
        lineWidth: 5,
        highlightColor: Colors.white.withValues(alpha: 0.38),
        cap: cap,
        joint: joint,
      ));
    }

    return lines;
  }

  /// Multi-layer route: border + glow + main stroke (+ optional center highlight).
  List<Polyline> _layeredRoute({
    required String id,
    required List<LatLng> points,
    Color? borderColor,
    required Color glowColor,
    required double glowWidth,
    required Color lineColor,
    required double lineWidth,
    Color? highlightColor,
    bool dashed = false,
    required Cap cap,
    required JointType joint,
  }) {
    final patterns = dashed
        ? <PatternItem>[PatternItem.dash(18), PatternItem.gap(12)]
        : const <PatternItem>[];

    final layers = <Polyline>[];

    if (borderColor != null) {
      layers.add(
        Polyline(
          polylineId: PolylineId('${id}_border'),
          points: points,
          color: borderColor,
          width: (lineWidth + 4).round(),
          startCap: cap,
          endCap: cap,
          jointType: joint,
          patterns: patterns,
          geodesic: true,
          zIndex: 0,
        ),
      );
    }

    layers.addAll([
      Polyline(
        polylineId: PolylineId('${id}_glow'),
        points: points,
        color: glowColor,
        width: glowWidth.round(),
        startCap: cap,
        endCap: cap,
        jointType: joint,
        geodesic: true,
        zIndex: 1,
      ),
      Polyline(
        polylineId: PolylineId(id),
        points: points,
        color: lineColor,
        width: lineWidth.round(),
        startCap: cap,
        endCap: cap,
        jointType: joint,
        patterns: patterns,
        geodesic: true,
        zIndex: 2,
      ),
    ]);

    if (highlightColor != null) {
      layers.add(
        Polyline(
          polylineId: PolylineId('${id}_highlight'),
          points: points,
          color: highlightColor,
          width: 2,
          startCap: cap,
          endCap: cap,
          jointType: joint,
          geodesic: true,
          zIndex: 3,
        ),
      );
    }

    return layers;
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
      onMapCreated: _onMapCreated,
      onCameraIdle: () {
        if (!mounted || _isMapReady) return;
        _mapTimeoutTimer?.cancel();
        setState(() => _isMapReady = true);
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
        if (_mapError != null)
          Positioned.fill(
            child: Container(
              color: Colors.white.withValues(alpha: 0.92),
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.map_outlined,
                      size: 40,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _mapError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
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

  Future<void> _onMapCreated(GoogleMapController controller) async {
    if (!mounted) {
      try {
        controller.dispose();
      } catch (_) {}
      return;
    }

    _mapController = controller;
    _mapTimeoutTimer?.cancel();
    _isMapReady = false;
    _mapError = null;

    if (!EnvConfig.hasGoogleMapsApiKey) {
      if (mounted) {
        setState(() {
          _mapError =
              'Map unavailable — API key missing.\n\n${GoogleMapsSetup.setupChecklist}';
        });
      }
      return;
    }

    final native = await MapsPlatformConfig.getNativeConfig();
    if (native != null && !native.isReady) {
      if (mounted) {
        setState(() {
          _mapError = GoogleMapsSetup.manifestKeyMissingError();
        });
      }
      return;
    }

    _fitCamera();

    _mapTimeoutTimer = Timer(const Duration(seconds: 15), () async {
      if (!mounted || _isMapReady || _mapError != null) return;
      final nativeCfg = await MapsPlatformConfig.getNativeConfig();
      setState(() {
        _mapError = GoogleMapsSetup.tilesLoadError(
          applicationId: nativeCfg?.applicationId,
        );
      });
    });
  }

  @override
  void dispose() {
    _mapTimeoutTimer?.cancel();
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
