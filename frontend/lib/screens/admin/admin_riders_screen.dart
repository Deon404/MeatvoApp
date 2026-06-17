import 'package:flutter/material.dart';

import '../../services/admin_service.dart';
import '../../core/constants/app_constants.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/admin/admin_navigation_drawer.dart';

enum RiderKycStatus { pending, verified, rejected }

class _RiderProfile {
  const _RiderProfile({
    required this.id,
    required this.name,
    required this.phone,
    required this.vehicle,
    required this.joinedOn,
    required this.status,
  });

  final String id;
  final String name;
  final String phone;
  final String vehicle;
  final DateTime joinedOn;
  final RiderKycStatus status;
}

class AdminRidersScreen extends StatefulWidget {
  const AdminRidersScreen({super.key});

  @override
  State<AdminRidersScreen> createState() => _AdminRidersScreenState();
}

class _AdminRidersScreenState extends State<AdminRidersScreen> {
  final _adminService = AdminService();
  List<_RiderProfile> _riders = [];
  bool _isLoading = true;
  String? _processingRiderId;

  @override
  void initState() {
    super.initState();
    _loadRiders();
  }

  RiderKycStatus _kycStatusFromPartner(Map<String, dynamic> partner) {
    final profile = partner['profile'] is Map
        ? Map<String, dynamic>.from(partner['profile'] as Map)
        : <String, dynamic>{};
    final approved = profile['approved'];
    if (approved == true) return RiderKycStatus.verified;
    if (approved == false) return RiderKycStatus.rejected;
    return RiderKycStatus.pending;
  }

  _RiderProfile _mapPartner(Map<String, dynamic> partner) {
    final profile = partner['profile'] is Map
        ? Map<String, dynamic>.from(partner['profile'] as Map)
        : <String, dynamic>{};
    return _RiderProfile(
      id: partner['id']?.toString() ?? '',
      name: profile['name']?.toString() ?? partner['phone']?.toString() ?? 'Rider',
      phone: partner['phone']?.toString() ?? '',
      vehicle: profile['vehicle']?.toString() ?? 'Not specified',
      joinedOn: DateTime.now(),
      status: _kycStatusFromPartner(partner),
    );
  }

  Future<void> _loadRiders() async {
    setState(() => _isLoading = true);
    try {
      final partners = await _adminService.getDeliveryPartners();
      if (!mounted) return;
      setState(() {
        _riders = partners.map(_mapPartner).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Failed to load riders: $e', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.primary : AppColors.success,
      ),
    );
  }

  Future<void> _updateStatus(_RiderProfile rider, RiderKycStatus status) async {
    setState(() => _processingRiderId = rider.id);
    try {
      await _adminService.updateRiderKYC(
        rider.id,
        status == RiderKycStatus.verified,
      );
      if (!mounted) return;
      _showMessage(
        status == RiderKycStatus.verified
            ? '${rider.name} verified'
            : '${rider.name} rejected',
      );
      await _loadRiders();
    } catch (e) {
      if (!mounted) return;
      _showMessage('Failed to update KYC: $e', isError: true);
    } finally {
      if (mounted) setState(() => _processingRiderId = null);
    }
  }

  void _showCreateRiderInfo() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Rider Profile'),
        content: const Text(
          'Pehle Manage Users se kisi user ko delivery partner role assign karein. '
          'Uske baad woh yahan riders list mein dikhega.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      drawer: AdminNavigationDrawer(
        currentSection: AdminNavSection.riders,
        onLogout: () => AdminNavigationDrawer.confirmLogout(context),
      ),
      appBar: AppBar(
        title: const Text('Manage Riders'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateRiderInfo,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Create Profile'),
        backgroundColor: AppColors.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadRiders,
              color: AppColors.primary,
              child: _riders.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(height: R.sh(6, context)),
                        const Center(
                          child: Text(
                            'No riders onboard yet.\nPromote a user from Manage Users.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      itemBuilder: (context, index) {
                        final rider = _riders[index];
                        final isProcessing = _processingRiderId == rider.id;
                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            rider.name,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            rider.phone,
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    _statusChip(rider.status),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.motorcycle, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        rider.vehicle,
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: isProcessing ||
                                                rider.status == RiderKycStatus.verified
                                            ? null
                                            : () => _updateStatus(
                                                  rider,
                                                  RiderKycStatus.verified,
                                                ),
                                        icon: const Icon(Icons.verified),
                                        label: const Text('Verify KYC'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: isProcessing ||
                                                rider.status == RiderKycStatus.rejected
                                            ? null
                                            : () => _updateStatus(
                                                  rider,
                                                  RiderKycStatus.rejected,
                                                ),
                                        icon: const Icon(Icons.block),
                                        label: const Text('Reject'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemCount: _riders.length,
                    ),
            ),
    );
  }

  Widget _statusChip(RiderKycStatus status) {
    Color bg;
    Color text;
    String label;

    switch (status) {
      case RiderKycStatus.verified:
        bg = Colors.green.shade100;
        text = Colors.green.shade800;
        label = 'KYC Verified';
      case RiderKycStatus.pending:
        bg = Colors.orange.shade100;
        text = Colors.orange.shade800;
        label = 'Pending KYC';
      case RiderKycStatus.rejected:
        bg = Colors.red.shade100;
        text = Colors.red.shade800;
        label = 'Rejected';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: text,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
