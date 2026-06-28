import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../config/env_config.dart';
import '../../config/google_maps_setup.dart';
import '../../config/store_config.dart';
import '../../services/maps_platform_config.dart';
import '../../core/constants/app_constants.dart';
import '../../services/delivery_service.dart';
import '../../services/maps_service.dart';
import 'serviceability_banner.dart';

/// Compact draggable-pin map for address form (Blinkit-style confirm step).
class InlineLocationMapPanel extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final ValueChanged<double> onLatitudeChanged;
  final ValueChanged<double> onLongitudeChanged;
  final void Function(Map<String, dynamic>? address)? onAddressResolved;
  final bool showServiceabilityBanner;

  const InlineLocationMapPanel({
    super.key,
    this.latitude,
    this.longitude,
    required this.onLatitudeChanged,
    required this.onLongitudeChanged,
    this.onAddressResolved,
    this.showServiceabilityBanner = true,
  });

  @override
  State<InlineLocationMapPanel> createState() => _InlineLocationMapPanelState();
}

class _InlineLocationMapPanelState extends State<InlineLocationMapPanel> {
  final MapsService _mapsService = MapsService();
  final DeliveryService _deliveryService = DeliveryService();
  GoogleMapController? _controller;
  LatLng? _center;
  bool _isResolving = false;
  bool _isServiceable = true;
  String? _distanceLabel;
  String? _configError;

  @override
  void initState() {
    super.initState();
    _center = LatLng(
      widget.latitude ?? StoreConfig.storeLatitude,
      widget.longitude ?? StoreConfig.storeLongitude,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkMapsConfig();
      _validateAndResolve();
    });
  }

  Future<void> _checkMapsConfig() async {
    if (!EnvConfig.hasGoogleMapsApiKey) {
      debugPrint(GoogleMapsSetup.setupChecklist);
      if (!mounted) return;
      setState(() {
        _configError = GoogleMapsSetup.customerLocationMapMessage;
      });
      return;
    }
    final native = await MapsPlatformConfig.getNativeConfig();
    if (!mounted || native == null) return;
    if (!native.isReady) {
      debugPrint(GoogleMapsSetup.devManifestKeyDiagnostic());
      setState(() {
        _configError = GoogleMapsSetup.customerLocationMapMessage;
      });
    }
  }

  @override
  void didUpdateWidget(covariant InlineLocationMapPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.latitude != oldWidget.latitude ||
        widget.longitude != oldWidget.longitude) {
      if (widget.latitude != null && widget.longitude != null) {
        _center = LatLng(widget.latitude!, widget.longitude!);
        _controller?.animateCamera(CameraUpdate.newLatLng(_center!));
      }
    }
  }

  Future<void> _validateAndResolve() async {
    final loc = _center;
    if (loc == null) return;

    final validation = await _deliveryService.validateDeliveryAddress(
      latitude: loc.latitude,
      longitude: loc.longitude,
    );

    if (!mounted) return;
    setState(() {
      _isServiceable = validation.isValid;
      _distanceLabel = validation.distanceFormatted;
    });

    widget.onLatitudeChanged(loc.latitude);
    widget.onLongitudeChanged(loc.longitude);

    setState(() => _isResolving = true);
    final address = await _mapsService.getAddressFromCoordinates(
      latitude: loc.latitude,
      longitude: loc.longitude,
    );
    if (mounted) {
      setState(() => _isResolving = false);
      widget.onAddressResolved?.call(address);
    }
  }

  Future<void> _onCameraIdle() async {
    await _validateAndResolve();
  }

  @override
  Widget build(BuildContext context) {
    if (_configError != null || !EnvConfig.hasGoogleMapsApiKey) {
      return Container(
        color: AppColors.surface,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(12),
        child: Text(
          _configError ?? GoogleMapsSetup.customerMapUnavailableShort,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    final target = _center!;

    return Stack(
      fit: StackFit.expand,
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: target, zoom: 16),
          onMapCreated: (c) => _controller = c,
          onCameraMove: (pos) => _center = pos.target,
          onCameraIdle: _onCameraIdle,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          markers: const {},
        ),
        const Center(
          child: Icon(Icons.location_on, size: 48, color: AppColors.primary),
        ),
        if (_isResolving)
          const Positioned(
            top: 12,
            right: 12,
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: widget.showServiceabilityBanner
              ? ServiceabilityBanner(
                  isServiceable: _isServiceable,
                  distanceLabel: _distanceLabel,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
