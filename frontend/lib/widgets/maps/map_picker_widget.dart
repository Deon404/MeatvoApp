import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../config/env_config.dart';
import '../../config/google_maps_setup.dart';
import '../../config/store_config.dart';
import '../../services/maps_platform_config.dart';
import '../../services/maps_service.dart';
import '../../services/delivery_service.dart';
import '../../core/constants/app_constants.dart';
import '../../utils/address_display_util.dart';
import '../location/location_flow_helper.dart';
import '../location/location_error_dialog.dart';

/// Map Picker Widget - Allows user to pick location on map
class MapPickerWidget extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final Function(double latitude, double longitude, Map<String, dynamic>? address)? onLocationSelected;

  const MapPickerWidget({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.onLocationSelected,
  });

  @override
  State<MapPickerWidget> createState() => _MapPickerWidgetState();
}

class _MapPickerWidgetState extends State<MapPickerWidget> {
  final MapsService _mapsService = MapsService();
  final DeliveryService _deliveryService = DeliveryService();
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  Map<String, dynamic>? _selectedAddress;
  bool _isLoadingAddress = false;
  bool _isLoadingLocation = false;
  bool _isWithinDeliveryRadius = false;
  String? _mapError;
  bool _isMapReady = false;
  Timer? _mapTimeoutTimer;
  
  // Default location (Store location - Bokaro)
  static final LatLng _defaultLocation = LatLng(
    StoreConfig.storeLatitude,
    StoreConfig.storeLongitude,
  );

  @override
  void initState() {
    super.initState();
    // Initialize location synchronously first
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedLocation = LatLng(
        widget.initialLatitude!,
        widget.initialLongitude!,
      );
    } else {
      // Use default location immediately so map has something to show
      _selectedLocation = _defaultLocation;
    }
    // Then load address asynchronously
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verifyNativeMapsConfig();
      _initializeLocation();
    });
  }

  Future<void> _verifyNativeMapsConfig() async {
    final native = await MapsPlatformConfig.getNativeConfig();
    if (!mounted || native == null) return;

    if (!native.isReady && EnvConfig.hasGoogleMapsApiKey) {
      setState(() {
        _mapError = GoogleMapsSetup.manifestKeyMissingError();
        _isMapReady = false;
      });
      debugPrint(
        '⚠️ Dart has Maps API key but Android manifest key length=${native.mapsApiKeyLength}',
      );
      return;
    }

    if (!native.isReady && !EnvConfig.hasGoogleMapsApiKey) {
      setState(() {
        _mapError =
            'Google Maps API key is missing.\n\n${GoogleMapsSetup.setupChecklist}';
        _isMapReady = false;
      });
    }
  }

  Future<void> _initializeLocation() async {
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      // Already set in initState, just get address
      await _getAddressForLocation(_selectedLocation!);
      if (mounted && _mapController != null) {
        _moveCameraToLocation(_selectedLocation!);
      }
    } else {
      // Try to get current location (silently, without showing dialogs on init)
      setState(() => _isLoadingLocation = true);
      try {
        final hasPermission = await _mapsService.hasLocationPermission();
        if (hasPermission) {
          final position = await _mapsService.getCurrentLocation(
            forceRequest: false,
            timeLimit: const Duration(seconds: 10),
          );
          if (position != null) {
            final location = LatLng(position.latitude, position.longitude);
            if (mounted) {
              setState(() {
                _selectedLocation = location;
              });
              await _getAddressForLocation(location);
              if (_mapController != null) {
                _moveCameraToLocation(location);
              }
            }
          } else {
            // Use default location
            if (mounted) {
              setState(() {
                _selectedLocation = _defaultLocation;
              });
              await _getAddressForLocation(_defaultLocation);
              if (_mapController != null) {
                _moveCameraToLocation(_defaultLocation);
              }
            }
          }
        } else {
          // No permission, use default location
          if (mounted) {
            setState(() {
              _selectedLocation = _defaultLocation;
            });
            await _getAddressForLocation(_defaultLocation);
            if (_mapController != null) {
              _moveCameraToLocation(_defaultLocation);
            }
          }
        }
      } catch (e) {
        debugPrint('Error initializing location: $e');
        // Use default location on error
        if (mounted) {
          setState(() {
            _selectedLocation = _defaultLocation;
          });
          await _getAddressForLocation(_defaultLocation);
          if (_mapController != null) {
            _moveCameraToLocation(_defaultLocation);
          }
        }
      } finally {
        if (mounted) {
          setState(() => _isLoadingLocation = false);
        }
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      final position = await resolveDeliveryLocation(context);
      if (!mounted) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      if (position == null) {
        setState(() {
          _isLoadingLocation = false;
          _selectedLocation = _defaultLocation;
        });
        _moveCameraToLocation(_defaultLocation);
        return;
      }

      final location = LatLng(position.latitude, position.longitude);
      setState(() {
        _selectedLocation = location;
      });
      await _getAddressForLocation(location);
      _moveCameraToLocation(location);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Current location loaded'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } on LocationException catch (e) {
      if (mounted) {
        final shouldRetry = await showLocationErrorDialog(context, e);
        if (shouldRetry == true) {
          await _getCurrentLocation();
          return;
        }
        setState(() {
          _selectedLocation = _defaultLocation;
        });
        _moveCameraToLocation(_defaultLocation);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _selectedLocation = _defaultLocation;
        });
        _moveCameraToLocation(_defaultLocation);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  Future<void> _getAddressForLocation(LatLng location) async {
    setState(() => _isLoadingAddress = true);

    try {
      final address = await _mapsService.getAddressWithPOI(
        latitude: location.latitude,
        longitude: location.longitude,
      );

      if (mounted) {
        setState(() {
          _selectedAddress = address;
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAddress = false);
      }
    }
  }

  void _moveCameraToLocation(LatLng location) {
    if (!mounted || _mapController == null) return;
    try {
      // Check if controller is still valid before using
      final controller = _mapController;
      if (controller != null && mounted) {
        controller.animateCamera(
          CameraUpdate.newLatLngZoom(location, 15.0),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error moving camera: $e');
      // If controller is disposed, clear reference
      if (e.toString().contains('disposed') || e.toString().contains('Bad state')) {
        _mapController = null;
      }
    }
  }

  void _onMapTap(LatLng location) {
    setState(() {
      _selectedLocation = location;
    });
    _validateLocation(location);
    _getAddressForLocation(location);
    _moveCameraToLocation(location);
  }

  Future<void> _validateLocation(LatLng location) async {
    final validation = await _deliveryService.validateDeliveryAddress(
      latitude: location.latitude,
      longitude: location.longitude,
    );
    
    if (mounted) {
      setState(() {
        _isWithinDeliveryRadius = validation.isValid;
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) async {
    // Check if widget is still mounted before assigning controller
    if (!mounted) {
      try {
        controller.dispose();
      } catch (e) {
        debugPrint('⚠️ Error disposing controller in _onMapCreated: $e');
      }
      return;
    }
    
    // Store controller reference
    _mapController = controller;
    
    // Clear any previous errors and timeout
    _mapTimeoutTimer?.cancel();
    
    if (!EnvConfig.hasGoogleMapsApiKey) {
      if (mounted) {
        setState(() {
          _mapError =
              'Google Maps API key is missing or invalid.\n\n${GoogleMapsSetup.setupChecklist}';
          _isMapReady = false;
        });
      }
      return;
    }

    final native = await MapsPlatformConfig.getNativeConfig();
    if (native != null && !native.isReady) {
      if (mounted) {
        setState(() {
          _mapError = GoogleMapsSetup.manifestKeyMissingError();
          _isMapReady = false;
        });
      }
      return;
    }
    
    final dartKey = EnvConfig.googleMapsApiKey;
    debugPrint(
      '✅ Google Maps controller created (dart key len=${dartKey.length}, '
      'native len=${native?.mapsApiKeyLength ?? -1})',
    );
    
    // Move camera to selected location immediately if available
    if (_selectedLocation != null && mounted) {
      try {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(_selectedLocation!, 15.0),
        );
        debugPrint('✅ Camera moved to location: ${_selectedLocation!.latitude}, ${_selectedLocation!.longitude}');
      } catch (e) {
        debugPrint('⚠️ Error moving camera: $e');
      }
    }
    
    // Set timeout to detect if map tiles don't load (increased to 15 seconds for slow networks)
    _mapTimeoutTimer = Timer(const Duration(seconds: 15), () async {
      if (!mounted || _isMapReady || _mapError != null) return;
      final native = await MapsPlatformConfig.getNativeConfig();
      setState(() {
        _mapError = GoogleMapsSetup.tilesLoadError(
          applicationId: native?.applicationId,
        );
      });
      debugPrint('⚠️ Map tiles timeout - tiles may not be loading');
    });
    
    // Don't try to access controller methods immediately - let onCameraIdle handle it
    // This prevents "used after dispose" errors
  }

  void _confirmSelection() {
    if (_selectedLocation == null) return;

    widget.onLocationSelected?.call(
      _selectedLocation!.latitude,
      _selectedLocation!.longitude,
      _selectedAddress,
    );
    Navigator.of(context).pop(<String, dynamic>{
      'latitude': _selectedLocation!.latitude,
      'longitude': _selectedLocation!.longitude,
      'address': _selectedAddress,
    });
  }

  @override
  Widget build(BuildContext context) {
    // Ensure we always have a location to show on map
    final locationToShow = _selectedLocation ?? _defaultLocation;
    
    if (!EnvConfig.hasGoogleMapsApiKey) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Select Location'),
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Google Maps API Key Required',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please add GOOGLE_MAPS_API_KEY to your .env file to use map picker.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          if (_isLoadingLocation)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.my_location),
              onPressed: _getCurrentLocation,
              tooltip: 'Use Current Location',
            ),
        ],
      ),
      body: _mapError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Google Maps Error',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _mapError!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _mapError = null;
                          _isMapReady = false;
                          // Don't reset controller here, let map recreate it
                        });
                        // Reinitialize location and map
                        _initializeLocation();
                      },
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
            )
          : Stack(
              children: [
                // Google Map
                GoogleMap(
                  key: const ValueKey('map_picker'), // Fixed key - don't change on rebuild
                  initialCameraPosition: CameraPosition(
                    target: locationToShow,
                    zoom: 15.0,
                  ),
                  onMapCreated: _onMapCreated,
                  onTap: _onMapTap,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  mapType: MapType.normal,
                  zoomControlsEnabled: true, // Enable zoom controls for better UX
                  zoomGesturesEnabled: true,
                  scrollGesturesEnabled: true,
                  tiltGesturesEnabled: false,
                  rotateGesturesEnabled: true,
                  compassEnabled: true, // Enable compass
                  mapToolbarEnabled: false,
                  liteModeEnabled: false,
                  // Add error handling for map tiles
                  onCameraIdle: () {
                    // Map is ready and camera stopped moving - tiles likely loaded
                    if (mounted) {
                      // Cancel timeout since tiles are loading
                      _mapTimeoutTimer?.cancel();
                      
                      // Mark map as ready if not already
                      if (!_isMapReady) {
                        setState(() {
                          _isMapReady = true;
                          _mapError = null;
                        });
                        debugPrint('✅ Google Maps tiles loaded successfully (onCameraIdle)');
                      } else if (_mapError != null) {
                        // Clear error if map is working
                        setState(() {
                          _mapError = null;
                        });
                      }
                    }
                    
                    if (_selectedLocation != null && mounted) {
                      _validateLocation(_selectedLocation!);
                      _getAddressForLocation(_selectedLocation!);
                    }
                  },
                  onCameraMove: (CameraPosition position) {
                    setState(() => _selectedLocation = position.target);
                  },
            circles: {
              // 8km delivery radius circle
              Circle(
                circleId: const CircleId('delivery_radius'),
                center: LatLng(
                  StoreConfig.storeLatitude,
                  StoreConfig.storeLongitude,
                ),
                radius: StoreConfig.deliveryRadiusKm * 1000, // Convert km to meters
                fillColor: AppColors.success.withValues(alpha: 0.2),
                strokeColor: AppColors.success,
                strokeWidth: 2,
              ),
            },
            markers: {
              Marker(
                markerId: const MarkerId('store_location'),
                position: LatLng(
                  StoreConfig.storeLatitude,
                  StoreConfig.storeLongitude,
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                infoWindow: const InfoWindow(
                  title: 'Meatvo Store',
                  snippet: 'Bokaro, Jharkhand',
                ),
              ),
            },
          ),
          
          // Center marker (fixed)
          const Center(
            child: Icon(
              Icons.location_on,
              color: AppColors.primary,
              size: 48,
            ),
          ),
          
          // Address card at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select delivery location',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // YOUR LOCATION label (Zomato style)
                      Row(
                        children: [
                          const Text(
                            'YOUR LOCATION',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_isLoadingAddress)
                        const Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Loading address...',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        )
                      else if (_selectedAddress != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // POI Name or Place Name (Primary - Zomato style)
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 18,
                                  color: _isWithinDeliveryRadius
                                      ? AppColors.success
                                      : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedAddress!['display_name'] as String? ??
                                    _selectedAddress!['poi_name'] as String? ??
                                    _selectedAddress!['place_name'] as String? ??
                                    'Address',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // CHANGE button (Zomato style)
                                TextButton(
                                  onPressed: () {
                                    // Allow user to search or change location
                                    // This can open a search dialog
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'CHANGE',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Full address (Secondary - Zomato style)
                            Padding(
                              padding: const EdgeInsets.only(left: 26),
                              child: Text(
                                _selectedAddress!['full_address'] as String? ??
                                _buildAddressString(_selectedAddress!),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_selectedLocation != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    _isWithinDeliveryRadius
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    size: 16,
                                    color: _isWithinDeliveryRadius
                                        ? AppColors.success
                                        : Colors.red,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isWithinDeliveryRadius
                                        ? 'Delivery available (${StoreConfig.getFormattedDistance(_selectedLocation!.latitude, _selectedLocation!.longitude)} from store)'
                                        : 'Delivery not available (${StoreConfig.getFormattedDistance(_selectedLocation!.latitude, _selectedLocation!.longitude)} from store)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _isWithinDeliveryRadius
                                          ? AppColors.success
                                          : Colors.red,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        )
                      else
                        const Text(
                          'Tap on map to select location',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (_selectedLocation != null && _isWithinDeliveryRadius)
                              ? _confirmSelection
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isWithinDeliveryRadius
                                ? AppColors.primary
                                : AppColors.surface,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _isWithinDeliveryRadius
                                ? 'Confirm Location'
                                : 'Select Location Within 8km',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildAddressString(Map<String, dynamic> address) {
    return buildAddressStringFromMap(address);
  }

  @override
  void dispose() {
    _mapTimeoutTimer?.cancel();
    // Clear controller reference before disposing to prevent use after dispose
    final controller = _mapController;
    _mapController = null;
    try {
      controller?.dispose();
    } catch (e) {
      debugPrint('⚠️ Error disposing map controller: $e');
    }
    super.dispose();
  }
}

