import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/earnings_data.dart';
import '../../services/auth_service.dart';
import '../../services/rider_location_service.dart';
import '../../services/rider_service.dart';
import '../../services/socket_service.dart';
import '../../providers/rider_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../utils/responsive_helper.dart';
import '../auth/phone_screen.dart';
import 'delivery_map_screen.dart';
import 'rider_analytics_screen.dart';

/// Rider Profile Screen - Rider profile and settings
class RiderProfileScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;

  const RiderProfileScreen({
    super.key,
    this.onBack,
  });

  @override
  ConsumerState<RiderProfileScreen> createState() =>
      _RiderProfileScreenState();
}

class _RiderProfileScreenState extends ConsumerState<RiderProfileScreen> {
  final RiderService _riderService = RiderService();
  final RiderLocationService _locationService = RiderLocationService();
  late final RiderAssignmentAlerts _assignmentAlerts;
  Map<String, dynamic>? _riderProfile;
  EarningsData? _earnings;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _assignmentAlerts = ref.read(riderAssignmentAlertsProvider.notifier);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _riderService.getRiderProfile();
      final earnings = await _riderService.getRiderEarnings();
      if (mounted) {
        setState(() {
          _riderProfile = profile;
          _earnings = earnings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load profile: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Profile'),
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProfile,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              )
            : _errorMessage != null
                ? _buildErrorState()
                : _riderProfile == null
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadProfile,
                        color: AppColors.primary,
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(R.sw(4, context)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildProfileHeader(),
                              SizedBox(height: R.sh(2, context)),
                              _buildPerformanceMetrics(),
                              SizedBox(height: R.sh(2, context)),
                              _buildVehicleDetails(),
                              SizedBox(height: R.sh(2, context)),
                              _buildEarningsSummary(),
                              SizedBox(height: R.sh(2, context)),
                              _buildQuickLinks(),
                              SizedBox(height: R.sh(2, context)),
                              _buildKYCStatus(),
                              SizedBox(height: R.sh(3, context)),
                              _buildLogoutButton(),
                              SizedBox(height: R.sh(2, context)),
                            ],
                          ),
                        ),
                      ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(R.sw(6, context)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            SizedBox(height: R.sh(2, context)),
            Text(
              'Error Loading Profile',
              style: TextStyle(
                fontSize: R.fontSize(18, context),
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: R.sh(1, context)),
            Text(
              _errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: R.fontSize(14, context),
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: R.sh(3, context)),
            ElevatedButton.icon(
              onPressed: _loadProfile,
              icon: const Icon(Icons.refresh),
              label: Text(
                'Retry',
                style: TextStyle(fontSize: R.fontSize(14, context)),
              ),
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
    return const Center(
      child: Text('Profile not found'),
    );
  }

  Widget _buildProfileHeader() {
    final user = _riderProfile?['user'] as Map<String, dynamic>?;
    final rawName = _riderProfile?['name']?.toString().trim() ??
        user?['name']?.toString().trim() ??
        '';
    final userPhone =
        _riderProfile?['phone']?.toString().trim() ??
        user?['phone']?.toString().trim() ??
        '';
    final userName = rawName.isNotEmpty
        ? rawName
        : (userPhone.isNotEmpty ? userPhone : 'Rider');
    final userEmail = user?['email'] as String? ?? '';
    final profileImage = user?['profile_image'] as String?;
    final status = _riderProfile?['status'] as String? ??
        (_riderProfile?['online'] == true ? 'available' : 'offline');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.divider, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(R.sw(3.5, context)),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.surface,
              backgroundImage: profileImage != null && profileImage.isNotEmpty
                  ? NetworkImage(profileImage)
                  : null,
              child: profileImage == null || profileImage.isEmpty
                  ? Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'R',
                      style: TextStyle(
                        fontSize: R.fontSize(28, context),
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    )
                  : null,
            ),
            SizedBox(height: R.sh(1.25, context)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    userName,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: R.fontSize(18, context),
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                SizedBox(width: R.sw(2, context)),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: const Icon(Icons.edit, size: 18),
                  color: AppColors.textSecondary,
                  tooltip: 'Edit name',
                  onPressed: () => _showEditNameDialog(initialName: rawName),
                ),
              ],
            ),
            SizedBox(height: R.sh(0.75, context)),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: R.sw(3, context),
                vertical: R.sh(0.75, context),
              ),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getStatusIcon(status),
                    size: 16,
                    color: _getStatusColor(status),
                  ),
                  SizedBox(width: R.sw(1, context)),
                  Text(
                    _getStatusLabel(status),
                    style: TextStyle(
                      fontSize: R.fontSize(12, context),
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(status),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: R.sh(1.5, context)),
            if (userPhone.isNotEmpty)
              _buildInfoRow(Icons.phone, userPhone),
            if (userEmail.isNotEmpty) ...[
              SizedBox(height: R.sh(1, context)),
              _buildInfoRow(Icons.email, userEmail),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        SizedBox(width: R.sw(2, context)),
        Text(
          text,
          style: TextStyle(
            fontSize: R.fontSize(14, context),
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  bool _isKycVerified() {
    final approved = _riderProfile?['approved'];
    if (approved is bool) return approved;
    final kycStatus = (_riderProfile?['kyc_status'] ??
            _riderProfile?['kycStatus'])
        ?.toString()
        .toLowerCase();
    return kycStatus == 'verified' || kycStatus == 'approved';
  }

  String _vehicleType() {
    final vehicle = _riderProfile?['vehicle'];
    if (vehicle is Map) {
      return (vehicle['type'] ?? vehicle['vehicle'] ?? '').toString().trim();
    }
    final type = vehicle?.toString().trim() ??
        _riderProfile?['vehicle_type']?.toString().trim();
    return (type == null || type.isEmpty) ? 'Not set' : type;
  }

  String _vehicleNumber() {
    final vehicle = _riderProfile?['vehicle'];
    if (vehicle is Map) {
      final number = (vehicle['number'] ?? vehicle['vehicleNumber'] ?? '')
          .toString()
          .trim();
      if (number.isNotEmpty) return number;
    }
    final number = (_riderProfile?['vehicleNumber'] ??
            _riderProfile?['vehicle_number'])
        ?.toString()
        .trim();
    return (number == null || number.isEmpty) ? 'Not set' : number;
  }

  String _licenceNumber() {
    final vehicle = _riderProfile?['vehicle'];
    if (vehicle is Map) {
      final licence = (vehicle['licenceNumber'] ??
              vehicle['licenseNumber'] ??
              vehicle['licence_number'] ??
              '')
          .toString()
          .trim();
      if (licence.isNotEmpty) return licence;
    }
    final licence = (_riderProfile?['licenceNumber'] ??
            _riderProfile?['license_number'] ??
            _riderProfile?['licence_number'])
        ?.toString()
        .trim();
    return (licence == null || licence.isEmpty) ? 'Not set' : licence;
  }

  Widget _buildPerformanceMetrics() {
    if (_earnings == null) return const SizedBox.shrink();
    final earnings = _earnings!;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.divider, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(R.sw(4, context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Metrics',
              style: TextStyle(
                fontSize: R.fontSize(16, context),
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: R.sh(2, context)),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    'Total Deliveries',
                    '${earnings.totalDeliveries}',
                    Icons.local_shipping,
                    Colors.blue,
                  ),
                ),
                SizedBox(width: R.sw(3, context)),
                Expanded(
                  child: _buildMetricItem(
                    'Completed',
                    '${earnings.completedDeliveries}',
                    Icons.check_circle,
                    AppColors.success,
                  ),
                ),
              ],
            ),
            SizedBox(height: R.sh(1.5, context)),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    'Average Rating',
                    earnings.rating.toStringAsFixed(1),
                    Icons.star,
                    AppColors.warning,
                  ),
                ),
                SizedBox(width: R.sw(3, context)),
                Expanded(
                  child: _buildMetricItem(
                    'Total Ratings',
                    '${earnings.totalRatings}',
                    Icons.rate_review,
                    AppColors.primary,
                  ),
                ),
              ],
            ),
            if (earnings.cancelledDeliveries > 0) ...[
              SizedBox(height: R.sh(1.5, context)),
              _buildMetricItem(
                'Cancelled',
                '${earnings.cancelledDeliveries}',
                Icons.cancel,
                Colors.red,
                fullWidth: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(
      String label, String value, IconData icon, Color color,
      {bool fullWidth = false}) {
    return Container(
      padding: EdgeInsets.all(R.sw(3, context)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              SizedBox(width: R.sw(1, context)),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: R.fontSize(12, context),
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: R.sh(0.5, context)),
          Text(
            value,
            style: TextStyle(
              fontSize: R.fontSize(18, context),
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleDetails() {
    final vehicleType = _vehicleType();
    final vehicleNumber = _vehicleNumber();
    final licenseNumber = _licenceNumber();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.divider, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(R.sw(4, context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Vehicle Details',
                  style: TextStyle(
                    fontSize: R.fontSize(16, context),
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _showEditVehicleDialog(),
                ),
              ],
            ),
            SizedBox(height: R.sh(1.5, context)),
            _buildDetailRow(
                'Vehicle Type', vehicleType, Icons.directions_bike),
            SizedBox(height: R.sh(1.5, context)),
            _buildDetailRow(
                'Vehicle Number', vehicleNumber, Icons.confirmation_number),
            SizedBox(height: R.sh(1.5, context)),
            _buildDetailRow('License Number', licenseNumber, Icons.badge),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        SizedBox(width: R.sw(3, context)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: R.fontSize(12, context),
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: R.sh(0.5, context)),
              Text(
                value,
                style: TextStyle(
                  fontSize: R.fontSize(14, context),
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEarningsSummary() {
    if (_earnings == null) return const SizedBox.shrink();
    final earnings = _earnings!;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE31E24), Color(0xFFB71C1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(R.sw(4, context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Earnings Summary',
              style: TextStyle(
                fontSize: R.fontSize(16, context),
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: R.sh(2, context)),
            _buildEarningsRow('Today', earnings.today, Icons.today),
            SizedBox(height: R.sh(1.5, context)),
            _buildEarningsRow(
                'This Week', earnings.thisWeek, Icons.calendar_view_week),
            SizedBox(height: R.sh(1.5, context)),
            _buildEarningsRow(
                'This Month', earnings.thisMonth, Icons.calendar_month),
            const Divider(height: 24, color: Colors.white24),
            _buildEarningsRow(
                'Total Earnings',
                earnings.total,
                Icons.account_balance_wallet,
                isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickLinks() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.analytics_outlined, color: AppColors.primary),
            title: const Text('Performance analytics'),
            subtitle: const Text('Earnings trends and delivery stats'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RiderAnalyticsScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.map_outlined, color: AppColors.primary),
            title: const Text('Delivery route map'),
            subtitle: const Text('View stops and optimized route'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DeliveryMapScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsRow(String label, double amount, IconData icon,
      {bool isTotal = false}) {
    return Row(
      children: [
        Icon(icon,
            size: 20,
            color: Colors.white.withValues(alpha: isTotal ? 1 : 0.8)),
        SizedBox(width: R.sw(3, context)),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isTotal
                  ? R.fontSize(16, context)
                  : R.fontSize(14, context),
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: Colors.white,
            ),
          ),
        ),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isTotal
                ? R.fontSize(18, context)
                : R.fontSize(16, context),
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildKYCStatus() {
    final kycVerified = _isKycVerified();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.divider, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(R.sw(4, context)),
        child: Row(
          children: [
            Icon(
              kycVerified ? Icons.verified : Icons.verified_user_outlined,
              color: kycVerified ? AppColors.success : AppColors.warning,
              size: 24,
            ),
            SizedBox(width: R.sw(3, context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'KYC Status',
                    style: TextStyle(
                      fontSize: R.fontSize(14, context),
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: R.sh(0.5, context)),
                  Text(
                    kycVerified ? 'Verified' : 'Not Verified',
                    style: TextStyle(
                      fontSize: R.fontSize(12, context),
                      color: kycVerified
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available':
        return AppColors.success;
      default:
        return AppColors.surface;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'available':
        return Icons.check_circle;
      default:
        return Icons.cancel;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'available':
        return 'Online';
      default:
        return 'Offline';
    }
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _confirmLogout,
        icon: const Icon(Icons.logout, color: AppColors.primary),
        label: Text(
          'Log out',
          style: TextStyle(
            fontSize: R.fontSize(14, context),
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.primary),
          padding: EdgeInsets.symmetric(vertical: R.sh(1.75, context)),
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      _riderService.disposeRealtime();
      _locationService.stopSendingLocation();
      _assignmentAlerts.clear();
      SocketService().disconnect();
      await AuthService().signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const PhoneScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not log out. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showEditVehicleDialog() async {
    final currentVehicleType =
        _vehicleType() == 'Not set' ? '' : _vehicleType();
    final currentVehicleNumber =
        _vehicleNumber() == 'Not set' ? '' : _vehicleNumber();
    final currentLicenseNumber =
        _licenceNumber() == 'Not set' ? '' : _licenceNumber();

    final vehicleNumberController =
        TextEditingController(text: currentVehicleNumber);
    final licenseNumberController =
        TextEditingController(text: currentLicenseNumber);
    final formKey = GlobalKey<FormState>();

    String selectedVehicleType =
        currentVehicleType.isNotEmpty ? currentVehicleType : 'Bike';
    bool isSaving = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Edit Vehicle Details'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedVehicleType,
                      decoration: const InputDecoration(
                        labelText: 'Vehicle Type',
                        prefixIcon: Icon(Icons.directions_bike),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Bike', child: Text('Bike')),
                        DropdownMenuItem(
                            value: 'Scooter', child: Text('Scooter')),
                        DropdownMenuItem(
                            value: 'Motorcycle', child: Text('Motorcycle')),
                        DropdownMenuItem(value: 'Car', child: Text('Car')),
                        DropdownMenuItem(value: 'Auto', child: Text('Auto')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedVehicleType = value;
                          });
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select vehicle type';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: R.sh(2, dialogContext)),
                    TextFormField(
                      controller: vehicleNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Vehicle Number',
                        hintText: 'e.g., MH12AB1234',
                        prefixIcon: Icon(Icons.confirmation_number),
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter vehicle number';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: R.sh(2, dialogContext)),
                    TextFormField(
                      controller: licenseNumberController,
                      decoration: const InputDecoration(
                        labelText: 'License Number',
                        hintText: 'Enter your driving license number',
                        prefixIcon: Icon(Icons.badge),
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter license number';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) {
                          return;
                        }

                        setDialogState(() {
                          isSaving = true;
                        });

                        try {
                          await _riderService.updateVehicleDetails(
                            vehicleType: selectedVehicleType,
                            vehicleNumber: vehicleNumberController.text,
                            licenseNumber: licenseNumberController.text,
                          );

                          if (!dialogContext.mounted) return;
                          Navigator.of(dialogContext).pop();

                          if (!mounted) return;
                          await _loadProfile();

                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Vehicle details updated successfully',
                              ),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        } catch (e) {
                          if (!dialogContext.mounted) return;
                          setDialogState(() {
                            isSaving = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to update: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      );
    } finally {
      vehicleNumberController.dispose();
      licenseNumberController.dispose();
    }
  }

  Future<void> _showEditNameDialog({required String initialName}) async {
    final controller = TextEditingController(text: initialName);
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Edit Name'),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
                onFieldSubmitted: (_) {},
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    isSaving ? null : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) {
                          return;
                        }
                        setDialogState(() => isSaving = true);
                        try {
                          await _riderService
                              .updateRiderName(controller.text.trim());
                          if (!dialogContext.mounted) return;
                          Navigator.of(dialogContext).pop();

                          if (!mounted) return;
                          await _loadProfile();

                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Name updated successfully'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        } catch (e) {
                          if (!dialogContext.mounted) return;
                          setDialogState(() => isSaving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to update: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
  }
}
