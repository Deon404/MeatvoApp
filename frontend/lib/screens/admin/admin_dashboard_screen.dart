import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../services/socket_service.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/admin/new_order_alert_banner.dart';
import '../auth/phone_screen.dart';
import 'admin_banners_screen.dart';
import 'admin_categories_screen.dart';
import 'admin_orders_map_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_products_screen.dart';
import 'admin_riders_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_users_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _adminService = AdminService();
  final _socketService = SocketService();
  AdminNewOrderAlertController? _alertController;
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupNewOrderAlerts();
    });
  }

  @override
  void dispose() {
    _socketService.offNewOrder();
    _alertController?.dispose();
    super.dispose();
  }

  void _setupNewOrderAlerts() {
    if (!mounted) return;

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    _alertController = AdminNewOrderAlertController(
      overlayState: overlay,
      onTap: (_) => _openOrdersFromAlert(),
    );
    _setupSocket();
  }

  Future<void> _setupSocket() async {
    await _socketService.connect();
    _socketService.emit('join_admin_room', null);
    _socketService.onNewOrder(_handleNewOrder);
  }

  void _handleNewOrder(dynamic data) {
    if (!mounted) return;

    final alert = NewOrderAlertData.fromSocket(data);
    if (alert.orderId == 0) return;

    setState(() {
      _stats ??= <String, dynamic>{};
      final currentOrders = _readStatInt(['today_orders', 'todayOrders']);
      _stats!['today_orders'] = currentOrders + 1;
      _stats!['todayOrders'] = currentOrders + 1;

      final currentRevenue = _readStatDouble(['today_revenue', 'todayRevenue']);
      final updatedRevenue = currentRevenue + alert.totalAmount;
      _stats!['today_revenue'] = updatedRevenue;
      _stats!['todayRevenue'] = updatedRevenue;
    });

    _alertController?.enqueue(alert);
  }

  void _openOrdersFromAlert() {
    if (!mounted) return;
    _open(context, const AdminOrdersScreen());
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _adminService.getDashboardStats();
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading stats: $e'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isTablet = screenWidth > 600;
    final todayOrders = _readStatInt(['today_orders', 'todayOrders']);
    final todayRevenue = _readStatDouble([
      'today_revenue',
      'todayRevenue',
    ]);
    final activeRiders = _readStatInt([
      'active_riders',
      'activeRiders',
      'total_delivery_partners',
      'totalDeliveryPartners',
    ]);
    
    // Responsive font sizes
    final titleFontSize = isSmallScreen ? 18.0 : (isTablet ? 24.0 : 20.0);
    final cardTitleFontSize = isSmallScreen ? 13.0 : (isTablet ? 18.0 : 16.0);
    final cardIconSize = isSmallScreen ? 40.0 : (isTablet ? 56.0 : 48.0);
    final statValueFontSize = isSmallScreen ? 20.0 : (isTablet ? 28.0 : 24.0);
    final statIconSize = isSmallScreen ? 24.0 : (isTablet ? 32.0 : 28.0);
    
    // Responsive spacing
    final horizontalPadding = isSmallScreen ? 12.0 : (isTablet ? 24.0 : 16.0);
    final cardPadding = isSmallScreen ? 12.0 : (isTablet ? 24.0 : 20.0);
    final gridSpacing = isSmallScreen ? 8.0 : (isTablet ? 16.0 : 12.0);
    final childAspectRatio = isSmallScreen ? 1.3 : (isTablet ? 1.0 : 1.2);
    
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.warmBg,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: AppColors.cardBg,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _confirmLogout,
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            color: AppColors.primary,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
              onRefresh: _loadStats,
              color: AppColors.primary,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Cards Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Today\'s Orders',
                            '$todayOrders',
                            Icons.shopping_bag,
                            AppColors.bluePrimary,
                            statValueFontSize: statValueFontSize,
                            statIconSize: statIconSize,
                          ),
                        ),
                        SizedBox(width: gridSpacing),
                        Expanded(
                          child: _buildStatCard(
                            'Today\'s Revenue',
                            '₹${_formatCurrency(todayRevenue)}',
                            Icons.currency_rupee,
                            AppColors.success,
                            statValueFontSize: statValueFontSize,
                            statIconSize: statIconSize,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: gridSpacing),
                    _buildStatCard(
                      'Active Riders',
                      '$activeRiders',
                      Icons.delivery_dining,
                      AppColors.warning,
                      fullWidth: true,
                      statValueFontSize: statValueFontSize,
                      statIconSize: statIconSize,
                    ),
                    SizedBox(height: 24),
                    
                    // Quick Actions Section
                    Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    SizedBox(height: gridSpacing),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: gridSpacing,
                      mainAxisSpacing: gridSpacing,
                      childAspectRatio: childAspectRatio,
                      children: [
                        _buildActionCard(
                          'Orders',
                          Icons.receipt_long,
                          AppColors.bluePrimary,
                          () => _open(context, const AdminOrdersScreen()),
                          iconSize: cardIconSize,
                          fontSize: cardTitleFontSize,
                          padding: cardPadding,
                        ),
                        _buildActionCard(
                          'Route Map',
                          Icons.map,
                          AppColors.primary,
                          () => _open(context, const AdminOrdersMapScreen()),
                          iconSize: cardIconSize,
                          fontSize: cardTitleFontSize,
                          padding: cardPadding,
                        ),
                        _buildActionCard(
                          'Riders',
                          Icons.delivery_dining,
                          AppColors.warning,
                          () => _open(context, const AdminRidersScreen()),
                          iconSize: cardIconSize,
                          fontSize: cardTitleFontSize,
                          padding: cardPadding,
                        ),
                        _buildActionCard(
                          'Products',
                          Icons.inventory_2,
                          AppColors.success,
                          () => _open(context, const AdminProductsScreen()),
                          iconSize: cardIconSize,
                          fontSize: cardTitleFontSize,
                          padding: cardPadding,
                        ),
                        _buildActionCard(
                          'Categories',
                          Icons.category,
                          AppColors.bluePrimary,
                          () => _open(context, const AdminCategoriesScreen()),
                          iconSize: cardIconSize,
                          fontSize: cardTitleFontSize,
                          padding: cardPadding,
                        ),
                        _buildActionCard(
                          'Banners',
                          Icons.view_carousel,
                          AppColors.success,
                          () => _open(context, const AdminBannersScreen()),
                          iconSize: cardIconSize,
                          fontSize: cardTitleFontSize,
                          padding: cardPadding,
                        ),
                        _buildActionCard(
                          'Settings',
                          Icons.settings,
                          AppColors.textSecondary,
                          () => _open(context, const AdminSettingsScreen()),
                          iconSize: cardIconSize,
                          fontSize: cardTitleFontSize,
                          padding: cardPadding,
                        ),
                        _buildActionCard(
                          'Users',
                          Icons.people,
                          AppColors.primary,
                          () => _open(context, const AdminUsersScreen()),
                          iconSize: cardIconSize,
                          fontSize: cardTitleFontSize,
                          padding: cardPadding,
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    _buildLogoutButton(),
                    SizedBox(height: horizontalPadding),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _confirmLogout,
        icon: const Icon(Icons.logout, color: AppColors.primary),
        label: const Text(
          'Log out',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.primary),
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You will need to sign in again to access the admin dashboard.',
        ),
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
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    bool fullWidth = false,
    double? statValueFontSize,
    double? statIconSize,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final titleFontSize = isSmallScreen ? 12.0 : 14.0;
    
    return Card(
      elevation: 0,
      color: AppColors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: statIconSize ?? 28),
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: statValueFontSize ?? 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: titleFontSize,
                color: AppColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    double? iconSize,
    double? fontSize,
    double? padding,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final defaultIconSize = iconSize ?? 48.0;
    final defaultFontSize = fontSize ?? 16.0;
    final defaultPadding = padding ?? 20.0;
    final spacing = isSmallScreen ? 8.0 : 12.0;
    
    return Card(
      elevation: 0,
      color: AppColors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(defaultPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: defaultIconSize, color: color),
              SizedBox(height: spacing),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: defaultFontSize,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _readStatInt(List<String> keys) {
    final stats = _stats;
    if (stats == null) return 0;

    for (final key in keys) {
      final value = stats[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }

    return 0;
  }

  double _readStatDouble(List<String> keys) {
    final stats = _stats;
    if (stats == null) return 0.0;

    for (final key in keys) {
      final value = stats[key];
      if (value is double) return value;
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }

    return 0.0;
  }

  String _formatCurrency(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    } else {
      return amount.toStringAsFixed(0);
    }
  }
}

