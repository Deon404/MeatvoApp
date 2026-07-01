import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/constants/app_constants.dart';
import '../../widgets/location/delivery_location_coordinator.dart';
import '../../widgets/location/delivery_location_header.dart';
import '../../widgets/skeletons/home_content_skeleton.dart';

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

  static const _locationTimeout = Duration(seconds: 12);

  Future<void> _start() async {
    if (_started) return;
    _started = true;

    setState(() => _fetchingLocation = true);

    final permission = await Geolocator.checkPermission();
    if (!mounted) return;

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      final completed = await _withTimeout(
        _coordinator.requestPermissionThenGps(),
      );
      if (!mounted) return;
      if (DeliveryLocationSession.setupJustCompleted) return;
      if (!completed) {
        setState(() => _fetchingLocation = false);
      }
      await _openSheetFallback();
      return;
    }

    final completed = await _withTimeout(
      _coordinator.useCurrentLocation(
        skipRationale: true,
        fastGps: true,
      ),
    );
    if (!mounted) return;

    if (DeliveryLocationSession.setupJustCompleted) return;

    if (!completed) {
      setState(() => _fetchingLocation = false);
    }
    await _openSheetFallback();
  }

  Future<bool> _withTimeout(Future<void> action) async {
    try {
      await action.timeout(_locationTimeout);
      return true;
    } on TimeoutException {
      return false;
    }
  }

  Future<void> _openSheetFallback() async {
    if (!mounted || DeliveryLocationSession.setupJustCompleted) return;
    setState(() {
      _fetchingLocation = false;
      _showSheetFallback = true;
    });
    await _coordinator.showDeliveryLocationSheet();
    if (mounted && !DeliveryLocationSession.setupJustCompleted) {
      setState(() => _showSheetFallback = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: AppColors.primary,
              child: Column(
                children: [
                  SizedBox(height: topInset),
                  DeliveryLocationHeader(
                    title: 'Delivery',
                    subtitle: _fetchingLocation ? 'Fetching…' : null,
                    isLoading: _fetchingLocation,
                    loadingTitle: 'Getting your location…',
                    loadingSubtitle: 'Fetching…',
                    onTap: _fetchingLocation ? () {} : _openSheetFallback,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _showSheetFallback
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Text(
                          'Choose your delivery location to continue.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                  : const HomeContentSkeleton(),
            ),
          ],
        ),
      ),
    );
  }
}
