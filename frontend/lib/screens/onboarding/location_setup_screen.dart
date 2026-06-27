import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/constants/app_constants.dart';
import '../../widgets/location/delivery_location_coordinator.dart';
import '../../widgets/location/delivery_location_header.dart';

/// Slim first-time gate: auto GPS then map pin flow.
class LocationSetupScreen extends ConsumerStatefulWidget {
  const LocationSetupScreen({super.key});

  @override
  ConsumerState<LocationSetupScreen> createState() =>
      _LocationSetupScreenState();
}

class _LocationSetupScreenState extends ConsumerState<LocationSetupScreen> {
  late final DeliveryLocationCoordinator _coordinator;

  bool _fetchingLocation = false;
  bool _showSheetFallback = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _coordinator = DeliveryLocationCoordinator(
      contextOf: () => context,
      ref: ref,
      navigateHomeOnComplete: true,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (_started) return;
    _started = true;

    setState(() => _fetchingLocation = true);

    final permission = await Geolocator.checkPermission();
    if (!mounted) return;

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      await _coordinator.requestPermissionThenGps();
      if (!mounted) return;
      if (DeliveryLocationSession.setupJustCompleted) return;
      setState(() {
        _fetchingLocation = false;
        _showSheetFallback = true;
      });
      await _coordinator.showDeliveryLocationSheet();
      if (mounted && !DeliveryLocationSession.setupJustCompleted) {
        setState(() => _showSheetFallback = false);
      }
      return;
    }

    await _coordinator.useCurrentLocation(skipRationale: true);
    if (!mounted) return;

    if (!DeliveryLocationSession.setupJustCompleted) {
      setState(() {
        _fetchingLocation = false;
        _showSheetFallback = true;
      });
      await _coordinator.showDeliveryLocationSheet();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DeliveryLocationHeader(
                title: 'Delivery',
                subtitle: _fetchingLocation ? 'Fetching…' : null,
                isLoading: _fetchingLocation,
                loadingTitle: 'Getting your location…',
                loadingSubtitle: 'Fetching…',
                onTap: () {},
              ),
              Expanded(
                child: Center(
                  child: _showSheetFallback
                      ? Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Text(
                            'Choose your delivery location to continue.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        )
                      : const CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.primary,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
