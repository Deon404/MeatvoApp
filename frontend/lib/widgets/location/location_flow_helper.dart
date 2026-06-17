import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/maps_service.dart';
import 'delivery_location_coordinator.dart';
import 'location_error_dialog.dart';
import 'permission_dialog.dart';

/// Shared flow: optional pre-permission → native dialogs → GPS fetch.
Future<Position?> resolveDeliveryLocation(
  BuildContext context, {
  bool skipRationale = false,
}) async {
  final mapsService = MapsService();

  var permission = await Geolocator.checkPermission();

  if (permission == LocationPermission.whileInUse ||
      permission == LocationPermission.always) {
    try {
      return await mapsService.resolveCurrentPosition(
        requestPermissionIfDenied: false,
      );
    } on LocationException catch (e) {
      if (!context.mounted) return null;
      final showFallback = e.errorType ==
              LocationErrorType.permissionDeniedForever ||
          (e.errorType == LocationErrorType.serviceDisabled &&
              e.nativeResolutionAttempted);
      if (showFallback) {
        await showLocationErrorDialog(context, e);
      }
      return null;
    }
  }

  if (permission == LocationPermission.denied) {
    if (skipRationale) {
      return null;
    }

    if (!DeliveryLocationSession.permissionPromptShown) {
      if (!context.mounted) return null;
      DeliveryLocationSession.permissionPromptShown = true;
      final granted = await showLocationPermissionDialog(
        context,
        title: 'Enable location for delivery',
        message:
            'Allow Meatvo to access your location so we can deliver fresh products to your doorstep.',
      );
      if (!granted) return null;
      if (!context.mounted) return null;
      permission = await Geolocator.checkPermission();
    } else {
      permission = await mapsService.requestLocationPermission();
    }
  }

  if (permission == LocationPermission.deniedForever) {
    if (context.mounted) {
      await showLocationPermissionDialog(
        context,
        title: 'Location access is off',
        message:
            'Open settings to allow location access for accurate delivery.',
        showSettingsButton: true,
      );
    }
    return null;
  }

  if (permission == LocationPermission.denied) {
    return null;
  }

  try {
    return await mapsService.resolveCurrentPosition(
      requestPermissionIfDenied: false,
    );
  } on LocationException catch (e) {
    if (!context.mounted) return null;

    final showFallback = e.errorType == LocationErrorType.permissionDeniedForever ||
        (e.errorType == LocationErrorType.serviceDisabled &&
            e.nativeResolutionAttempted);

    if (showFallback) {
      await showLocationErrorDialog(context, e);
    }
    return null;
  }
}
