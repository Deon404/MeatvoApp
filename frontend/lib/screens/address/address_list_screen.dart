import 'package:flutter/material.dart';
import '../../models/address_model.dart';
import '../../models/user_model.dart';
import '../../services/address_service.dart';
import '../../services/auth_service.dart';
import '../../core/constants/app_constants.dart';
import '../../utils/address_display_util.dart';
import 'address_details_screen.dart';
import 'map_pin_screen.dart';

/// Address List Screen - Manage all saved addresses
class AddressListScreen extends StatefulWidget {
  const AddressListScreen({super.key});

  @override
  State<AddressListScreen> createState() => _AddressListScreenState();
}

class _AddressListScreenState extends State<AddressListScreen> {
  final AddressService _addressService = AddressService();
  final AuthService _authService = AuthService();
  List<AddressModel> _addresses = [];
  UserModel? _userProfile;
  bool _isLoading = true;
  String? _errorMessage;
  String? _selectingAddressId;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final userProfile = await _authService.getCurrentUserProfile();
      if (mounted) {
        setState(() {
          _userProfile = userProfile;
        });
      }
    } catch (e) {
      // Silently fail - user profile is optional for address display
      debugPrint('Failed to load user profile: $e');
    }
  }

  Future<void> _loadAddresses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final addresses = await _addressService.getUserAddresses();
      if (mounted) {
        setState(() {
          _addresses = addresses;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectAddress(AddressModel address) async {
    if (address.isDefault || _selectingAddressId != null) return;

    final messenger = ScaffoldMessenger.of(context);
    final previousAddresses = List<AddressModel>.from(_addresses);

    setState(() {
      _selectingAddressId = address.id;
      _addresses = _addresses
          .map(
            (a) => a.copyWith(isDefault: a.id == address.id),
          )
          .toList();
    });

    try {
      await _addressService.setDefaultAddress(address.id);
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Default address updated'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _addresses = previousAddresses);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to update address: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _selectingAddressId = null);
      }
    }
  }

  Future<void> _deleteAddress(AddressModel address) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Address'),
        content: Text('Are you sure you want to delete this ${address.label.displayName} address?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _addressService.deleteAddress(address.id);
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Address deleted successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        await _loadAddresses();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to delete address: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  Future<void> _navigateToAddAddress() async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await Navigator.push<AddressModel>(
      context,
      MaterialPageRoute(
        builder: (_) => const MapPinScreen(),
      ),
    );

    if (!mounted) return;
    if (result == null) return;

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Address saved successfully'),
        backgroundColor: AppColors.success,
      ),
    );
    await _loadAddresses();
  }

  Future<void> _navigateToEditAddress(AddressModel address) async {
    final messenger = ScaffoldMessenger.of(context);
    final lat = address.latitude;
    final lng = address.longitude;
    if (lat == null || lng == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('This address is missing map coordinates'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final result = await Navigator.push<AddressModel>(
      context,
      MaterialPageRoute(
        builder: (_) => AddressDetailsScreen(
          latitude: lat,
          longitude: lng,
          geocodedAddress: geocodedMapFromAddressModel(address),
          existingAddress: address,
        ),
      ),
    );

    if (!mounted) return;
    if (result == null) return;

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Address updated successfully'),
        backgroundColor: AppColors.success,
      ),
    );
    await _loadAddresses();
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
        title: const Text(
          'My Addresses',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
          : _errorMessage != null
              ? _buildErrorState()
              : _addresses.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadAddresses,
                      color: AppColors.primary,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          ..._addresses.map((address) => _buildAddressCard(address)),
                          const SizedBox(height: 80), // Space for FAB
                        ],
                      ),
                    ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton.icon(
            onPressed: _navigateToAddAddress,
            icon: const Icon(Icons.add),
            label: const Text('Add New Address'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAddresses,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off,
              size: 80,
              color: AppColors.surface,
            ),
            const SizedBox(height: 24),
            const Text(
              'No addresses saved',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your first delivery address to get started!',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _navigateToAddAddress,
              icon: const Icon(Icons.add),
              label: const Text('Add Address'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressCard(AddressModel address) {
    final isSelecting = _selectingAddressId == address.id;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: address.isDefault || _selectingAddressId != null
            ? null
            : () => _selectAddress(address),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: address.isDefault
                  ? AppColors.primary
                  : AppColors.divider,
              width: address.isDefault ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
        children: [
          // Red overlay for default address
          if (address.isDefault)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    address.label == AddressLabel.home
                        ? Icons.home
                        : address.label == AddressLabel.work
                            ? Icons.work
                            : Icons.location_on,
                    color: AppColors.textPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                // Address Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            address.label.displayName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (address.isDefault) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Default',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        address.displayAddress,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _buildContactInfo(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Edit and Delete Icons
                Column(
                  children: [
                    if (isSelecting)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    else ...[
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        color: AppColors.textPrimary,
                        onPressed: () => _navigateToEditAddress(address),
                        tooltip: 'Edit',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: AppColors.textPrimary,
                        onPressed: () => _deleteAddress(address),
                        tooltip: 'Delete',
                      ),
                    ],
                  ],
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

  String _buildContactInfo() {
    final name = _userProfile?.name ?? 'User';
    final phone = _userProfile?.phoneNumber ?? '';
    
    if (phone.isNotEmpty) {
      return '$name, $phone';
    }
    return name;
  }
}



