import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../core/constants/app_constants.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/admin/admin_navigation_drawer.dart';
import 'admin_user_detail_screen.dart';

/// Admin Users Management Screen
/// Allows viewing, searching, filtering, and managing users (customers, riders, staff, admins)
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _adminService = AdminService();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String? _selectedRole; // null = all, 'customer', 'rider', 'staff', 'admin'
  bool? _showOnlyActive; // null = all, true = active only, false = inactive only
  String? _processingUserId;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(() {
      if (_searchController.text.trim().isEmpty) {
        _loadUsers();
      }
    });
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _adminService.getAllUsers(
        role: _selectedRole,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        isActive: _showOnlyActive,
      );
      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Failed to load users: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _toggleUserStatus(Map<String, dynamic> user) async {
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

    setState(() => _processingUserId = userId);
    try {
      await _adminService.updateUserStatus(userId, newStatus);
      if (!mounted) return;
      _showSuccess(
        newStatus
            ? '$userName has been unblocked'
            : '$userName has been blocked',
      );
      _loadUsers();
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to update user status: $e');
    } finally {
      if (mounted) {
        setState(() => _processingUserId = null);
      }
    }
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

  String _normalizeRoleKey(String? role) {
    final value = (role ?? '').toLowerCase();
    if (value == 'delivery' || value == 'rider') return 'delivery_partner';
    return value;
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

  String _roleApiValue(String uiRole) {
    switch (uiRole) {
      case 'rider':
        return 'delivery_partner';
      default:
        return uiRole;
    }
  }

  Future<void> _changeUserRole(Map<String, dynamic> user) async {
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
                Text(
                  'Assign Role — $userName',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select a new role for this user',
                  style: TextStyle(color: AppColors.textSecondary),
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

    setState(() => _processingUserId = userId);
    try {
      await _adminService.updateUserRole(userId, _roleApiValue(selectedRole));
      if (!mounted) return;
      _showSuccess(
        '${_getRoleDisplayName(selectedRole)} role assigned to $userName',
      );
      _loadUsers();
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to assign role: $e');
    } finally {
      if (mounted) setState(() => _processingUserId = null);
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      drawer: AdminNavigationDrawer(
        currentSection: AdminNavSection.users,
        onLogout: () => AdminNavigationDrawer.confirmLogout(context),
      ),
      appBar: AppBar(
        title: const Text('Manage Users'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, phone, or email...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _loadUsers();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.divider),
                    ),
                    filled: true,
                    fillColor: AppColors.background,
                  ),
                  onSubmitted: (_) => _loadUsers(),
                ),
                const SizedBox(height: 12),
                // Filter Row
                Row(
                  children: [
                    // Role Filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(_selectedRole),
                        initialValue: _selectedRole,
                        decoration: InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('All Roles')),
                          DropdownMenuItem(value: 'customer', child: Text('Customer')),
                          DropdownMenuItem(value: 'rider', child: Text('Rider')),
                          DropdownMenuItem(value: 'staff', child: Text('Staff')),
                          DropdownMenuItem(value: 'admin', child: Text('Admin')),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedRole = value);
                          _loadUsers();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Status Filter
                    Expanded(
                      child: DropdownButtonFormField<bool?>(
                        key: ValueKey(_showOnlyActive),
                        initialValue: _showOnlyActive,
                        decoration: InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('All')),
                          DropdownMenuItem(value: true, child: Text('Active')),
                          DropdownMenuItem(value: false, child: Text('Blocked')),
                        ],
                        onChanged: (value) {
                          setState(() => _showOnlyActive = value);
                          _loadUsers();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Users List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: AppColors.surface,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No users found',
                              style: TextStyle(
                                fontSize: 18,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try adjusting your filters',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadUsers,
                        color: AppColors.primary,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _users.length,
                          itemBuilder: (context, index) {
                            final user = _users[index];
                            return _buildUserCard(user);
                          },
                        ),
                      ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final userId = user['id'] as String;
    final name = user['name'] as String? ?? 'Unknown';
    final phone = user['phone'] as String? ?? '';
    final email = user['email'] as String?;
    final role = _normalizeRoleKey(user['role'] as String?);
    final isActive = user['is_active'] as bool? ?? true;
    final orderCount = user['order_count'] as int? ?? 0;
    final lifetimeValue = (user['lifetime_value'] as num?)?.toDouble() ?? 0.0;
    final createdAt = user['created_at'] as String?;
    final riderInfo = user['rider'] as Map<String, dynamic>?;

    final isProcessing = _processingUserId == userId;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive ? AppColors.divider : AppColors.primary.withValues(alpha: 0.3),
          width: isActive ? 1 : 2,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AdminUserDetailScreen(userId: userId),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: _getRoleBadgeColor(role).withValues(alpha: 0.1),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: _getRoleBadgeColor(role),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name and Role
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
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                        const SizedBox(height: 4),
                        Text(
                          phone,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (email != null && email.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Status and Actions
                  Column(
                    children: [
                      // Status Badge
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
                      const SizedBox(height: 8),
                      IconButton(
                        icon: const Icon(
                          Icons.manage_accounts,
                          color: Colors.blue,
                        ),
                        onPressed: isProcessing ? null : () => _changeUserRole(user),
                        tooltip: 'Assign Role',
                      ),
                      IconButton(
                        icon: Icon(
                          isActive ? Icons.block : Icons.check_circle,
                          color: isActive ? AppColors.primary : AppColors.success,
                        ),
                        onPressed: isProcessing ? null : () => _toggleUserStatus(user),
                        tooltip: isActive ? 'Block User' : 'Unblock User',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Stats Row
              Row(
                children: [
                  // Order Count
                  Expanded(
                    child: _buildStatChip(
                      icon: Icons.shopping_bag,
                      label: 'Orders',
                      value: orderCount.toString(),
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Lifetime Value
                  Expanded(
                    child: _buildStatChip(
                      icon: Icons.currency_rupee,
                      label: 'Spent',
                      value: '₹${_formatCurrency(lifetimeValue)}',
                      color: AppColors.success,
                    ),
                  ),
                  if (_normalizeRoleKey(role) == 'delivery_partner' && riderInfo != null) ...[
                    const SizedBox(width: 8),
                    // Rider Deliveries
                    Expanded(
                      child: _buildStatChip(
                        icon: Icons.delivery_dining,
                        label: 'Deliveries',
                        value: (riderInfo['total_deliveries'] as int? ?? 0).toString(),
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ],
              ),
              if (createdAt != null) ...[
                const SizedBox(height: 8),
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
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else if (difference.inDays < 30) {
        return '${(difference.inDays / 7).floor()} weeks ago';
      } else if (difference.inDays < 365) {
        return '${(difference.inDays / 30).floor()} months ago';
      } else {
        return '${(difference.inDays / 365).floor()} years ago';
      }
    } catch (e) {
      return dateString;
    }
  }
}

