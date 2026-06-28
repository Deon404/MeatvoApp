import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../config/store_config.dart';
import '../../core/widgets/map_markers.dart';
import '../../services/api_service.dart';
import '../../services/maps_service.dart';
import '../../services/navigation_service.dart';
import '../../services/rider_location_service.dart';
import '../../services/rider_service.dart';
import '../../services/contact_action_service.dart';
import '../../utils/address_display_util.dart';
import 'widgets/delivery_otp_dialog.dart';

class _BatchStop {
  final String orderId;
  final int stopNumber;
  final String customerName;
  final String customerPhone;
  final String address;
  final double lat;
  final double lng;
  final double distanceKm;

  const _BatchStop({
    required this.orderId,
    required this.stopNumber,
    required this.customerName,
    required this.customerPhone,
    required this.address,
    required this.lat,
    required this.lng,
    required this.distanceKm,
  });
}

/// Multi-stop batch delivery screen — Licious-style map + bottom sheet.
class BatchDeliveryScreen extends StatefulWidget {
  final List<String> orderIds;

  const BatchDeliveryScreen({
    super.key,
    required this.orderIds,
  });

  @override
  State<BatchDeliveryScreen> createState() =>
      _BatchDeliveryScreenState();
}

class _BatchDeliveryScreenState extends State<BatchDeliveryScreen> {
  static const Color _primary = Color(0xFFC8102E);
  static const Color _greyText = Color(0xFF6B6B6B);
  static const Color _darkText = Color(0xFF1A1A1A);

  final RiderService _riderService = RiderService();
  final MapsService _mapsService = MapsService();
  final NavigationService _navigationService = NavigationService();
  final ApiService _api = ApiService();
  final ContactActionService _contactService = ContactActionService();
  final RiderLocationService _locationService = RiderLocationService();

  GoogleMapController? _mapController;
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _errorMessage;

  int _currentStopIndex = 0;
  late List<bool> _delivered;

  List<_BatchStop> _stops = [];
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng? _currentLocation;

  @override
  void initState() {
    super.initState();
    _delivered = List<bool>.filled(widget.orderIds.length, false);
    _loadBatchStops();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _locationService.stopSendingLocation();
    super.dispose();
  }

  Future<void> _loadBatchStops() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final orderIdSet = widget.orderIds.map((id) => id.toString()).toSet();
      final stops = <_BatchStop>[];

      try {
        final response = await _api.get('/delivery/my-route');
        final data = response.data;
        if (data is Map) {
          final routeData = data['data'] as Map<String, dynamic>?;
          final routeStops = routeData?['route'] as List<dynamic>?;
          if (routeStops != null) {
            var stopNumber = 1;
            for (final raw in routeStops) {
              if (raw is! Map) continue;
              final stop = Map<String, dynamic>.from(raw);
              final orderId = stop['orderId']?.toString() ?? '';
              if (!orderIdSet.contains(orderId)) continue;

              final lat = (stop['lat'] as num?)?.toDouble();
              final lng = (stop['lng'] as num?)?.toDouble();
              if (lat == null || lng == null) continue;

              stops.add(_BatchStop(
                orderId: orderId,
                stopNumber: stopNumber++,
                customerName:
                    stop['customerName']?.toString() ?? 'Customer',
                customerPhone:
                    stop['customerPhone']?.toString() ?? '',
                address: formatAddressForDisplay(stop['address']),
                lat: lat,
                lng: lng,
                distanceKm:
                    (stop['distanceFromPrevKm'] as num?)?.toDouble() ?? 0,
              ));
            }
          }
        }
      } catch (e) {
        debugPrint('[BatchDelivery] my-route failed, falling back: $e');
      }

      final loadedIds = stops.map((s) => s.orderId).toSet();
      final missingIds =
          orderIdSet.where((id) => !loadedIds.contains(id)).toList();

      for (final orderId in missingIds) {
        final assignment =
            await _riderService.getOrderAssignment(orderId, forceRefresh: true);
        final order = assignment['order'] as Map<String, dynamic>? ?? {};
        final coords = resolveAddressCoords(order);
        if (coords.lat == null || coords.lng == null) continue;

        final user = order['user'] as Map<String, dynamic>?;
        stops.add(_BatchStop(
          orderId: orderId,
          stopNumber: stops.length + 1,
          customerName: (user?['name'] ??
                  order['customerName'] ??
                  order['customer_name'])
              ?.toString()
              .trim() ??
              'Customer',
          customerPhone: (user?['phone'] ?? order['customer_phone'] ?? '')
              .toString()
              .trim(),
          address: formatAddressForDisplay(
            order['delivery_address'] ?? order['address'],
          ),
          lat: coords.lat!,
          lng: coords.lng!,
          distanceKm: 0,
        ));
      }

      if (stops.isEmpty) {
        throw Exception('Could not load delivery stops');
      }

      // Preserve widget.orderIds order when my-route didn't return all stops.
      if (stops.length != widget.orderIds.length) {
        final byId = {for (final s in stops) s.orderId: s};
        final ordered = <_BatchStop>[];
        for (var i = 0; i < widget.orderIds.length; i++) {
          final stop = byId[widget.orderIds[i]];
          if (stop != null) {
            ordered.add(_BatchStop(
              orderId: stop.orderId,
              stopNumber: i + 1,
              customerName: stop.customerName,
              customerPhone: stop.customerPhone,
              address: stop.address,
              lat: stop.lat,
              lng: stop.lng,
              distanceKm: stop.distanceKm,
            ));
          }
        }
        if (ordered.isNotEmpty) {
          stops
            ..clear()
            ..addAll(ordered);
        }
      }

      if (mounted) {
        setState(() {
          _stops = stops;
          _delivered = List<bool>.filled(stops.length, false);
          _currentStopIndex = 0;
          _isLoading = false;
        });
        _syncLocationTracking();
        await _buildMapElements();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load batch: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _startLocationTracking() async {
    try {
      final position = await _mapsService.getCurrentLocation(
        forceRequest: false,
      );
      if (position != null && mounted) {
        setState(() {
          _currentLocation =
              LatLng(position.latitude, position.longitude);
        });
        await _buildMapElements();
      }
    } catch (e) {
      debugPrint('[BatchDelivery] Location error: $e');
    }
  }

  void _syncLocationTracking() {
    if (_stops.isEmpty || _currentStopIndex >= _stops.length) return;
    if (_delivered.every((d) => d)) {
      _locationService.stopSendingLocation();
      return;
    }
    _locationService.startSendingLocation(_stops[_currentStopIndex].orderId);
  }

  Future<void> _buildMapElements() async {
    if (_stops.isEmpty) return;

    final storeLocation = LatLng(
      StoreConfig.storeLatitude,
      StoreConfig.storeLongitude,
    );

    final markers = <Marker>{};
    markers.add(await _createStoreMarker(storeLocation));

    for (var i = 0; i < _stops.length; i++) {
      final stop = _stops[i];
      final icon = await MapMarkers.numberedStop(
        stop.stopNumber,
        delivered: _delivered[i],
      );
      markers.add(Marker(
        markerId: MarkerId('stop_${stop.orderId}'),
        position: LatLng(stop.lat, stop.lng),
        icon: icon,
        anchor: const Offset(0.5, 0.5),
      ));
    }

    if (_currentLocation != null) {
      final riderIcon = await MapMarkers.riderMarker();
      markers.add(Marker(
        markerId: const MarkerId('rider'),
        position: _currentLocation!,
        icon: riderIcon,
        anchor: const Offset(0.5, 0.5),
      ));
    }

    final polylines = await _buildRoutePolyline(storeLocation);

    if (mounted) {
      setState(() {
        _markers = markers;
        _polylines = polylines;
      });
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

  Future<Set<Polyline>> _buildRoutePolyline(LatLng storeLocation) async {
    if (_stops.isEmpty) return {};

    final allPoints = <LatLng>[];
    var previous = storeLocation;

    for (final stop in _stops) {
      final stopLocation = LatLng(stop.lat, stop.lng);
      final drivingRoute = await _mapsService.getDrivingRoute(
        originLat: previous.latitude,
        originLng: previous.longitude,
        destLat: stopLocation.latitude,
        destLng: stopLocation.longitude,
      );

      if (drivingRoute != null && drivingRoute.points.isNotEmpty) {
        allPoints.addAll(
          drivingRoute.points.map((p) => LatLng(p.lat, p.lng)),
        );
      } else {
        allPoints.addAll([previous, stopLocation]);
      }
      previous = stopLocation;
    }

    final backRoute = await _mapsService.getDrivingRoute(
      originLat: previous.latitude,
      originLng: previous.longitude,
      destLat: storeLocation.latitude,
      destLng: storeLocation.longitude,
    );

    if (backRoute != null && backRoute.points.isNotEmpty) {
      allPoints.addAll(
        backRoute.points.map((p) => LatLng(p.lat, p.lng)),
      );
    } else {
      allPoints.addAll([previous, storeLocation]);
    }

    return {
      Polyline(
        polylineId: const PolylineId('batch_route'),
        points: allPoints,
        color: _primary,
        width: 4,
      ),
    };
  }

  void _fitCameraToBounds() {
    if (_markers.isEmpty || _mapController == null) return;

    var minLat = double.infinity;
    var maxLat = -double.infinity;
    var minLng = double.infinity;
    var maxLng = -double.infinity;

    for (final marker in _markers) {
      final lat = marker.position.latitude;
      final lng = marker.position.longitude;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        60,
      ),
    );
  }

  int get _completedCount => _delivered.where((d) => d).length;

  _BatchStop? get _currentStop {
    if (_stops.isEmpty || _currentStopIndex >= _stops.length) return null;
    return _stops[_currentStopIndex];
  }

  double _distanceToStop(_BatchStop stop) {
    if (_currentLocation != null) {
      return _mapsService.calculateDistance(
        startLatitude: _currentLocation!.latitude,
        startLongitude: _currentLocation!.longitude,
        endLatitude: stop.lat,
        endLongitude: stop.lng,
      );
    }
    return stop.distanceKm;
  }

  Future<void> _navigateToCurrentStop() async {
    final stop = _currentStop;
    if (stop == null) return;

    await _navigationService.launchGoogleMapsNavigation(
      destination: LatLng(stop.lat, stop.lng),
      origin: _currentLocation,
    );
  }

  Future<void> _callCustomer(String phone) async {
    if (phone.isEmpty) return;
    final success = await _contactService.makeCall(phone);
    if (!success && mounted) {
      _contactService.showContactError(context, 'call', phone);
    }
  }

  Future<void> _smsCustomer(String phone) async {
    if (phone.isEmpty) return;
    final success = await _contactService.sendSMS(phone);
    if (!success && mounted) {
      _contactService.showContactError(context, 'message', phone);
    }
  }

  Future<void> _markCurrentDelivered() async {
    final stop = _currentStop;
    if (stop == null || _isProcessing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Delivery'),
        content: Text(
          'Have you delivered order #${stop.orderId} to ${stop.customerName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _primary),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    final otp = await showDeliveryOtpDialog(context);
    if (!mounted || otp == null) return;

    setState(() => _isProcessing = true);
    try {
      await _riderService.markOrderDelivered(stop.orderId, otp: otp);
      if (!mounted) return;

      setState(() {
        _delivered[_currentStopIndex] = true;
      });
      await _buildMapElements();

      if (!_delivered.contains(false)) {
        _showAllDeliveredDialog();
      } else {
        setState(() {
          _currentStopIndex = _delivered.indexWhere((d) => !d);
        });
        _syncLocationTracking();
      }
    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message.isEmpty ? 'Failed to mark delivered' : message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showAllDeliveredDialog() {
    _locationService.stopSendingLocation();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF2ECC71).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Color(0xFF2ECC71),
                size: 44,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'All Delivered!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2ECC71),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You completed all ${widget.orderIds.length} deliveries.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: _greyText),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _goBackToStore() async {
    await _navigationService.launchGoogleMapsNavigation(
      destination: LatLng(
        StoreConfig.storeLatitude,
        StoreConfig.storeLongitude,
      ),
      origin: _currentLocation,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F7),
      appBar: AppBar(
        title: Text('Batch Delivery · ${widget.orderIds.length} stops'),
        backgroundColor: Colors.white,
        foregroundColor: _darkText,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _primary),
            )
          : _errorMessage != null
              ? _buildErrorState()
              : Column(
                  children: [
                    Expanded(child: _buildMap()),
                    Expanded(child: _buildBottomSheet()),
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
            const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _greyText),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadBatchStops,
              style: ElevatedButton.styleFrom(backgroundColor: _primary),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(StoreConfig.storeLatitude, StoreConfig.storeLongitude),
        zoom: 13,
      ),
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      onMapCreated: (controller) {
        _mapController = controller;
        _fitCameraToBounds();
      },
    );
  }

  Widget _buildBottomSheet() {
    final allDone = _delivered.every((d) => d);
    final current = _currentStop;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFEEEEEE),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_completedCount of ${widget.orderIds.length} delivered',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _darkText,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: widget.orderIds.isEmpty
                      ? 0
                      : _completedCount / widget.orderIds.length,
                  color: _primary,
                  backgroundColor: const Color(0xFFEEEEEE),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              children: [
                if (!allDone && current != null) ...[
                  _buildCurrentStopCard(current),
                  const SizedBox(height: 16),
                ],
                _buildOtherStopsList(),
                if (allDone) ...[
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _goBackToStore,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'All Delivered? Go Back to Store',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStopCard(_BatchStop stop) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(color: _primary, width: 4),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: _primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${stop.stopNumber}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Next Stop',
                      style: TextStyle(fontSize: 11, color: _greyText),
                    ),
                    Text(
                      stop.customerName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _darkText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stop.address,
                      style: const TextStyle(fontSize: 12, color: _greyText),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (stop.customerPhone.isNotEmpty) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _smsCustomer(stop.customerPhone),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: _primary),
                    ),
                    child: const Icon(
                      Icons.message_outlined,
                      color: _primary,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _callCustomer(stop.customerPhone),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: _primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.phone,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isProcessing ? null : _navigateToCurrentStop,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Navigate',
                    style: TextStyle(
                      color: _primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _markCurrentDelivered,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isProcessing ? 'Saving...' : 'Mark Delivered',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isProcessing ? null : _markCurrentFailedDelivery,
              icon: const Icon(Icons.error_outline, size: 16),
              label: const Text('Failed Delivery'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF39C12),
                side: const BorderSide(color: Color(0xFFF39C12)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markCurrentFailedDelivery() async {
    final stop = _currentStop;
    if (stop == null || _isProcessing) return;

    const reasons = <Map<String, String>>[
      {'value': 'CUSTOMER_UNREACHABLE', 'label': 'Customer Unreachable'},
      {'value': 'WRONG_ADDRESS', 'label': 'Wrong Address'},
      {'value': 'CUSTOMER_REFUSED', 'label': 'Customer Refused'},
    ];

    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Failed Delivery'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons
              .map(
                (r) => ListTile(
                  title: Text(r['label']!),
                  onTap: () => Navigator.pop(context, r['value']),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (selected == null) return;

    setState(() => _isProcessing = true);
    try {
      await _riderService.markFailedDelivery(stop.orderId, selected);
      if (!mounted) return;

      setState(() {
        _delivered[_currentStopIndex] = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Failed delivery recorded. Return package to store from order details.',
          ),
        ),
      );

      if (!_delivered.contains(false)) {
        _showAllDeliveredDialog();
      } else {
        setState(() {
          _currentStopIndex = _delivered.indexWhere((d) => !d);
        });
        _syncLocationTracking();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Widget _buildOtherStopsList() {
    if (_stops.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_delivered.every((d) => d))
          const Text(
            'All Stops',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _greyText,
            ),
          ),
        if (!_delivered.every((d) => d)) const SizedBox(height: 8),
        ...List.generate(_stops.length, (index) {
          if (index == _currentStopIndex && !_delivered[index]) {
            return const SizedBox.shrink();
          }
          return _buildStopListItem(index);
        }),
      ],
    );
  }

  Widget _buildStopListItem(int index) {
    final stop = _stops[index];
    final isDone = _delivered[index];
    final distance = _distanceToStop(stop);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isDone ? const Color(0xFFE0E0E0) : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDone ? const Color(0xFF9E9E9E) : _primary,
                width: 1.5,
              ),
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check, size: 14, color: Color(0xFF9E9E9E))
                  : Text(
                      '${stop.stopNumber}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDone ? const Color(0xFF9E9E9E) : _primary,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stop.customerName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDone ? const Color(0xFF9E9E9E) : _darkText,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  stop.address,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDone ? const Color(0xFFBDBDBD) : _greyText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            '${distance.toStringAsFixed(1)} km',
            style: TextStyle(
              fontSize: 11,
              color: isDone ? const Color(0xFFBDBDBD) : _greyText,
            ),
          ),
        ],
      ),
    );
  }
}
