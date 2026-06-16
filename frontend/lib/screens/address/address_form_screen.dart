import 'package:flutter/material.dart';
import '../../config/backend_resolver.dart';
import '../../models/address_model.dart';
import '../../services/address_service.dart';
import '../../services/delivery_service.dart';
import '../../services/maps_service.dart';
import '../../core/constants/app_constants.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/location/location_flow_helper.dart';
import '../../widgets/location/inline_location_map_panel.dart';
import '../../widgets/location/location_search_sheet.dart';
import '../../widgets/maps/map_picker_widget.dart';

/// Address Form Screen - Add or Edit address
class AddressFormScreen extends StatefulWidget {
  final AddressModel? address; // If provided, edit mode; otherwise, add mode
  final double? initialLatitude; // Initial latitude for new address
  final double? initialLongitude; // Initial longitude for new address
  final Map<String, dynamic>? initialAddress; // Initial address data for new address

  const AddressFormScreen({
    super.key, 
    this.address,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
  });

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  final AddressService _addressService = AddressService();
  final MapsService _mapsService = MapsService();
  final DeliveryService _deliveryService = DeliveryService();
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  late AddressLabel _selectedLabel;
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _landmarkController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  bool _isDefault = false;
  bool _isSaving = false;
  double? _selectedLatitude;
  double? _selectedLongitude;
  bool _isFetchingLocation = false;

  @override
  void initState() {
    super.initState();
    if (widget.address != null) {
      // Edit mode - populate fields
      _selectedLabel = widget.address!.label;
      _addressLine1Controller.text = widget.address!.addressLine1;
      _addressLine2Controller.text = widget.address!.addressLine2 ?? '';
      _landmarkController.text = widget.address!.landmark ?? '';
      _cityController.text = widget.address!.city;
      _stateController.text = widget.address!.state;
      _pincodeController.text = widget.address!.pincode;
      _isDefault = widget.address!.isDefault;
      _selectedLatitude = widget.address!.latitude;
      _selectedLongitude = widget.address!.longitude;
    } else {
      // Add mode - default values
      _selectedLabel = AddressLabel.home;
      
      // If initial coordinates provided, use them
      if (widget.initialLatitude != null && widget.initialLongitude != null) {
        _selectedLatitude = widget.initialLatitude;
        _selectedLongitude = widget.initialLongitude;
        
        // If initial address data provided, populate fields
        if (widget.initialAddress != null) {
          final address = widget.initialAddress!;
          final placeName = address['place_name'] as String? ?? '';
          final addressLine1 = address['address_line1'] as String? ?? '';
          final combinedAddress = placeName.isNotEmpty && addressLine1.isNotEmpty
              ? '$placeName, $addressLine1'
              : placeName.isNotEmpty
                  ? placeName
                  : addressLine1;
          
          _addressLine1Controller.text = combinedAddress.isNotEmpty ? combinedAddress : '';
          _addressLine2Controller.text = address['address_line2'] as String? ?? '';
          _landmarkController.text = address['landmark'] as String? ?? '';
          _cityController.text = address['city'] as String? ?? '';
          _stateController.text = address['state'] as String? ?? '';
          _pincodeController.text = address['pincode'] as String? ?? '';
        } else {
          // Auto-fetch address from coordinates if not provided
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _applyCoordinates(
              latitude: widget.initialLatitude!,
              longitude: widget.initialLongitude!,
            );
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _landmarkController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  String _saveErrorMessage(Object error) {
    final raw = error.toString().replaceFirst('Exception:', '').trim();
    final lower = raw.toLowerCase();
    if (lower.contains('server tak') ||
        lower.contains('meatvo_api_root') ||
        lower.contains('cannot reach') ||
        lower.contains('connection refused') ||
        lower.contains('connection timeout') ||
        lower.contains('connection error') ||
        lower.contains('connection')) {
      return BackendResolver.connectionHelpMessage();
    }
    if (lower.contains('network')) {
      return BackendResolver.connectionHelpMessage();
    }
    if (raw.isEmpty) {
      return 'Could not save address. Please try again.';
    }
    return raw.startsWith('Failed to add address:') ||
            raw.startsWith('Failed to update address:')
        ? raw
        : 'Could not save address. $raw';
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final lat = _selectedLatitude ?? widget.address?.latitude;
    final lng = _selectedLongitude ?? widget.address?.longitude;

    if (lat == null || lng == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please pick your location on the map or use current location before saving.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);

    setState(() {
      _isSaving = true;
    });

    var saved = false;
    try {
      await _deliveryService.ensureDeliveryAvailable(
        latitude: lat,
        longitude: lng,
      );

      final address = AddressModel(
        id: widget.address?.id ?? '',
        userId: widget.address?.userId ?? '',
        label: _selectedLabel,
        addressLine1: _addressLine1Controller.text.trim(),
        addressLine2: _addressLine2Controller.text.trim().isEmpty
            ? null
            : _addressLine2Controller.text.trim(),
        landmark: _landmarkController.text.trim().isEmpty
            ? null
            : _landmarkController.text.trim(),
        city: _cityController.text.trim().isEmpty
            ? 'Bokaro'
            : _cityController.text.trim(),
        state: _stateController.text.trim().isEmpty
            ? 'Jharkhand'
            : _stateController.text.trim(),
        pincode: _pincodeController.text.trim(),
        latitude: lat,
        longitude: lng,
        isDefault: _isDefault,
        createdAt: widget.address?.createdAt,
        updatedAt: widget.address?.updatedAt,
      );

      if (widget.address != null) {
        await _addressService.updateAddress(address);
      } else {
        await _addressService.addAddress(address);
      }

      saved = true;
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DeliveryException catch (e) {
      if (!context.mounted) return;
      messenger?.showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger?.showSnackBar(
        SnackBar(
          content: Text(_saveErrorMessage(e)),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted && !saved) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _openLocationSearch() async {
    final result = await LocationSearchSheet.show(context);
    if (result == null || !mounted) return;

    final lat = (result['latitude'] as num?)?.toDouble();
    final lng = (result['longitude'] as num?)?.toDouble();
    if (lat != null && lng != null) {
      setState(() {
        _selectedLatitude = lat;
        _selectedLongitude = lng;
      });
      await _applyCoordinates(latitude: lat, longitude: lng);
      return;
    }

    final formatted = result['formatted_address'] as String?;
    if (formatted != null && formatted.isNotEmpty) {
      _addressLine1Controller.text = formatted;
    }
  }

  void _applyResolvedAddress(Map<String, dynamic>? address) {
    if (address == null) return;
    _applyAddressFields(address);
  }

  void _applyAddressFields(Map<String, dynamic> address) {
    final placeName = address['place_name'] as String? ?? '';
    final addressLine1 = address['address_line1'] as String? ?? '';
    final combinedAddress = placeName.isNotEmpty && addressLine1.isNotEmpty
        ? '$placeName, $addressLine1'
        : placeName.isNotEmpty
            ? placeName
            : addressLine1;

    setState(() {
      if (combinedAddress.isNotEmpty) {
        _addressLine1Controller.text = combinedAddress;
      }
      _addressLine2Controller.text =
          address['address_line2'] as String? ?? _addressLine2Controller.text;
      _landmarkController.text =
          address['landmark'] as String? ?? _landmarkController.text;
      _cityController.text = address['city'] as String? ?? _cityController.text;
      _stateController.text =
          address['state'] as String? ?? _stateController.text;
      _pincodeController.text =
          address['pincode'] as String? ?? _pincodeController.text;
    });
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerWidget(
          initialLatitude: widget.address?.latitude,
          initialLongitude: widget.address?.longitude,
          onLocationSelected: (latitude, longitude, address) {
            Navigator.pop(context, {
              'latitude': latitude,
              'longitude': longitude,
              'address': address,
            });
          },
        ),
      ),
    );

    if (result != null && mounted) {
      final latitude = result['latitude'] as double?;
      final longitude = result['longitude'] as double?;
      final address = result['address'] as Map<String, dynamic>?;

      if (latitude != null && longitude != null) {
        if (address != null) {
          setState(() {
            _selectedLatitude = latitude;
            _selectedLongitude = longitude;
            // Combine place name with address line 1 if place name exists
            final placeName = address['place_name'] as String? ?? '';
            final addressLine1 = address['address_line1'] as String? ?? '';
            final combinedAddress = placeName.isNotEmpty && addressLine1.isNotEmpty
                ? '$placeName, $addressLine1'
                : placeName.isNotEmpty
                    ? placeName
                    : addressLine1;
            _addressLine1Controller.text = combinedAddress;
            _addressLine2Controller.text =
                address['address_line2'] as String? ?? '';
            _landmarkController.text = address['landmark'] as String? ?? '';
            _cityController.text = address['city'] as String? ?? '';
            _stateController.text = address['state'] as String? ?? '';
            _pincodeController.text = address['pincode'] as String? ?? '';
          });
        } else {
          await _applyCoordinates(latitude: latitude, longitude: longitude);
        }
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isFetchingLocation = true);

    try {
      final position = await resolveDeliveryLocation(context);
      if (position == null || !mounted) return;

      await _applyCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location detected successfully'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  Future<void> _applyCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    setState(() {
      _selectedLatitude = latitude;
      _selectedLongitude = longitude;
    });

    final address = await _mapsService.getAddressFromCoordinates(
      latitude: latitude,
      longitude: longitude,
    );

    if (address != null && mounted) {
      setState(() {
        // Combine place name with address line 1 if place name exists
        final placeName = address['place_name'] as String? ?? '';
        final addressLine1 = address['address_line1'] as String? ?? '';
        final combinedAddress = placeName.isNotEmpty && addressLine1.isNotEmpty
            ? '$placeName, $addressLine1'
            : placeName.isNotEmpty
                ? placeName
                : addressLine1;
        
        _addressLine1Controller.text = combinedAddress.isNotEmpty
            ? combinedAddress
            : _addressLine1Controller.text;
        _addressLine2Controller.text =
            address['address_line2'] as String? ?? _addressLine2Controller.text;
        _landmarkController.text =
            address['landmark'] as String? ?? _landmarkController.text;
        _cityController.text =
            address['city'] as String? ?? _cityController.text;
        _stateController.text =
            address['state'] as String? ?? _stateController.text;
        _pincodeController.text =
            address['pincode'] as String? ?? _pincodeController.text;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.address != null ? 'Edit Address' : 'Add Address',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _isFetchingLocation ? null : _useCurrentLocation,
            icon: _isFetchingLocation
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location, color: AppColors.primary),
            tooltip: 'Use my location',
          ),
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.textPrimary),
            onPressed: _openLocationSearch,
            tooltip: 'Search location',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = isCompactScreenHeight(context);
            return Column(
          children: [
            // Map Section at Top
            Expanded(
              flex: compact ? 1 : 2,
              child: Column(
                children: [
                  Expanded(
                    child: InlineLocationMapPanel(
                      latitude: _selectedLatitude,
                      longitude: _selectedLongitude,
                      onLatitudeChanged: (lat) =>
                          setState(() => _selectedLatitude = lat),
                      onLongitudeChanged: (lng) =>
                          setState(() => _selectedLongitude = lng),
                      onAddressResolved: _applyResolvedAddress,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _openMapPicker,
                    icon: const Icon(Icons.fullscreen, size: 18),
                    label: const Text('Open full screen map'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            // Address Details Form
            Expanded(
              flex: compact ? 2 : 3,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    16 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Enter Address Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // House/Flat No.
                      TextFormField(
                        controller: _addressLine1Controller,
                        decoration: InputDecoration(
                          labelText: 'House/Flat No.',
                          hintText: 'Enter your house or flat number',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter house/flat number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Street
                      TextFormField(
                        controller: _addressLine2Controller,
                        decoration: InputDecoration(
                          labelText: 'Street',
                          hintText: 'Enter street name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Locality
                      TextFormField(
                        controller: _cityController,
                        decoration: InputDecoration(
                          labelText: 'Locality',
                          hintText: 'Enter locality',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter locality';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Landmark (Optional)
                      TextFormField(
                        controller: _landmarkController,
                        decoration: InputDecoration(
                          labelText: 'Landmark (Optional)',
                          hintText: 'E.g. near the city park',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // State and Pincode in same row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _stateController,
                              decoration: InputDecoration(
                                labelText: 'State',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Required';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _pincodeController,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              decoration: InputDecoration(
                                labelText: 'Pincode',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Required';
                                }
                                if (value.trim().length != 6) {
                                  return '6 digits';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      _buildLabelSection(),
                      const SizedBox(height: 32),
                      
                      // Save Address Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveAddress,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Save Address',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLabelSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Address Type',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildLabelChip(AddressLabel.home, Icons.home)),
            const SizedBox(width: 12),
            Expanded(child: _buildLabelChip(AddressLabel.work, Icons.work)),
            const SizedBox(width: 12),
            Expanded(
              child: _buildLabelChip(AddressLabel.other, Icons.location_on),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLabelChip(AddressLabel label, IconData icon) {
    final isSelected = _selectedLabel == label;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedLabel = label;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.white,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.surface,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label.displayName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
