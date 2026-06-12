import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../design_system/tokens/meatvo_radii.dart';
import '../../design_system/tokens/meatvo_spacing.dart';
import '../../models/address_model.dart';
import '../../screens/address/address_form_screen.dart';
import '../../services/address_service.dart';
import '../../services/maps_service.dart';
import '../../viewmodels/home_provider.dart';
import 'location_flow_helper.dart';
import 'location_search_sheet.dart';

/// Licious-style location onboarding bottom sheet — shown when no default address.
class LocationOnboardingSheet extends ConsumerStatefulWidget {
  final String? userName;

  const LocationOnboardingSheet({super.key, this.userName});

  static Future<void> show(
    BuildContext context, {
    String? userName,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PopScope(
        canPop: false,
        child: LocationOnboardingSheet(userName: userName),
      ),
    );
  }

  @override
  ConsumerState<LocationOnboardingSheet> createState() =>
      _LocationOnboardingSheetState();
}

class _LocationOnboardingSheetState extends ConsumerState<LocationOnboardingSheet> {
  final AddressService _addressService = AddressService();
  final MapsService _mapsService = MapsService();

  List<AddressModel> _addresses = [];
  bool _loadingAddresses = true;
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
    if (mounted) Navigator.of(context).pop();
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
          SnackBar(content: Text('Failed to set address: $e')),
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
    final saved = await Navigator.of(context, rootNavigator: true).push<bool>(
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

  Future<void> _onSearchLocation() async {
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

  Future<void> _onUseMyLocation() async {
    setState(() => _actionInProgress = true);
    try {
      final position = await resolveDeliveryLocation(context);
      if (position == null || !mounted) return;

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
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  String get _greetingName {
    final name = widget.userName?.trim();
    if (name == null || name.isEmpty) return 'there';
    return name.split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.55;

    return Container(
      height: sheetHeight + bottomInset,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          MeatvoSpacing.md,
          MeatvoSpacing.md,
          MeatvoSpacing.md,
          MeatvoSpacing.md + bottomInset,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: MeatvoSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back, $_greetingName',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: MeatvoSpacing.xs),
                      Text(
                        'Enable location access to show available products for your area.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: MeatvoSpacing.sm),
                Icon(
                  Icons.location_on_rounded,
                  size: 48,
                  color: AppColors.primary.withValues(alpha: 0.85),
                ),
              ],
            ),
            const SizedBox(height: MeatvoSpacing.lg),
            if (_loadingAddresses)
              const Center(child: CircularProgressIndicator(strokeWidth: 2))
            else if (_addresses.isNotEmpty) ...[
              Text(
                'YOUR SAVED LOCATION',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
              ),
              const SizedBox(height: MeatvoSpacing.sm),
              Expanded(
                child: ListView.separated(
                  itemCount: _addresses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: MeatvoSpacing.sm),
                  itemBuilder: (context, index) {
                    final address = _addresses[index];
                    return _SavedAddressTile(
                      address: address,
                      onTap: _actionInProgress
                          ? null
                          : () => _selectSavedAddress(address),
                    );
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: MeatvoSpacing.md),
                child: Row(
                  children: [
                    Expanded(child: Divider(color: AppColors.divider)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: MeatvoSpacing.sm),
                      child: Text('or', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                    Expanded(child: Divider(color: AppColors.divider)),
                  ],
                ),
              ),
            ]             else if (!_loadingAddresses)
              const Spacer(),
            _ActionButtons(
              loading: _actionInProgress,
              onSearch: _onSearchLocation,
              onUseMyLocation: _onUseMyLocation,
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedAddressTile extends StatelessWidget {
  final AddressModel address;
  final VoidCallback? onTap;

  const _SavedAddressTile({required this.address, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(MeatvoRadii.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MeatvoRadii.md),
        child: Padding(
          padding: const EdgeInsets.all(MeatvoSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                address.label == AddressLabel.home
                    ? Icons.home_rounded
                    : address.label == AddressLabel.work
                        ? Icons.work_rounded
                        : Icons.location_on_rounded,
                color: AppColors.textPrimary,
                size: 22,
              ),
              const SizedBox(width: MeatvoSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      address.label.displayName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      address.fullAddress,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final bool loading;
  final VoidCallback onSearch;
  final VoidCallback onUseMyLocation;

  const _ActionButtons({
    required this.loading,
    required this.onSearch,
    required this.onUseMyLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: loading ? null : onSearch,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MeatvoRadii.md),
              ),
            ),
            child: const Text(
              'Search Manually',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: MeatvoSpacing.sm),
        Expanded(
          child: ElevatedButton(
            onPressed: loading ? null : onUseMyLocation,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MeatvoRadii.md),
              ),
            ),
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Use Current Location',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }
}


