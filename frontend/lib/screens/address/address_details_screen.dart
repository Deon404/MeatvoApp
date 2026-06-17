import 'package:flutter/material.dart';

import '../../config/backend_resolver.dart';
import '../../core/constants/app_constants.dart';
import '../../models/address_model.dart';
import '../../services/address_service.dart';
import '../../services/delivery_service.dart';
import '../../services/maps_service.dart';
import '../../utils/address_display_util.dart';
import 'map_pin_screen.dart';

/// Zappfresh-style minimal address details step.
class AddressDetailsScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final Map<String, dynamic> geocodedAddress;
  final AddressModel? existingAddress;

  const AddressDetailsScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.geocodedAddress,
    this.existingAddress,
  });

  @override
  State<AddressDetailsScreen> createState() => _AddressDetailsScreenState();
}

class _AddressDetailsScreenState extends State<AddressDetailsScreen> {
  final _houseController = TextEditingController();
  final _floorController = TextEditingController();
  final _towerController = TextEditingController();
  final _landmarkController = TextEditingController();
  final AddressService _addressService = AddressService();
  final DeliveryService _deliveryService = DeliveryService();

  late GeocodedAddressFields _fields;
  late AddressLabel _label;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fields = GeocodedAddressFields.fromMap(widget.geocodedAddress);
    _label = widget.existingAddress?.label ?? AddressLabel.home;
    if (widget.existingAddress != null) {
      _houseController.text = widget.existingAddress!.addressLine1;
      _landmarkController.text = widget.existingAddress!.landmark ?? '';
    }
  }

  @override
  void dispose() {
    _houseController.dispose();
    _floorController.dispose();
    _towerController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  Future<void> _changeLocation() async {
    final saved = await Navigator.of(context).push<AddressModel>(
      MaterialPageRoute(
        builder: (_) => MapPinScreen(
          initialLatitude: widget.latitude,
          initialLongitude: widget.longitude,
          initialAddress: widget.geocodedAddress,
        ),
      ),
    );
    if (saved != null && mounted) {
      Navigator.of(context).pop(saved);
    }
  }

  Future<void> _save() async {
    final house = _houseController.text.trim();
    if (house.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter house number')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _deliveryService.ensureDeliveryAvailable(
        latitude: widget.latitude,
        longitude: widget.longitude,
      );

      final floor = _floorController.text.trim();
      final tower = _towerController.text.trim();
      final landmarkParts = [
        if (floor.isNotEmpty) floor,
        if (tower.isNotEmpty) tower,
        if (_landmarkController.text.trim().isNotEmpty)
          _landmarkController.text.trim(),
      ];

      final line1 = ensureAddressLine1MinLength(
        flatOrPrimary: house,
        street: _fields.street.isEmpty ? null : _fields.street,
        locality: _fields.locality.isEmpty ? null : _fields.locality,
      );
      final line2 = secondaryAddressLineIfDistinct(
        line1,
        _fields.street.isEmpty ? null : _fields.street,
      );

      final model = AddressModel(
        id: widget.existingAddress?.id ?? '',
        userId: widget.existingAddress?.userId ?? '',
        label: _label,
        addressLine1: line1,
        addressLine2: line2,
        landmark: landmarkParts.isEmpty ? null : landmarkParts.join(', '),
        city: _fields.locality.isEmpty ? 'Bokaro' : _fields.locality,
        state: _fields.state.isEmpty ? 'Jharkhand' : _fields.state,
        pincode: _fields.pincode,
        latitude: widget.latitude,
        longitude: widget.longitude,
        isDefault: true,
      );

      final saved = widget.existingAddress != null
          ? await _addressService.updateAddress(model)
          : await _addressService.addAddress(model);

      if (mounted) Navigator.of(context).pop(saved);
    } on DeliveryException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_saveErrorMessage(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _saveErrorMessage(Object error) {
    final raw = error.toString().replaceFirst('Exception:', '').trim();
    if (BackendResolver.isConnectionError(raw)) {
      return BackendResolver.connectionUserMessage();
    }
    return raw.isEmpty ? 'Could not save address.' : raw;
  }

  @override
  Widget build(BuildContext context) {
    final title = _fields.locality.isNotEmpty
        ? _fields.locality
        : (_fields.street.isNotEmpty ? _fields.street.split(',').first : 'Location');

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Add new address'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LocationPreviewCard(
                    latitude: widget.latitude,
                    longitude: widget.longitude,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: AppTextStyles.h2.copyWith(fontSize: 17),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _fields.street.isNotEmpty
                                  ? _fields.street
                                  : _fields.areaDisplayLine,
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      OutlinedButton(
                        onPressed: _changeLocation,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.textPrimary),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('CHANGE'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Select address type',
                    style: AppTextStyles.h3.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      _LabelChip(
                        label: 'Home',
                        selected: _label == AddressLabel.home,
                        onTap: () => setState(() => _label = AddressLabel.home),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _LabelChip(
                        label: 'Work',
                        selected: _label == AddressLabel.work,
                        onTap: () => setState(() => _label = AddressLabel.work),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _LabelChip(
                        label: 'Other',
                        selected: _label == AddressLabel.other,
                        onTap: () => setState(() => _label = AddressLabel.other),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Enter more details',
                    style: AppTextStyles.h3.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _FilledField(
                    controller: _houseController,
                    hint: 'House number',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _FilledField(
                    controller: _floorController,
                    hint: 'Floor',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _FilledField(
                    controller: _towerController,
                    hint: 'Tower / Block (optional)',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _FilledField(
                    controller: _landmarkController,
                    hint: 'Nearby landmark (optional)',
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md + MediaQuery.paddingOf(context).bottom,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save address',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationPreviewCard extends StatelessWidget {
  final double latitude;
  final double longitude;

  const _LocationPreviewCard({
    required this.latitude,
    required this.longitude,
  });

  @override
  Widget build(BuildContext context) {
    final mapUrl = MapsService().getLocationPreviewMapUrl(
      latitude: latitude,
      longitude: longitude,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: SizedBox(
        height: 120,
        width: double.infinity,
        child: mapUrl.isEmpty
            ? _MapPreviewFallback()
            : Image.network(
                mapUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const _MapPreviewFallback(showLoader: true);
                },
                errorBuilder: (_, __, ___) => const _MapPreviewFallback(),
              ),
      ),
    );
  }
}

class _MapPreviewFallback extends StatelessWidget {
  const _MapPreviewFallback({this.showLoader = false});

  final bool showLoader;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.greyLight,
      alignment: Alignment.center,
      child: showLoader
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              Icons.map_outlined,
              size: 48,
              color: AppColors.textMuted.withValues(alpha: 0.4),
            ),
    );
  }
}

class _LabelChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LabelChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: Ink(
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: Border.all(
              color: AppColors.primary,
              width: selected ? 0 : 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilledField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const _FilledField({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.greyLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
      ),
    );
  }
}
