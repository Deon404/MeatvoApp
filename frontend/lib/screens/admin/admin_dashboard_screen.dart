import 'package:flutter/material.dart';
import '../../config/backend_resolver.dart';
import '../../services/admin_service.dart';
import '../../services/socket_service.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/admin/admin_navigation_drawer.dart';
import '../../widgets/admin/assignment_failed_alert_banner.dart';
import '../../widgets/admin/new_order_alert_banner.dart';
import '../../widgets/common/error_state.dart';
import 'admin_orders_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _adminService = AdminService();
  final _socketService = SocketService();
  AdminNewOrderAlertController? _alertController;
  AdminAssignmentFailedAlertController? _assignmentFailedController;
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  String? _loadError;

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
    _socketService.offAssignmentFailed();
    _alertController?.dispose();
    _assignmentFailedController?.dispose();
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
    _assignmentFailedController = AdminAssignmentFailedAlertController(
      overlayState: overlay,
      onTap: (_) => _openOrdersFromAlert(),
    );
    _setupSocket();
  }

  Future<void> _setupSocket() async {
    await _socketService.connect();
    _socketService.onNewOrder(_handleNewOrder);
    _socketService.onAssignmentFailed(_handleAssignmentFailed);
  }

  void _handleAssignmentFailed(dynamic data) {
    if (!mounted) return;

    final alert = AssignmentFailedAlertData.fromSocket(data);
    if (alert.orderId == 0) return;

    _assignmentFailedController?.show(alert);
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
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final stats = await _adminService.getDashboardStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _isLoading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = BackendResolver.toUserMessage(
          e,
          fallback: 'Could not load dashboard stats.',
        );
      });
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
    final statValueFontSize = isSmallScreen ? 20.0 : (isTablet ? 28.0 : 24.0);
    final statIconSize = isSmallScreen ? 24.0 : (isTablet ? 32.0 : 28.0);
    
    // Responsive spacing
    final horizontalPadding = isSmallScreen ? 12.0 : (isTablet ? 24.0 : 16.0);
    final gridSpacing = isSmallScreen ? 8.0 : (isTablet ? 16.0 : 12.0);
    
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.warmBg,
      drawer: AdminNavigationDrawer(
        currentSection: AdminNavSection.dashboard,
        todayOrders: todayOrders,
        todayRevenue: todayRevenue,
        onLogout: () => AdminNavigationDrawer.confirmLogout(context),
      ),
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: AppColors.cardBg,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadStats,
            tooltip: 'Refresh stats',
            icon: const Icon(Icons.refresh),
            color: AppColors.textSecondary,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null && _stats == null
                ? ErrorStateWidget(
                    title: 'Dashboard unavailable',
                    message: _loadError,
                    icon: Icons.cloud_off_outlined,
                    iconColor: AppColors.primary,
                    onRetry: _loadStats,
                  )
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
                    SizedBox(height: horizontalPadding),
                  ],
                ),
              ),
            ),
      ),
    );
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

