import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../design_system/tokens/meatvo_radii.dart';
import '../../design_system/tokens/meatvo_spacing.dart';
import '../../models/address_model.dart';
import '../../main.dart' show MyHomePage;
import '../../screens/address/address_form_screen.dart';
import '../../services/address_service.dart';
import '../../services/maps_service.dart';
import '../../viewmodels/home_provider.dart';
import '../../widgets/location/location_flow_helper.dart';
import '../../widgets/location/location_search_sheet.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/onboarding/delivery_location_illustration.dart';
import '../../widgets/onboarding/location_fetch_skeleton.dart';
import '../../widgets/skeletons/shimmer_base.dart';

/// Premium full-screen location + address selection after login.
class LocationSetupScreen extends ConsumerStatefulWidget {
  const LocationSetupScreen({super.key});

  @override
  ConsumerState<LocationSetupScreen> createState() => _LocationSetupScreenState();
}

class _LocationSetupScreenState extends ConsumerState<LocationSetupScreen> {
  final AddressService _addressService = AddressService();
  final MapsService _mapsService = MapsService();

  List<AddressModel> _addresses = [];
  bool _loadingAddresses = true;
  bool _fetchingLocation = false;
  bool _actionInProgress = false;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    try {
      final list = await _addressService.getUserAddresses();
      if (mounted) {
        setState(() {
          _addresses = list;
          _loadingAddresses = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAddresses = false);
    }
  }

  Future<void> _onAddressSaved() async {
    await ref.read(homeViewModelProvider.notifier).refresh();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const MyHomePage(title: 'Meatvo'),
      ),
      (_) => false,
    );
  }

  Future<void> _selectSavedAddress(AddressModel address) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _actionInProgress = true);
    try {
      await _addressService.setDefaultAddress(address.id);
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Delivery location updated')),
        );
        await _onAddressSaved();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not update address. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _openAddressForm({
    double? latitude,
    double? longitude,
    Map<String, dynamic>? initialAddress,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddressFormScreen(
          initialLatitude: latitude,
          initialLongitude: longitude,
          initialAddress: initialAddress,
        ),
      ),
    );
    if (!mounted) return;
    if (saved != true) return;

    messenger.showSnackBar(
      const SnackBar(content: Text('Address saved successfully')),
    );
    await _onAddressSaved();
  }

  Future<void> _onSearchManually() async {
    if (_actionInProgress || _fetchingLocation) return;

    final place = await LocationSearchSheet.show(context);
    if (place == null || !mounted) return;

    final lat = (place['latitude'] as num?)?.toDouble();
    final lng = (place['longitude'] as num?)?.toDouble();
    if (lat != null && lng != null) {
      final address = await _mapsService.getAddressFromCoordinates(
        latitude: lat,
        longitude: lng,
      );
      await _openAddressForm(
        latitude: lat,
        longitude: lng,
        initialAddress: address,
      );
      return;
    }

    await _openAddressForm();
  }

  Future<void> _onUseCurrentLocation() async {
    if (_actionInProgress || _fetchingLocation) return;

    setState(() {
      _actionInProgress = true;
      _fetchingLocation = true;
    });

    try {
      final position = await resolveDeliveryLocation(context);
      if (position == null) {
        if (!mounted) return;
        // Show error message when GPS fails
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to get your location. Please check GPS is enabled or use manual search.',
            ),
            duration: Duration(seconds: 4),
            backgroundColor: AppColors.textSecondary,
          ),
        );
        return;
      }
      if (!mounted) return;

      final address = await _mapsService.getAddressFromCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!mounted) return;
      await _openAddressForm(
        latitude: position.latitude,
        longitude: position.longitude,
        initialAddress: address,
      );
    } finally {
      if (mounted) {
        setState(() {
          _actionInProgress = false;
          _fetchingLocation = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final theme = Theme.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final busy = _actionInProgress || _fetchingLocation;

    return PopScope(
      canPop: false,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              MeatvoSpacing.lg,
              MeatvoSpacing.md,
              MeatvoSpacing.lg,
              MeatvoSpacing.lg + bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(MeatvoSpacing.xl),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(MeatvoRadii.xl),
                            border: Border.all(color: AppColors.divider),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.textPrimary.withValues(alpha: 0.05),
                                blurRadius: 28,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              DeliveryLocationIllustration(
                                height: sh(context, 0.22).clamp(140.0, 200.0),
                                backgroundImagePath: 'assets/images/location_bg.png',
                              ),
                              const SizedBox(height: MeatvoSpacing.lg),
                              Text(
                                'Deliver fresh products to your doorstep',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: MeatvoSpacing.sm),
                              Text(
                                'Set your delivery location to browse products available in your area.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_fetchingLocation) ...[
                          const SizedBox(height: MeatvoSpacing.lg),
                          const LocationFetchSkeleton(),
                        ],
                        if (_loadingAddresses) ...[
                          const SizedBox(height: MeatvoSpacing.lg),
                          _SavedAddressesSkeleton(),
                        ] else if (_addresses.isNotEmpty) ...[
                          const SizedBox(height: MeatvoSpacing.xl),
                          Text(
                            'YOUR SAVED LOCATIONS',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: MeatvoSpacing.sm),
                          ..._addresses.map(
                            (address) => Padding(
                              padding: const EdgeInsets.only(bottom: MeatvoSpacing.sm),
                              child: _SavedAddressTile(
                                address: address,
                                onTap: busy ? null : () => _selectSavedAddress(address),
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: MeatvoSpacing.md),
                            child: Row(
                              children: [
                                Expanded(child: Divider(color: AppColors.divider)),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: MeatvoSpacing.sm),
                                  child: Text(
                                    'or choose below',
                                    style: TextStyle(color: AppColors.textSecondary),
                                  ),
                                ),
                                Expanded(child: Divider(color: AppColors.divider)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: MeatvoSpacing.md),
                SizedBox(
                  height: math.max(44.0, R.sh(5.5, context)),
                  child: ElevatedButton.icon(
                    onPressed: busy ? null : _onUseCurrentLocation,
                    icon: busy && _fetchingLocation
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.my_location_rounded, size: 20),
                    label: Text(
                      _fetchingLocation
                          ? 'Detecting location…'
                          : 'Use Current Location',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: R.fontSize(16, context),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(MeatvoRadii.md),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: MeatvoSpacing.sm),
                SizedBox(
                  height: math.max(44.0, R.sh(5.5, context)),
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : _onSearchManually,
                    icon: const Icon(Icons.search_rounded, size: 20),
                    label: Text(
                      'Search Manually',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: R.fontSize(16, context),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(MeatvoRadii.md),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedAddressesSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ShimmerContainer(width: 140, height: 10, borderRadius: 6),
        const SizedBox(height: MeatvoSpacing.sm),
        for (var i = 0; i < 2; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: MeatvoSpacing.sm),
            child: Container(
              padding: const EdgeInsets.all(MeatvoSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(MeatvoRadii.md),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  const ShimmerCircle(diameter: 36),
                  const SizedBox(width: MeatvoSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        ShimmerContainer(width: 80, height: 14, borderRadius: 6),
                        SizedBox(height: 8),
                        ShimmerContainer(width: double.infinity, height: 12, borderRadius: 6),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SavedAddressTile extends StatelessWidget {
  final AddressModel address;
  final VoidCallback? onTap;

  const _SavedAddressTile({required this.address, this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = address.label.displayName;
    final line = address.fullAddress.trim().isEmpty
        ? 'Address details unavailable'
        : address.fullAddress;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(MeatvoRadii.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MeatvoRadii.md),
        child: Container(
          padding: const EdgeInsets.all(MeatvoSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MeatvoRadii.md),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                address.label == AddressLabel.home
                    ? Icons.home_rounded
                    : address.label == AddressLabel.work
                        ? Icons.work_rounded
                        : Icons.location_on_rounded,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: MeatvoSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      line,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


