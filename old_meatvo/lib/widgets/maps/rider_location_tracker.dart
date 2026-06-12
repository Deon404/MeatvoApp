import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../config/env_config.dart';
import '../../config/store_config.dart';
import '../../core/constants/app_constants.dart';
import '../../services/maps_service.dart';

/// Rider Location Tracker Widget - Shows rider location on map in real-time
class RiderLocationTracker extends StatefulWidget {
  final String riderId;
  final double? riderLatitude;
  final double? riderLongitude;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final String? deliveryAddress;
  final String statusLabel;
  final String? statusSubLabel;
  final bool showRouteLine;
  final bool showActionButton;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback? onActionTap;

  const RiderLocationTracker({
    super.key,
    required this.riderId,
    this.riderLatitude,
    this.riderLongitude,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.deliveryAddress,
    this.statusLabel = 'Rider is on the way',
    this.statusSubLabel,
    this.showRouteLine = false,
    this.showActionButton = false,
    this.actionLabel = 'Open in Maps',
    this.actionIcon = Icons.navigation_rounded,
    this.onActionTap,
  });

  @override
  State<RiderLocationTracker> createState() => _RiderLocationTrackerState();
}

class _RiderLocationTrackerState extends State<RiderLocationTracker> {
  final MapsService _mapsService = MapsService();
  GoogleMapController? _mapController;
  LatLng? _riderLocation;
  LatLng? _deliveryLocation;
  bool _isLoading = true;
  String? _errorMessage;
  String? _etaText;
  String? _distanceText;

  static final LatLng _fallbackLocation = LatLng(
    StoreConfig.storeLatitude,
    StoreConfig.storeLongitude,
  );

  @override
  void initState() {
    super.initState();
    _initializeLocations();
  }

  @override
  void didUpdateWidget(covariant RiderLocationTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.riderLatitude != null &&
        widget.riderLongitude != null &&
        (widget.riderLatitude != oldWidget.riderLatitude ||
            widget.riderLongitude != oldWidget.riderLongitude)) {
      setState(() {
        _riderLocation = LatLng(widget.riderLatitude!, widget.riderLongitude!);
      });
      _updateCameraPosition();
      _calculateRouteInfo();
    }
  }

  Future<void> _initializeLocations() async {
    setState(() => _isLoading = true);

    try {
      // Get initial rider location
      await _fetchRiderLocation();

      // Set delivery location if provided
      if (widget.deliveryLatitude != null && widget.deliveryLongitude != null) {
        setState(() {
          _deliveryLocation = LatLng(
            widget.deliveryLatitude!,
            widget.deliveryLongitude!,
          );
        });
      }

      // Move camera to show both locations
      _updateCameraPosition();
      
      // Calculate ETA and distance if both locations available
      _calculateRouteInfo();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load rider location: $e';
        _isLoading = false;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _calculateRouteInfo() {
    if (_riderLocation != null && _deliveryLocation != null) {
      final routeInfo = _mapsService.calculateRouteInfo(
        startLatitude: _riderLocation!.latitude,
        startLongitude: _riderLocation!.longitude,
        endLatitude: _deliveryLocation!.latitude,
        endLongitude: _deliveryLocation!.longitude,
        travelMode: 'driving',
      );
      
      setState(() {
        _etaText = routeInfo['etaFormatted'] as String;
        _distanceText = routeInfo['distanceFormatted'] as String;
      });
    }
  }

  Future<void> _fetchRiderLocation() async {
    if (widget.riderLatitude != null && widget.riderLongitude != null) {
      setState(() {
        _riderLocation = LatLng(widget.riderLatitude!, widget.riderLongitude!);
      });
      return;
    }
    setState(() => _riderLocation = null);
  }

  void _updateCameraPosition() {
    if (_mapController == null) return;

    if (_riderLocation != null && _deliveryLocation != null) {
      // Show both rider and delivery location
      final bounds = LatLngBounds(
        southwest: LatLng(
          _riderLocation!.latitude < _deliveryLocation!.latitude
              ? _riderLocation!.latitude
              : _deliveryLocation!.latitude,
          _riderLocation!.longitude < _deliveryLocation!.longitude
              ? _riderLocation!.longitude
              : _deliveryLocation!.longitude,
        ),
        northeast: LatLng(
          _riderLocation!.latitude > _deliveryLocation!.latitude
              ? _riderLocation!.latitude
              : _deliveryLocation!.latitude,
          _riderLocation!.longitude > _deliveryLocation!.longitude
              ? _riderLocation!.longitude
              : _deliveryLocation!.longitude,
        ),
      );

      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100.0),
      );
    } else if (_riderLocation != null) {
      // Show only rider location
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_riderLocation!, 15.0),
      );
    } else if (_deliveryLocation != null) {
      // Show only delivery location
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_deliveryLocation!, 15.0),
      );
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _updateCameraPosition();
  }

  @override
  Widget build(BuildContext context) {
    final apiKey = EnvConfig.googleMapsApiKey;

    if (apiKey.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.divider,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map, size: 48, color: AppColors.surface),
              SizedBox(height: 8),
              Text(
                'Google Maps API Key Required',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.divider,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.divider,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final initialLocation =
        _riderLocation ?? _deliveryLocation ?? _fallbackLocation;

    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: initialLocation,
                zoom: 13.0,
              ),
              onMapCreated: _onMapCreated,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              markers: _buildMarkers(),
              polylines: _buildPolylines(),
            ),
            // Info overlay
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.showActionButton
                          ? Icons.navigation_rounded
                          : Icons.delivery_dining,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.statusLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (widget.statusSubLabel != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.statusSubLabel!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                          if (_etaText != null || _distanceText != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (_etaText != null) ...[
                                  Icon(
                                    Icons.access_time,
                                    size: 12,
                                    color: AppColors.success,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _etaText!,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                                if (_etaText != null && _distanceText != null)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4),
                                    child: Text(
                                      '•',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                if (_distanceText != null) ...[
                                  Icon(
                                    Icons.straighten,
                                    size: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _distanceText!,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (widget.showActionButton &&
                        widget.onActionTap != null) ...[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: widget.onActionTap,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                        icon: Icon(widget.actionIcon, size: 16),
                        label: Text(
                          widget.actionLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    // Rider marker
    if (_riderLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('rider'),
          position: _riderLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(
            title: 'Rider Location',
            snippet: 'Your delivery rider',
          ),
        ),
      );
    }

    // Delivery location marker
    if (_deliveryLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('delivery'),
          position: _deliveryLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Delivery Address',
            snippet: widget.deliveryAddress ?? 'Your delivery location',
          ),
        ),
      );
    }

    return markers;
  }

  Set<Polyline> _buildPolylines() {
    if (!widget.showRouteLine ||
        _riderLocation == null ||
        _deliveryLocation == null) {
      return const <Polyline>{};
    }

    return {
      Polyline(
        polylineId: const PolylineId('rider_to_delivery'),
        points: [_riderLocation!, _deliveryLocation!],
        color: AppColors.primary,
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    };
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
