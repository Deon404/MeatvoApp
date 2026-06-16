import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/order_model.dart';
import '../../services/navigation_service.dart';
import '../../services/maps_service.dart';

/// Navigation map widget for riders showing route to customer
class RiderNavigationMap extends StatefulWidget {
  final OrderModel order;
  final bool showTraffic;
  final Function(String eta, String distance)? onRouteUpdate;

  const RiderNavigationMap({
    super.key,
    required this.order,
    this.showTraffic = false,
    this.onRouteUpdate,
  });

  @override
  State<RiderNavigationMap> createState() => _RiderNavigationMapState();
}

class _RiderNavigationMapState extends State<RiderNavigationMap> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  List<LatLng> _routePoints = [];
  String? _eta;
  String? _distance;
  Timer? _maxIntervalTimer;
  StreamSubscription<Position>? _positionStream;
  bool _isCalculatingRoute = false;
  bool _isTrafficEnabled = false;

  final NavigationService _navigationService = NavigationService();
  final MapsService _mapsService = MapsService();

  @override
  void initState() {
    super.initState();
    _isTrafficEnabled = widget.showTraffic;
    _initLocationTracking();
  }

  @override
  void dispose() {
    _maxIntervalTimer?.cancel();
    _positionStream?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initLocationTracking() async {
    try {
      // Get initial position
      final hasPermission = await _mapsService.hasLocationPermission();
      if (!hasPermission) {
        final permission = await _mapsService.requestLocationPermission();
        if (permission != LocationPermission.whileInUse &&
            permission != LocationPermission.always) {
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() => _currentPosition = position);
        await _updateRoute();
      }

      // Subscribe to position stream with 50m distance filter
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 50, // Update on 50m movement
        ),
      ).listen((Position position) {
        if (!mounted) return;
        setState(() => _currentPosition = position);
        _updateRoute();
      });

      // Backup: 30s max interval timer
      _maxIntervalTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _updateRoute(),
      );
    } catch (e) {
      debugPrint('Error initializing location tracking: $e');
    }
  }

  Future<void> _updateRoute() async {
    if (_isCalculatingRoute) return;
    if (_currentPosition == null) return;
    if (widget.order.deliveryLatitude == null ||
        widget.order.deliveryLongitude == null) return;

    setState(() => _isCalculatingRoute = true);

    try {
      final origin = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
      final destination = LatLng(
        widget.order.deliveryLatitude!,
        widget.order.deliveryLongitude!,
      );

      final route = await _navigationService.calculateRoute(
        origin: origin,
        destination: destination,
      );

      if (route != null && mounted) {
        setState(() {
          _routePoints = route.polylinePoints;
          _eta = route.duration;
          _distance = route.distance;
          _isCalculatingRoute = false;
        });

        // Notify parent
        widget.onRouteUpdate?.call(route.duration, route.distance);

        // Animate camera to show both points
        _animateCameraToFitRoute();
      } else {
        if (mounted) {
          setState(() => _isCalculatingRoute = false);
        }
      }
    } catch (e) {
      debugPrint('Error updating route: $e');
      if (mounted) {
        setState(() => _isCalculatingRoute = false);
      }
    }
  }

  void _animateCameraToFitRoute() {
    if (_mapController == null || _routePoints.isEmpty) return;

    final bounds = _calculateBounds(_routePoints);
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80),
    );
  }

  LatLngBounds _calculateBounds(List<LatLng> points) {
    double south = points.first.latitude;
    double north = points.first.latitude;
    double west = points.first.longitude;
    double east = points.first.longitude;

    for (final point in points) {
      if (point.latitude < south) south = point.latitude;
      if (point.latitude > north) north = point.latitude;
      if (point.longitude < west) west = point.longitude;
      if (point.longitude > east) east = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );
  }

  Future<void> _launchGoogleMaps() async {
    if (widget.order.deliveryLatitude == null ||
        widget.order.deliveryLongitude == null) {
      return;
    }

    final destination = LatLng(
      widget.order.deliveryLatitude!,
      widget.order.deliveryLongitude!,
    );

    final origin = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : null;

    final success = await _navigationService.launchGoogleMapsNavigation(
      destination: destination,
      origin: origin,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open Google Maps'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (widget.order.deliveryLatitude == null ||
        widget.order.deliveryLongitude == null) {
      return _buildNoLocationState();
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(
              widget.order.deliveryLatitude!,
              widget.order.deliveryLongitude!,
            ),
            zoom: 14,
          ),
          onMapCreated: (controller) {
            _mapController = controller;
            if (_routePoints.isNotEmpty) {
              _animateCameraToFitRoute();
            }
          },
          markers: _buildMarkers(),
          polylines: _buildPolylines(colorScheme),
          trafficEnabled: _isTrafficEnabled,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),
        _buildTopControls(colorScheme),
        _buildNavigationInfo(colorScheme),
      ],
    );
  }

  Widget _buildNoLocationState() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Customer location not available',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopControls(ColorScheme colorScheme) {
    return Positioned(
      top: 16,
      right: 16,
      child: Column(
        children: [
          FloatingActionButton.small(
            heroTag: 'traffic',
            onPressed: () {
              setState(() => _isTrafficEnabled = !_isTrafficEnabled);
            },
            backgroundColor: _isTrafficEnabled
                ? colorScheme.primary
                : colorScheme.surface,
            foregroundColor: _isTrafficEnabled
                ? colorScheme.onPrimary
                : colorScheme.onSurface,
            child: const Icon(Icons.traffic),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'center',
            onPressed: _animateCameraToFitRoute,
            backgroundColor: colorScheme.surface,
            foregroundColor: colorScheme.onSurface,
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationInfo(ColorScheme colorScheme) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (_isCalculatingRoute)
                const LinearProgressIndicator()
              else
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _eta ?? 'Calculating...',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _distance ?? 'Getting route...',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurface.withOpacity(0.7),
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    FilledButton.icon(
                      onPressed: _launchGoogleMaps,
                      icon: const Icon(Icons.navigation),
                      label: const Text('Navigate'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    // Customer location marker
    if (widget.order.deliveryLatitude != null &&
        widget.order.deliveryLongitude != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('customer'),
          position: LatLng(
            widget.order.deliveryLatitude!,
            widget.order.deliveryLongitude!,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Delivery Location',
            snippet: widget.order.deliveryAddress,
          ),
        ),
      );
    }

    return markers;
  }

  Set<Polyline> _buildPolylines(ColorScheme colorScheme) {
    if (_routePoints.isEmpty) return {};

    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: _routePoints,
        color: colorScheme.primary,
        width: 5,
        geodesic: true,
        patterns: [
          PatternItem.dash(30),
          PatternItem.gap(10),
        ],
      ),
    };
  }
}
