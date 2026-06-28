import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../models/address_model.dart';
import '../../screens/address/address_details_screen.dart';
import '../../screens/address/search_locality_screen.dart';
import '../../services/address_service.dart';
import '../../utils/address_display_util.dart';
import 'delivery_location_coordinator.dart';

/// Zappfresh-style select delivery address bottom sheet.
class DeliveryLocationSheet extends ConsumerStatefulWidget {
  const DeliveryLocationSheet({
    super.key,
    this.mode = DeliveryLocationFlowMode.homeGate,
    this.selectedAddressId,
  });

  final DeliveryLocationFlowMode mode;
  final String? selectedAddressId;

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DeliveryLocationSheet(),
    );
  }

  /// Checkout / profile: returns the address the user picked or added.
  static Future<AddressModel?> showPicker(
    BuildContext context, {
    String? selectedAddressId,
  }) {
    return showModalBottomSheet<AddressModel>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DeliveryLocationSheet(
        mode: DeliveryLocationFlowMode.picker,
        selectedAddressId: selectedAddressId,
      ),
    );
  }

  @override
  ConsumerState<DeliveryLocationSheet> createState() =>
      _DeliveryLocationSheetState();
}

class _DeliveryLocationSheetState extends ConsumerState<DeliveryLocationSheet> {
  late final DeliveryLocationCoordinator _coordinator;

  List<AddressModel> _addresses = [];
  bool _loading = true;
  bool _busy = false;

  bool get _isPicker => widget.mode == DeliveryLocationFlowMode.picker;

  @override
  void initState() {
    super.initState();
    _coordinator = DeliveryLocationCoordinator(
      contextOf: () => context,
      ref: ref,
      mode: widget.mode,
      useRootNavigator: true,
      navigateHomeOnComplete: !_isPicker,
    );
    _load();
  }

  Future<void> _openMapPinFlow({
    double? latitude,
    double? longitude,
    Map<String, dynamic>? geocodedAddress,
  }) async {
    if (_isPicker) {
      await _run(() => _coordinator.openMapPin(
            latitude: latitude,
            longitude: longitude,
            geocodedAddress: geocodedAddress,
          ));
      return;
    }
    await _runVoid(() => _coordinator.openMapPin(
          latitude: latitude,
          longitude: longitude,
          geocodedAddress: geocodedAddress,
        ));
  }

  void _onAddNewAddressTap() {
    if (_busy) return;
    _openMapPinFlow();
  }

  Future<void> _load() async {
    try {
      final list = await _coordinator.loadSavedAddresses();
      if (mounted) {
        setState(() {
          _addresses = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<AddressModel?> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picked = await action();
      if (!mounted || picked == null) return;
      if (_isPicker) {
        Navigator.of(context).pop(picked);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runVoid(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _popWithAddress(AddressModel address) {
    if (!mounted) return;
    if (_isPicker) {
      Navigator.of(context).pop(address);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _openSearch() async {
    if (_busy) return;
    final place = await Navigator.of(context, rootNavigator: true)
        .push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const SearchLocalityScreen()),
    );
    if (place == null || !mounted) return;

    final lat = (place['latitude'] as num?)?.toDouble();
    final lng = (place['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return;

    await _openMapPinFlow(
      latitude: lat,
      longitude: lng,
      geocodedAddress: place,
    );
  }

  Future<void> _editAddress(AddressModel address) async {
    final lat = address.latitude;
    final lng = address.longitude;
    if (lat == null || lng == null) return;

    final saved = await Navigator.of(context, rootNavigator: true)
        .push<AddressModel>(
      MaterialPageRoute(
        builder: (_) => AddressDetailsScreen(
          latitude: lat,
          longitude: lng,
          geocodedAddress: geocodedMapFromAddressModel(address),
          existingAddress: address,
        ),
      ),
    );
    if (saved != null) {
      await _load();
      if (_isPicker) _popWithAddress(saved);
    }
  }

  Future<void> _deleteAddress(AddressModel address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete address'),
        content: Text('Remove ${address.label.displayName} address?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await AddressService().deleteAddress(address.id);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete address')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.85;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              'Select delivery address',
              style: AppTextStyles.h2,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: InkWell(
              onTap: _busy ? null : _openSearch,
              borderRadius: BorderRadius.circular(AppRadius.button),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.greyLight,
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: AppColors.textMuted),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Search a new address',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _SheetActionButton(
              icon: Icons.my_location_rounded,
              label: 'Use your current location',
              filled: true,
              loading: _busy,
              onTap: _busy
                  ? null
                  : () {
                      if (_isPicker) {
                        _run(() => _coordinator.useCurrentLocation());
                      } else {
                        _runVoid(() => _coordinator.useCurrentLocation());
                      }
                    },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _SheetActionButton(
              icon: Icons.add_rounded,
              label: 'Add new address',
              filled: false,
              loading: _busy,
              onTap: _busy ? null : _onAddNewAddressTap,
            ),
          ),
          if (_loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_addresses.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Text(
                'Your saved addresses',
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md + bottom,
                ),
                itemCount: _addresses.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final address = _addresses[index];
                  final isSelected = widget.selectedAddressId != null &&
                      widget.selectedAddressId == address.id;
                  return _SavedAddressCard(
                    address: address,
                    isSelected: isSelected,
                    onSelect: _busy
                        ? null
                        : () {
                            if (_isPicker) {
                              _run(() =>
                                  _coordinator.selectSavedAddress(address));
                            } else {
                              _runVoid(() =>
                                  _coordinator.selectSavedAddress(address));
                            }
                          },
                    onEdit: () => _editAddress(address),
                    onDelete: () => _deleteAddress(address),
                  );
                },
              ),
            ),
          ] else
            const Spacer(),
        ],
      ),
    );
  }
}

class _SheetActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final bool loading;
  final VoidCallback? onTap;

  const _SheetActionButton({
    required this.icon,
    required this.label,
    required this.filled,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? AppColors.primary : AppColors.primaryLight,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 14,
          ),
          child: Row(
            children: [
              Icon(icon, color: filled ? Colors.white : AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: filled ? Colors.white : AppColors.primary,
                  ),
                ),
              ),
              if (loading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: filled ? Colors.white : AppColors.primary,
                  ),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: filled ? Colors.white : AppColors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedAddressCard extends StatelessWidget {
  final AddressModel address;
  final bool isSelected;
  final VoidCallback? onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SavedAddressCard({
    required this.address,
    this.isSelected = false,
    this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppColors.primaryLight.withValues(alpha: 0.35)
          : AppColors.greyLight,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: isSelected
                ? Border.all(color: AppColors.primary, width: 1.5)
                : null,
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      address.label == AddressLabel.home
                          ? Icons.home_rounded
                          : address.label == AddressLabel.work
                              ? Icons.work_rounded
                              : Icons.location_on_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          address.label.displayName,
                          style: AppTextStyles.h3.copyWith(fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          address.fullAddress,
                          style: AppTextStyles.caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primary,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  _IconSquare(icon: Icons.edit_outlined, onTap: onEdit),
                  const SizedBox(width: AppSpacing.sm),
                  _IconSquare(icon: Icons.delete_outline, onTap: onDelete),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconSquare extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconSquare({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
