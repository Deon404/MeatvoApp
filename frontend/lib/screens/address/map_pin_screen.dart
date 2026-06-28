import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../config/env_config.dart';
import '../../config/google_maps_setup.dart';
import '../../config/store_config.dart';
import '../../core/constants/app_constants.dart';
import '../../models/address_model.dart';
import '../../services/delivery_service.dart';
import '../../services/maps_service.dart';
import '../../utils/address_display_util.dart';
import '../../widgets/location/serviceability_banner.dart';
import 'address_details_screen.dart';

/// Zappfresh-style full-screen map with fixed center pin.
class MapPinScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final Map<String, dynamic>? initialAddress;

  const MapPinScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
  });

  @override
  State<MapPinScreen> createState() => _MapPinScreenState();
}

class _MapPinScreenState extends State<MapPinScreen> {
  final MapsService _mapsService = MapsService();
  final DeliveryService _deliveryService = DeliveryService();
  GoogleMapController? _controller;

  late LatLng _center;
  GeocodedAddressFields _fields = const GeocodedAddressFields();
  bool _isResolving = false;
  bool _isServiceable = true;
  String? _distanceLabel;
  String? _mapError;

  @override
  void initState() {
    super.initState();
    _center = LatLng(
      widget.initialLatitude ?? StoreConfig.storeLatitude,
      widget.initialLongitude ?? StoreConfig.storeLongitude,
    );
    if (widget.initialAddress != null) {
      _fields = GeocodedAddressFields.fromMap(widget.initialAddress!);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveCenter());
  }

  Future<void> _resolveCenter() async {
    if (!EnvConfig.hasGoogleMapsApiKey) {
      debugPrint(GoogleMapsSetup.setupChecklist);
      setState(() {
        _mapError = GoogleMapsSetup.customerLocationMapMessage;
      });
      return;
    }

    setState(() => _isResolving = true);
    final validation = await _deliveryService.validateDeliveryAddress(
      latitude: _center.latitude,
      longitude: _center.longitude,
    );

    final address = widget.initialAddress ??
        await _mapsService.getAddressFromCoordinates(
          latitude: _center.latitude,
          longitude: _center.longitude,
        );

    if (!mounted) return;
    setState(() {
      _isResolving = false;
      _isServiceable = validation.isValid;
      _distanceLabel = validation.distanceFormatted;
      if (address != null) {
        _fields = GeocodedAddressFields.fromMap(address);
      }
    });
  }

  Future<void> _onCameraIdle() async {
    if (_controller == null) return;
    setState(() => _isResolving = true);

    final validation = await _deliveryService.validateDeliveryAddress(
      latitude: _center.latitude,
      longitude: _center.longitude,
    );
    final address = await _mapsService.getAddressFromCoordinates(
      latitude: _center.latitude,
      longitude: _center.longitude,
    );

    if (!mounted) return;
    setState(() {
      _isResolving = false;
      _isServiceable = validation.isValid;
      _distanceLabel = validation.distanceFormatted;
      if (address != null) {
        _fields = GeocodedAddressFields.fromMap(address);
      }
    });
  }

  Future<void> _openDetails() async {
    if (!_isServiceable) return;

    final saved = await Navigator.of(context).push<AddressModel>(
      MaterialPageRoute(
        builder: (_) => AddressDetailsScreen(
          latitude: _center.latitude,
          longitude: _center.longitude,
          geocodedAddress: {
            'place_name': _fields.locality,
            'address_line1': _fields.street,
            'city': _fields.locality,
            'state': _fields.state,
            'pincode': _fields.pincode,
            'landmark': _fields.landmark,
          },
        ),
      ),
    );

    if (saved != null && mounted) {
      Navigator.of(context).pop(saved);
    }
  }

  String get _localityTitle {
    if (_fields.locality.isNotEmpty) return _fields.locality;
    if (_fields.street.isNotEmpty) return _fields.street.split(',').first;
    return 'Selected location';
  }

  String get _addressLine {
    if (_fields.street.isNotEmpty) return _fields.street;
    return _fields.areaDisplayLine;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Add new address'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                if (_mapError != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        _mapError!,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                else
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _center,
                      zoom: 16,
                    ),
                    onMapCreated: (c) => _controller = c,
                    onCameraMove: (pos) => _center = pos.target,
                    onCameraIdle: _onCameraIdle,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    markers: const {},
                  ),
                IgnorePointer(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(bottom: 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface.withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            'Move the map to adjust your location',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.location_on_rounded,
                          size: 48,
                          color: AppColors.primary,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isResolving)
                  const Positioned(
                    top: 12,
                    right: 12,
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                ServiceabilityBanner(
                  isServiceable: _isServiceable,
                  distanceLabel: _distanceLabel,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(_localityTitle, style: AppTextStyles.h2.copyWith(fontSize: 18)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _addressLine,
                  style: AppTextStyles.caption.copyWith(height: 1.4),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isServiceable && !_isResolving ? _openDetails : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                    ),
                    child: Text(
                      _isServiceable
                          ? 'Add more address details'
                          : 'Outside delivery zone',
                      style: AppTextStyles.button.copyWith(fontSize: 15),
                    ),
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
