import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../core/constants/app_constants.dart';
import '../../utils/address_display_util.dart';
import '../../utils/responsive_helper.dart';
import '../../utils/order_display_util.dart';
import '../orders/order_detail_screen.dart';

/// Admin User Detail Screen
/// Shows complete user information, order history, and management options
class AdminUserDetailScreen extends StatefulWidget {
  final String userId;

  const AdminUserDetailScreen({super.key, required this.userId});

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  final _adminService = AdminService();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedTab; // 'orders', 'addresses', 'rider_info'

  @override
  void initState() {
    super.initState();
    _selectedTab = 'orders';
    _loadUserDetails();
  }

  Future<void> _loadUserDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userData = await _adminService.getUserDetails(widget.userId);
      if (!mounted) return;
      setState(() {
        _userData = userData;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load user details: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleUserStatus() async {
    final user = _userData?['user'] as Map<String, dynamic>?;
    if (user == null) return;

    final userId = user['id'] as String;
    final currentStatus = user['is_active'] as bool? ?? true;
    final newStatus = !currentStatus;
    final userName = user['name'] as String? ?? 'User';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(newStatus ? 'Unblock User' : 'Block User'),
        content: Text(
          newStatus
              ? 'Are you sure you want to unblock $userName?'
              : 'Are you sure you want to block $userName? This will prevent them from using the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus ? AppColors.success : AppColors.primary,
            ),
            child: Text(newStatus ? 'Unblock' : 'Block'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _adminService.updateUserStatus(userId, newStatus);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus
                ? '$userName has been unblocked'
                : '$userName has been blocked',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      _loadUserDetails();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update user status: $e'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  Future<void> _changeUserRole() async {
    final user = _userData?['user'] as Map<String, dynamic>?;
    if (user == null) return;

    final userId = user['id'] as String;
    final userName = user['name'] as String? ?? user['phone'] as String? ?? 'User';
    final currentRole = _normalizeRoleKey(user['role'] as String?);

    final selectedRole = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: modalSheetInsets(ctx, horizontal: 16, top: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Assign Role',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _roleOption(ctx, 'customer', 'Customer', Icons.person, currentRole),
                _roleOption(ctx, 'delivery_partner', 'Rider', Icons.delivery_dining, currentRole),
                _roleOption(ctx, 'staff', 'Staff', Icons.restaurant_menu, currentRole),
                _roleOption(ctx, 'admin', 'Admin', Icons.admin_panel_settings, currentRole),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;

    if (selectedRole == null || selectedRole == currentRole) return;

    if (selectedRole == 'admin') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Assign Admin Role'),
          content: Text(
            'Grant admin access to $userName? '
            'This user will have full access to the admin dashboard.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Assign Admin'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    try {
      await _adminService.updateUserRole(userId, _roleApiValue(selectedRole));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_getRoleDisplayName(selectedRole)} role assigned successfully',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      _loadUserDetails();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update role: $e'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  String _normalizeRoleKey(String? role) {
    final value = (role ?? '').toLowerCase();
    if (value == 'delivery' || value == 'rider') return 'delivery_partner';
    return value;
  }

  String _roleApiValue(String uiRole) {
    switch (uiRole) {
      case 'rider':
        return 'delivery_partner';
      default:
        return uiRole;
    }
  }

  Widget _roleOption(
    BuildContext ctx,
    String value,
    String label,
    IconData icon,
    String currentRole,
  ) {
    final isSelected = currentRole == value;
    return ListTile(
      leading: Icon(icon, color: _getRoleBadgeColor(value)),
      title: Text(label),
      trailing: isSelected ? const Icon(Icons.check, color: AppColors.success) : null,
      onTap: () => Navigator.of(ctx).pop(value),
    );
  }

  Color _getRoleBadgeColor(String? role) {
    switch (_normalizeRoleKey(role)) {
      case 'admin':
        return AppColors.primary;
      case 'delivery_partner':
        return Colors.blue;
      case 'customer':
        return AppColors.success;
      case 'staff':
        return AppColors.warning;
      default:
        return AppColors.surface;
    }
  }

  String _getRoleDisplayName(String? role) {
    switch (_normalizeRoleKey(role)) {
      case 'admin':
        return 'Admin';
      case 'delivery_partner':
        return 'Rider';
      case 'customer':
        return 'Customer';
      case 'staff':
        return 'Staff';
      default:
        return 'Unknown';
    }
  }

  String _formatCurrency(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('User Details'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          if (_userData != null) ...[
            IconButton(
              icon: const Icon(Icons.manage_accounts, color: Colors.blue),
              onPressed: _changeUserRole,
              tooltip: 'Assign Role',
            ),
            IconButton(
              icon: Icon(
                (_userData!['user'] as Map<String, dynamic>)['is_active'] == true
                    ? Icons.block
                    : Icons.check_circle,
                color: (_userData!['user'] as Map<String, dynamic>)['is_active'] == true
                    ? AppColors.primary
                    : AppColors.success,
              ),
              onPressed: _toggleUserStatus,
              tooltip: (_userData!['user'] as Map<String, dynamic>)['is_active'] == true
                  ? 'Block User'
                  : 'Unblock User',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadUserDetails,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _userData == null
                  ? const Center(child: Text('No user data'))
                  : RefreshIndicator(
                      onRefresh: _loadUserDetails,
                      color: AppColors.primary,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // User Info Card
                            _buildUserInfoCard(),
                            const SizedBox(height: 16),

                            // Stats Card
                            _buildStatsCard(),
                            const SizedBox(height: 16),

                            // Tabs
                            _buildTabs(),
                            const SizedBox(height: 16),

                            // Tab Content
                            _buildTabContent(),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildUserInfoCard() {
    final user = _userData!['user'] as Map<String, dynamic>;
    final name = user['name'] as String? ?? 'Unknown';
    final phone = user['phone'] as String? ?? '';
    final email = user['email'] as String?;
    final role = user['role'] as String? ?? 'customer';
    final isActive = user['is_active'] as bool? ?? true;
    final createdAt = user['created_at'] as String?;
    final profileImage = user['profile_image'] as String?;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.divider, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 40,
              backgroundColor: _getRoleBadgeColor(role).withValues(alpha: 0.1),
              backgroundImage: profileImage != null ? NetworkImage(profileImage) : null,
              child: profileImage == null
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: _getRoleBadgeColor(role),
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            // User Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      // Role Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getRoleBadgeColor(role).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getRoleDisplayName(role),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _getRoleBadgeColor(role),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          phone,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (email != null && email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.email, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            email,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.success.withValues(alpha: 0.1)
                              : AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isActive ? 'Active' : 'Blocked',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isActive ? AppColors.success : AppColors.primary,
                          ),
                        ),
                      ),
                      if (createdAt != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          'Joined: ${_formatDate(createdAt)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
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
    );
  }

  Widget _buildStatsCard() {
    final stats = _userData!['stats'] as Map<String, dynamic>;
    final totalOrders = stats['total_orders'] as int? ?? 0;
    final deliveredOrders = stats['delivered_orders'] as int? ?? 0;
    final cancelledOrders = stats['cancelled_orders'] as int? ?? 0;
    final totalSpent = (stats['total_spent'] as num?)?.toDouble() ?? 0.0;
    final avgOrderValue = (stats['average_order_value'] as num?)?.toDouble() ?? 0.0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.divider, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Statistics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Orders',
                    totalOrders.toString(),
                    Icons.shopping_bag,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Delivered',
                    deliveredOrders.toString(),
                    Icons.check_circle,
                    AppColors.success,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Cancelled',
                    cancelledOrders.toString(),
                    Icons.cancel,
                    AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Spent',
                    '₹${_formatCurrency(totalSpent)}',
                    Icons.currency_rupee,
                    AppColors.success,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Avg Order',
                    '₹${_formatCurrency(avgOrderValue)}',
                    Icons.trending_up,
                    Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Row(
      children: [
        Expanded(
          child: _buildTabButton('Orders', 'orders', Icons.shopping_bag),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildTabButton('Addresses', 'addresses', Icons.location_on),
        ),
        if (_userData!['rider_info'] != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: _buildTabButton('Rider Info', 'rider_info', Icons.delivery_dining),
          ),
        ],
      ],
    );
  }

  Widget _buildTabButton(String label, String tab, IconData icon) {
    final isSelected = _selectedTab == tab;
    return InkWell(
      onTap: () => setState(() => _selectedTab = tab),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.divider,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 'orders':
        return _buildOrdersTab();
      case 'addresses':
        return _buildAddressesTab();
      case 'rider_info':
        return _buildRiderInfoTab();
      default:
        return _buildOrdersTab();
    }
  }

  Widget _buildOrdersTab() {
    final orders = _userData!['orders'] as List<dynamic>? ?? [];

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 64,
              color: AppColors.surface,
            ),
            const SizedBox(height: 16),
            const Text(
              'No orders yet',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Order History (${orders.length})',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...orders.map((order) => _buildOrderCard(order as Map<String, dynamic>)),
      ],
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final orderId = order['id'] as String;
    final orderNumber = order['order_number'] as String? ?? formatOrderDisplayId(orderId);
    final status = order['status'] as String? ?? 'placed';
    final totalPrice = (order['total_price'] as num?)?.toDouble() ?? 0.0;
    final createdAt = order['created_at'] as String?;
    final items = order['items'] as List<dynamic>? ?? [];

    Color statusColor;
    switch (status) {
      case 'delivered':
        statusColor = AppColors.success;
        break;
      case 'cancelled':
        statusColor = AppColors.primary;
        break;
      case 'on_way':
      case 'out_for_delivery':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = AppColors.surface;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.divider, width: 1),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => OrderDetailScreen(orderId: orderId),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #$orderNumber',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              if (createdAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  _formatDate(createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              if (items.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${items.length} item${items.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total: ₹${totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressesTab() {
    final addresses = _userData!['addresses'] as List<dynamic>? ?? [];

    if (addresses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 64,
              color: AppColors.surface,
            ),
            const SizedBox(height: 16),
            const Text(
              'No addresses saved',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Saved Addresses (${addresses.length})',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...addresses.map((address) => _buildAddressCard(address as Map<String, dynamic>)),
      ],
    );
  }

  Widget _buildAddressCard(Map<String, dynamic> address) {
    final label = address['label'] as String? ?? 'home';
    final displayText = formatAddressForDisplay(address);
    final isDefault = address['is_default'] as bool? ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDefault ? AppColors.primary : AppColors.divider,
          width: isDefault ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  label == 'home'
                      ? Icons.home
                      : label == 'work'
                          ? Icons.work
                          : Icons.location_on,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (isDefault) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'DEFAULT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              displayText,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiderInfoTab() {
    final riderInfo = _userData!['rider_info'] as Map<String, dynamic>?;
    if (riderInfo == null) {
      return const Center(
        child: Text('No rider information available'),
      );
    }

    final status = riderInfo['status'] as String? ?? 'offline';
    final vehicleType = riderInfo['vehicle_type'] as String? ?? '';
    final vehicleNumber = riderInfo['vehicle_number'] as String? ?? '';
    final totalDeliveries = riderInfo['total_deliveries'] as int? ?? 0;
    final completedDeliveries = riderInfo['completed_deliveries'] as int? ?? 0;
    final averageRating = (riderInfo['average_rating'] as num?)?.toDouble() ?? 0.0;
    final earningsTotal = (riderInfo['earnings_total'] as num?)?.toDouble() ?? 0.0;
    final kycVerified = riderInfo['kyc_verified'] as bool? ?? false;

    Color statusColor;
    switch (status) {
      case 'available':
        statusColor = AppColors.success;
        break;
      case 'busy':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = AppColors.surface;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.divider, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rider Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildRiderInfoRow('Status', status.toUpperCase(), statusColor),
            const SizedBox(height: 12),
            _buildRiderInfoRow('Vehicle Type', vehicleType, AppColors.textPrimary),
            const SizedBox(height: 12),
            _buildRiderInfoRow('Vehicle Number', vehicleNumber, AppColors.textPrimary),
            const SizedBox(height: 12),
            _buildRiderInfoRow('Total Deliveries', totalDeliveries.toString(), Colors.blue),
            const SizedBox(height: 12),
            _buildRiderInfoRow('Completed', completedDeliveries.toString(), AppColors.success),
            const SizedBox(height: 12),
            _buildRiderInfoRow('Average Rating', averageRating.toStringAsFixed(1), Colors.blue),
            const SizedBox(height: 12),
            _buildRiderInfoRow('Total Earnings', '₹${_formatCurrency(earningsTotal)}', AppColors.success),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'KYC Verified: ',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                Icon(
                  kycVerified ? Icons.check_circle : Icons.cancel,
                  color: kycVerified ? AppColors.success : AppColors.primary,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiderInfoRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

