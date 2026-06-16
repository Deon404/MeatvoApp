import 'package:flutter/material.dart';
import '../../models/address_model.dart';
import '../../core/constants/app_constants.dart';
import '../../services/location_service.dart';

/// Address Card Widget - Displays current delivery address (Swiggy/Instamart style)
/// Shows current location option if available
class AddressCard extends StatefulWidget {
  final AddressModel? address;
  final VoidCallback? onEdit;
  final VoidCallback? onTap;
  final Function(double latitude, double longitude, Map<String, dynamic>? address)? onUseCurrentLocation;

  const AddressCard({
    super.key,
    this.address,
    this.onEdit,
    this.onTap,
    this.onUseCurrentLocation,
  });

  @override
  State<AddressCard> createState() => _AddressCardState();
}

class _AddressCardState extends State<AddressCard> {
  final LocationService _locationService = LocationService();
  Map<String, dynamic>? _currentLocation;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    final location = await _locationService.getLastLocation();
    if (mounted) {
      setState(() {
        _currentLocation = location;
      });
    }
  }

  Future<void> _handleUseCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    
    try {
      final location = await _locationService.refreshLocation();
      if (location != null && widget.onUseCurrentLocation != null) {
        // Get address from location data if available
        final address = location['address'] as Map<String, dynamic>?;
        
        widget.onUseCurrentLocation!(
          location['latitude'] as double,
          location['longitude'] as double,
          address, // Pass address if available, otherwise will be fetched in AddressFormScreen
        );
      } else if (location == null && widget.onUseCurrentLocation != null) {
        // Location is null - show error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not get current location. Please try again or select location on map.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not get current location: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Card(
        margin: const EdgeInsets.all(16),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.divider, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AddressCardBody(
              address: widget.address,
              onTap: widget.onTap,
              onEdit: widget.onEdit,
            ),
            if (widget.address == null && _currentLocation != null)
              _UseCurrentLocationButton(
                isLoading: _isLoadingLocation,
                onPressed: _handleUseCurrentLocation,
              ),
          ],
        ),
      ),
    );
  }
}

/// Static address row — parent scroll pe rebuild isolate ho.
class _AddressCardBody extends StatelessWidget {
  const _AddressCardBody({
    required this.address,
    this.onTap,
    this.onEdit,
  });

  final AddressModel? address;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.location_on,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        address?.label.displayName ?? 'Select Address',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (address?.isDefault == true) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Default',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address?.shortAddress ?? 'Tap to add delivery address',
                    style: TextStyle(
                      fontSize: 13,
                      color: address != null
                          ? AppColors.textSecondary
                          : AppColors.primary.withValues(alpha: 0.8),
                      fontWeight:
                          address == null ? FontWeight.w500 : FontWeight.normal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.edit_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              onPressed: onEdit,
              tooltip: 'Edit Address',
            ),
          ],
        ),
      ),
    );
  }
}

class _UseCurrentLocationButton extends StatelessWidget {
  const _UseCurrentLocationButton({
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.my_location, size: 18),
        label: Text(
          isLoading ? 'Getting location...' : 'Use Current Location',
          style: const TextStyle(fontSize: 13),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

