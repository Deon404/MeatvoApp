import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../app_navigator_key.dart';
import '../../main.dart' show MyHomePage;
import '../../models/address_model.dart';
import '../../screens/address/map_pin_screen.dart';
import '../../screens/address/search_locality_screen.dart';
import '../../services/address_service.dart';
import '../../services/maps_service.dart';
import '../../viewmodels/home_provider.dart';
import 'delivery_location_sheet.dart';
import 'location_flow_helper.dart';

/// How the shared location coordinator completes after save/select.
enum DeliveryLocationFlowMode {
  /// Home gate: refresh catalog and optionally navigate to home.
  homeGate,

  /// Checkout / profile picker: return [AddressModel] to caller, stay on screen.
  picker,
}

/// Session flags to avoid duplicate permission prompts and home gate sheets.
class DeliveryLocationSession {
  static bool permissionPromptShown = false;
  static bool setupJustCompleted = false;

  static void markSetupCompleted() {
    setupJustCompleted = true;
  }

  static void consumeSetupCompleted() {
    setupJustCompleted = false;
  }
}

/// Shared delivery-location logic for setup screen and home sheet.
class DeliveryLocationCoordinator {
  DeliveryLocationCoordinator({
    required BuildContext Function() contextOf,
    required this.ref,
    this.mode = DeliveryLocationFlowMode.homeGate,
    this.useRootNavigator = false,
    this.navigateHomeOnComplete = true,
  }) : _contextOf = contextOf;

  final BuildContext Function() _contextOf;
  final WidgetRef ref;
  final DeliveryLocationFlowMode mode;
  final bool useRootNavigator;
  final bool navigateHomeOnComplete;

  final AddressService _addressService = AddressService();
  final MapsService _mapsService = MapsService();

  BuildContext get context => _contextOf();

  NavigatorState get _navigator {
    if (useRootNavigator) {
      final root = appNavigatorKey.currentState;
      if (root != null) return root;
      return Navigator.of(context, rootNavigator: true);
    }
    return Navigator.of(context);
  }

  Future<List<AddressModel>> loadSavedAddresses() {
    return _addressService.getUserAddresses();
  }

  Future<bool> isLocationPermissionGranted() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  Future<AddressModel?> selectSavedAddress(AddressModel address) async {
    try {
      await _addressService.setDefaultAddress(address.id);
      if (!context.mounted) return null;
      if (mode == DeliveryLocationFlowMode.picker) {
        await ref.read(homeViewModelProvider.notifier).refresh();
        return address;
      }
      await _completeFlow(
        snackbarMessage: 'Delivery location updated',
      );
      return address;
    } catch (_) {
      return null;
    }
  }

  Future<void> requestPermissionThenGps() async {
    DeliveryLocationSession.permissionPromptShown = true;
    final permission = await _mapsService.requestLocationPermission();
    if (!context.mounted) return;

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      await useCurrentLocation(skipRationale: true);
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      await showDeliveryLocationSheet();
    }
  }

  Future<void> showDeliveryLocationSheet() async {
    if (!context.mounted) return;
    await DeliveryLocationSheet.show(context);
  }

  Future<AddressModel?> useCurrentLocation({bool skipRationale = false}) async {
    final position = await resolveDeliveryLocation(
      context,
      skipRationale: skipRationale,
    );
    if (position == null || !context.mounted) {
      if (context.mounted && !skipRationale) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to get your location. Try search or pick on map.',
            ),
          ),
        );
      }
      return null;
    }

    final address = await _mapsService.getAddressFromCoordinates(
      latitude: position.latitude,
      longitude: position.longitude,
    );

    if (!context.mounted) return null;
    return openMapPin(
      latitude: position.latitude,
      longitude: position.longitude,
      geocodedAddress: address,
    );
  }

  Future<AddressModel?> searchManually() async {
    final place = await _navigator.push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const SearchLocalityScreen()),
    );
    if (place == null || !context.mounted) return null;

    final lat = (place['latitude'] as num?)?.toDouble();
    final lng = (place['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;

    return openMapPin(
      latitude: lat,
      longitude: lng,
      geocodedAddress: place,
    );
  }

  Future<AddressModel?> openMapPin({
    double? latitude,
    double? longitude,
    Map<String, dynamic>? geocodedAddress,
  }) async {
    final saved = await _navigator.push<AddressModel>(
      MaterialPageRoute(
        builder: (_) => MapPinScreen(
          initialLatitude: latitude,
          initialLongitude: longitude,
          initialAddress: geocodedAddress,
        ),
      ),
    );

    if (saved == null || !context.mounted) return null;

    if (mode == DeliveryLocationFlowMode.picker) {
      await ref.read(homeViewModelProvider.notifier).refresh();
      return saved;
    }

    await _completeFlow(snackbarMessage: 'Address saved successfully');
    return saved;
  }

  /// Returns true when the app navigated to [MyHomePage] (caller must not pop).
  Future<bool> _completeFlow({required String snackbarMessage}) async {
    if (mode == DeliveryLocationFlowMode.picker) return false;

    DeliveryLocationSession.markSetupCompleted();
    await ref.read(homeViewModelProvider.notifier).refresh();
    if (!context.mounted) return false;

    final messenger = ScaffoldMessenger.maybeOf(context);

    if (navigateHomeOnComplete) {
      _navigator.pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const MyHomePage(title: 'Meatvo'),
        ),
        (_) => false,
      );
      final rootMessenger =
          appNavigatorKey.currentContext != null
              ? ScaffoldMessenger.maybeOf(appNavigatorKey.currentContext!)
              : null;
      (rootMessenger ?? messenger)?.showSnackBar(
        SnackBar(content: Text(snackbarMessage)),
      );
      return true;
    }

    messenger?.showSnackBar(
      SnackBar(content: Text(snackbarMessage)),
    );
    return false;
  }
}
