import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/rider_service.dart';
import '../../services/maps_service.dart';
import '../../services/navigation_service.dart';
import '../../services/api_service.dart';
import '../../services/contact_action_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/map_markers.dart';
import '../../config/store_config.dart';
import '../../widgets/skeletons/shimmer_base.dart';

/// Delivery Map Screen for Riders
/// Shows all delivery stops with optimized route and navigation
class DeliveryMapScreen extends StatefulWidget {
  const DeliveryMapScreen({super.key});

  @override
  State<DeliveryMapScreen> createState() => _DeliveryMapScreenState();
}

class _DeliveryMapScreenState extends State<DeliveryMapScreen> {
  final RiderService _riderService = RiderService();
  final MapsService _mapsService = MapsService();
  final NavigationService _navigationService = NavigationService();
  final ApiService _api = ApiService();
  final ContactActionService _contactService = ContactActionService();

  GoogleMapController? _mapController;
  Map<String, dynamic>? _routeData;
  bool _isLoading = true;
  String? _error;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng? _currentLocation;
  List<Map<String, dynamic>> _stops = [];

  @override
  void initState() {
    super.initState();
    _loadRouteData();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadRouteData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Use optimized route endpoint from backend
      final response = await _api.get('/delivery/my-route');
      
      final data = response.data;
      if (data is! Map) {
        throw Exception('Invalid response format');
      }
      
      final routeData = data['data'] as Map<String, dynamic>?;
      if (routeData == null) {
        throw Exception('No route data received');
      }

      final routeStops = routeData['route'] as List<dynamic>?;
      if (routeStops == null || routeStops.isEmpty) {
        setState(() {
          _error = 'No active deliveries';
          _isLoading = false;
        });
        return;
      }

      // Map optimized route stops to UI format
      final stops = <Map<String, dynamic>>[];
      for (final stopData in routeStops) {
        final stop = stopData as Map<String, dynamic>;
        final lat = (stop['lat'] as num?)?.toDouble();
        final lng = (stop['lng'] as num?)?.toDouble();

        // Skip stops without valid coordinates
        if (lat == null || lng == null) {
          debugPrint('Skipping stop ${stop['orderId']} - missing coordinates');
          continue;
        }

        stops.add({
          'stopNumber': stop['stopNumber'] as int? ?? stops.length + 1,
          'orderId': stop['orderId']?.toString() ?? '',
          'customerName': stop['customerName']?.toString() ?? 'Customer',
          'customerPhone': stop['customerPhone']?.toString() ?? '',
          'address': stop['address']?.toString() ?? 'Address',
          'latitude': lat,
          'longitude': lng,
          'distanceFromPrev': stop['distanceFromPrevKm'] as num? ?? 0,
          'delivered': (stop['status']?.toString().toLowerCase() ?? '') == 'delivered',
        });
      }

      if (stops.isEmpty) {
        setState(() {
          _error = 'No stops with valid coordinates';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _stops = stops;
        _routeData = {
          'stops': stops,
          'totalStops': stops.length,
          'totalDistanceKm': routeData['totalDistanceKm'] as num? ?? 0,
          'estimatedMinutes': routeData['estimatedMinutes'] as int? ?? 0,
        };
        _isLoading = false;
      });

      await _buildMapElements();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _startLocationTracking() async {
    try {
      final position = await _mapsService.getCurrentLocation(
        forceRequest: false,
      );
      if (position != null) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
        await _buildMapElements();
      }
    } catch (e) {
      debugPrint('Location tracking error: $e');
    }
  }

  Future<void> _buildMapElements() async {
    if (_stops.isEmpty) return;

    final markers = <Marker>{};
    final storeLocation = LatLng(
      StoreConfig.storeLatitude,
      StoreConfig.storeLongitude,
    );

    // 1. Store marker
    final storeMarker = await _createStoreMarker(storeLocation);
    markers.add(storeMarker);

    // 2. Customer stop markers
    for (final stop in _stops) {
      final stopMarker = await _createStopMarker(stop);
      markers.add(stopMarker);
    }

    // 3. Rider current location marker
    if (_currentLocation != null) {
      final riderMarker = await _createRiderMarker(_currentLocation!);
      markers.add(riderMarker);
    }

    // 4. Build route polyline
    final polylines = await _buildRoutePolyline(storeLocation);

    setState(() {
      _markers = markers;
      _polylines = polylines;
    });

    // Fit camera to show all markers
    if (_mapController != null) {
      _fitCameraToBounds();
    }
  }

  Future<Marker> _createStoreMarker(LatLng position) async {
    final icon = await MapMarkers.storeMarker();

    return Marker(
      markerId: const MarkerId('store'),
      position: position,
      icon: icon,
      anchor: const Offset(0.5, 0.5),
      infoWindow: const InfoWindow(title: 'Store'),
    );
  }

  Future<Marker> _createStopMarker(Map<String, dynamic> stop) async {
    final stopNumber = stop['stopNumber'] as int;
    final lat = stop['latitude'] as double;
    final lng = stop['longitude'] as double;
    final delivered = stop['delivered'] as bool;
    final status = stop['status']?.toString().toLowerCase() ?? 'assigned';

    // Determine dot color by status
    Color dotColor;
    if (delivered || status == 'delivered') {
      dotColor = const Color(0xFF9E9E9E); // grey
    } else if (status == 'picked_up' || status == 'on_the_way') {
      dotColor = const Color(0xFF2196F3); // blue
    } else {
      dotColor = const Color(0xFFFF9800); // orange (pending/assigned)
    }

    final icon = await MapMarkers.densityDot(
      color: dotColor,
      orderCount: 1, // Single dot, no count
    );

    return Marker(
      markerId: MarkerId('stop_$stopNumber'),
      position: LatLng(lat, lng),
      icon: icon,
      anchor: const Offset(0.5, 0.5),
      onTap: () => _showStopDetails(stop),
    );
  }

  Future<Marker> _createRiderMarker(LatLng position) async {
    final icon = await MapMarkers.riderMarker();

    return Marker(
      markerId: const MarkerId('rider'),
      position: position,
      icon: icon,
      anchor: const Offset(0.5, 0.5),
      infoWindow: const InfoWindow(title: 'Your Location'),
    );
  }

  Future<Set<Polyline>> _buildRoutePolyline(LatLng storeLocation) async {
    if (_stops.isEmpty) return {};

    final allPolylinePoints = <LatLng>[];
    LatLng previousLocation = storeLocation;

    // Get driving route for each segment
    for (final stop in _stops) {
      final stopLocation = LatLng(
        stop['latitude'] as double,
        stop['longitude'] as double,
      );

      // Try to get actual road polyline from Google Directions API
      final drivingRoute = await _mapsService.getDrivingRoute(
        originLat: previousLocation.latitude,
        originLng: previousLocation.longitude,
        destLat: stopLocation.latitude,
        destLng: stopLocation.longitude,
      );

      if (drivingRoute != null && drivingRoute.points.isNotEmpty) {
        // Use real road polyline from Directions API
        allPolylinePoints.addAll(
          drivingRoute.points.map((p) => LatLng(p.lat, p.lng)),
        );
      } else {
        // Fallback to straight line if API fails
        allPolylinePoints.add(previousLocation);
        allPolylinePoints.add(stopLocation);
      }

      previousLocation = stopLocation;
    }

    // Add route back to store
    final backToStoreRoute = await _mapsService.getDrivingRoute(
      originLat: previousLocation.latitude,
      originLng: previousLocation.longitude,
      destLat: storeLocation.latitude,
      destLng: storeLocation.longitude,
    );

    if (backToStoreRoute != null && backToStoreRoute.points.isNotEmpty) {
      allPolylinePoints.addAll(
        backToStoreRoute.points.map((p) => LatLng(p.lat, p.lng)),
      );
    } else {
      // Fallback straight line back to store
      allPolylinePoints.add(previousLocation);
      allPolylinePoints.add(storeLocation);
    }

    return {
      Polyline(
        polylineId: const PolylineId('delivery_route'),
        points: allPolylinePoints,
        color: const Color(0xFFC8102E),
        width: 4,
        patterns: const [],
      ),
    };
  }

  void _fitCameraToBounds() {
    if (_markers.isEmpty) return;

    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (final marker in _markers) {
      final lat = marker.position.latitude;
      final lng = marker.position.longitude;
      
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 60),
    );
  }

  void _showStopDetails(Map<String, dynamic> stop) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stop ${stop['stopNumber']}',
              style: AppTextStyles.h3.copyWith(
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.person, size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stop['customerName'] as String,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if ((stop['customerPhone'] as String).isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.phone, size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      stop['customerPhone'] as String,
                      style: AppTextStyles.body,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stop['address'] as String,
                    style: AppTextStyles.body,
                  ),
                ),
              ],
            ),
            if (_currentLocation != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.straighten, size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    '${_mapsService.calculateDistance(
                      startLatitude: _currentLocation!.latitude,
                      startLongitude: _currentLocation!.longitude,
                      endLatitude: stop['latitude'] as double,
                      endLongitude: stop['longitude'] as double,
                    ).toStringAsFixed(1)} km from you',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                if ((stop['customerPhone'] as String).isNotEmpty) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _callCustomer(stop['customerPhone'] as String),
                      icon: const Icon(Icons.call, size: 20),
                      label: const Text('Call'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _smsCustomer(stop['customerPhone'] as String),
                      icon: const Icon(Icons.message_outlined, size: 20),
                      label: const Text('SMS'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _navigateToStop(stop),
                    icon: const Icon(Icons.navigation, size: 20),
                    label: const Text('Navigate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _callCustomer(String phone) async {
    final success = await _contactService.makeCall(phone);
    if (!success && mounted) {
      _contactService.showContactError(context, 'call', phone);
    }
  }

  Future<void> _smsCustomer(String phone) async {
    final success = await _contactService.sendSMS(phone);
    if (!success && mounted) {
      _contactService.showContactError(context, 'message', phone);
    }
  }

  Future<void> _navigateToStop(Map<String, dynamic> stop) async {
    final destination = LatLng(
      stop['latitude'] as double,
      stop['longitude'] as double,
    );

    await _navigationService.launchGoogleMapsNavigation(
      destination: destination,
      origin: _currentLocation,
      mode: TravelMode.driving,
    );
  }

  Future<void> _startFullRoute() async {
    if (_stops.isEmpty) return;

    try {
      // Build waypoints string for Google Maps
      final waypoints = _stops.map((stop) {
        return '${stop['latitude']},${stop['longitude']}';
      }).join('|');

      final storeLocation = LatLng(
        StoreConfig.storeLatitude,
        StoreConfig.storeLongitude,
      );

      // Launch Google Maps with all waypoints
      final url = 'https://www.google.com/maps/dir/?api=1'
          '&origin=${storeLocation.latitude},${storeLocation.longitude}'
          '&destination=${storeLocation.latitude},${storeLocation.longitude}'
          '&waypoints=$waypoints'
          '&travelmode=d';

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open Google Maps'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching Google Maps: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open navigation'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Today\'s Route'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          if (_routeData != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_stops.length} Stops',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _error != null
              ? _buildErrorState()
              : _buildMapView(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading route...',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Error loading route',
              style: AppTextStyles.h3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadRouteData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapView() {
    // Use backend-provided metrics if available, otherwise calculate
    final totalDistance = (_routeData?['totalDistanceKm'] as num?)?.toDouble() ?? 
                         _calculateTotalDistance();
    final totalDuration = (_routeData?['estimatedMinutes'] as int?) ?? 
                         _calculateTotalDuration();

    return RefreshIndicator(
      onRefresh: _loadRouteData,
      color: AppColors.primary,
      child: Column(
        children: [
          // Map (70% of screen)
          Expanded(
            flex: 7,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      StoreConfig.storeLatitude,
                      StoreConfig.storeLongitude,
                    ),
                    zoom: 13,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: true,
                  mapToolbarEnabled: false,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _fitCameraToBounds();
                  },
                ),
                if (_stops.isNotEmpty)
                  _buildSummaryBar(),
              ],
            ),
          ),
          // Bottom sheet (30% of screen)
          Expanded(
            flex: 3,
            child: DraggableScrollableSheet(
              initialChildSize: 1.0,
              minChildSize: 0.3,
              maxChildSize: 1.0,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Handle bar
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_stops.length} stops · ${totalDistance.toStringAsFixed(1)} km · ~${totalDuration} min',
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: _startFullRoute,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                              child: const Text('Start Route'),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Stop list
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _loadRouteData,
                          color: AppColors.primary,
                          child: ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _stops.length,
                            separatorBuilder: (context, index) => const Divider(),
                            itemBuilder: (context, index) {
                              final stop = _stops[index];
                              return _buildStopCard(stop);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStopCard(Map<String, dynamic> stop) {
    final stopNumber = stop['stopNumber'] as int;
    final customerName = stop['customerName'] as String;
    final address = stop['address'] as String;
    final delivered = stop['delivered'] as bool;

    // Calculate distance from store or previous stop
    final stopLocation = LatLng(
      stop['latitude'] as double,
      stop['longitude'] as double,
    );
    final previousLocation = stopNumber == 1
        ? LatLng(StoreConfig.storeLatitude, StoreConfig.storeLongitude)
        : LatLng(
            _stops[stopNumber - 2]['latitude'] as double,
            _stops[stopNumber - 2]['longitude'] as double,
          );

    final distance = _mapsService.calculateDistance(
      startLatitude: previousLocation.latitude,
      startLongitude: previousLocation.longitude,
      endLatitude: stopLocation.latitude,
      endLongitude: stopLocation.longitude,
    );

    return InkWell(
      onTap: () => _showStopDetails(stop),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            // Number circle or checkmark
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: delivered ? AppColors.success : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: delivered ? AppColors.success : AppColors.primary,
                  width: 2,
                ),
              ),
              child: Center(
                child: delivered
                    ? const Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                      )
                    : Text(
                        stopNumber.toString(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          fontFamily: 'Poppins',
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Customer info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customerName,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    address,
                    style: AppTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Distance
            Text(
              '${distance.toStringAsFixed(1)} km',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBar() {
    final pending = _stops.where((s) => !(s['delivered'] as bool)).length;
    final delivered = _stops.where((s) => s['delivered'] as bool).length;

    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          '${_stops.length} stops · $pending pending · $delivered delivered',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  double _calculateTotalDistance() {
    if (_stops.isEmpty) return 0;

    double total = 0;
    LatLng previousLocation = LatLng(
      StoreConfig.storeLatitude,
      StoreConfig.storeLongitude,
    );

    for (final stop in _stops) {
      final stopLocation = LatLng(
        stop['latitude'] as double,
        stop['longitude'] as double,
      );
      
      total += _mapsService.calculateDistance(
        startLatitude: previousLocation.latitude,
        startLongitude: previousLocation.longitude,
        endLatitude: stopLocation.latitude,
        endLongitude: stopLocation.longitude,
      );
      
      previousLocation = stopLocation;
    }

    // Add distance back to store
    total += _mapsService.calculateDistance(
      startLatitude: previousLocation.latitude,
      startLongitude: previousLocation.longitude,
      endLatitude: StoreConfig.storeLatitude,
      endLongitude: StoreConfig.storeLongitude,
    );

    return total;
  }

  int _calculateTotalDuration() {
    final distance = _calculateTotalDistance();
    // Assume average speed of 30 km/h in city
    final hours = distance / 30;
    return (hours * 60).round();
  }
}
