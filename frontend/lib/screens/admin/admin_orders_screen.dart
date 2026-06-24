import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/backend_resolver.dart';
import '../../services/admin_service.dart';
import '../../services/socket_service.dart';
import '../../core/constants/app_constants.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/error_state.dart';
import '../../widgets/admin/admin_navigation_drawer.dart';
import '../../widgets/admin/assignment_failed_alert_banner.dart';
import '../../widgets/admin/new_order_alert_banner.dart';
import '../../widgets/skeletons/order_card_skeleton.dart';

/// Admin Orders Management Screen
/// Lists all orders with filters, rider assignment, and status updates
class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  final _adminService = AdminService();
  final _socketService = SocketService();
  final _dateFormat = DateFormat('MMM d, yyyy • hh:mm a');
  AdminNewOrderAlertController? _alertController;
  Timer? _socketReloadDebounce;

  final List<Map<String, String?>> _statusFilters = const [
    {'label': 'All', 'value': null},
    {'label': 'Placed', 'value': 'PLACED'},
    {'label': 'Accepted', 'value': 'CONFIRMED'},
    {'label': 'Packed', 'value': 'PACKED'},
    {'label': 'Assigned', 'value': 'RIDER_ASSIGNED'},
    {'label': 'On the Way', 'value': 'OUT_FOR_DELIVERY'},
    {'label': 'Delivered', 'value': 'DELIVERED'},
    {'label': 'Cancelled', 'value': 'CANCELLED'},
  ];

  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _loadError;
  String? _selectedStatus;
  DateTimeRange? _selectedDateRange;
  String? _assigningOrderId;
  String? _updatingOrderId;
  final Set<int> _unassignedOrderIds = {};

  @override
  void initState() {
    super.initState();
    _loadOrders();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupNewOrderAlerts();
      _setupSocketListeners();
    });
  }

  @override
  void dispose() {
    _socketReloadDebounce?.cancel();
    _socketService.offNewOrder();
    _socketService.offAdminOrderUpdate();
    _socketService.offAssignmentFailed();
    _alertController?.dispose();
    super.dispose();
  }

  void _setupNewOrderAlerts() {
    if (!mounted) return;

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    _alertController = AdminNewOrderAlertController(
      overlayState: overlay,
      onTap: (_) => _debouncedReloadOrders(),
    );
  }

  Future<void> _setupSocketListeners() async {
    await _socketService.connect();
    _socketService.onNewOrder(_handleNewOrder);
    _socketService.onAdminOrderUpdate(_onOrderUpdatedSocketEvent);
    _socketService.onAssignmentFailed(_handleAssignmentFailed);
  }

  void _handleAssignmentFailed(dynamic data) {
    if (!mounted) return;

    final alert = AssignmentFailedAlertData.fromSocket(data);
    if (alert.orderId == 0) return;

    setState(() {
      _unassignedOrderIds.add(alert.orderId);
    });
    _debouncedReloadOrders();
  }

  void _handleNewOrder(dynamic data) {
    if (!mounted) return;

    final alert = NewOrderAlertData.fromSocket(data);
    if (alert.orderId > 0) {
      _alertController?.enqueue(alert);
    }

    _debouncedReloadOrders();
  }

  void _onOrderUpdatedSocketEvent(dynamic _) {
    if (!mounted) return;
    _debouncedReloadOrders();
  }

  void _debouncedReloadOrders() {
    _socketReloadDebounce?.cancel();
    _socketReloadDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) _loadOrders(showLoading: false);
    });
  }

  void _syncUnassignedWarnings(List<Map<String, dynamic>> orders) {
    if (_unassignedOrderIds.isEmpty) return;

    final assignedOrderIds = <int>{};
    for (final order in orders) {
      final orderId = int.tryParse(order['id']?.toString() ?? '');
      if (orderId == null) continue;
      if (_orderHasAssignment(order)) {
        assignedOrderIds.add(orderId);
      }
    }

    _unassignedOrderIds.removeWhere(assignedOrderIds.contains);
  }

  bool _orderHasAssignment(Map<String, dynamic> order) {
    final assignmentData = order['assignment'];
    if (assignmentData is List) return assignmentData.isNotEmpty;
    if (assignmentData is Map<String, dynamic>) return assignmentData.isNotEmpty;
    return false;
  }

  bool _isUnassignedOrder(dynamic orderId) {
    final parsed = int.tryParse(orderId?.toString() ?? '');
    return parsed != null && _unassignedOrderIds.contains(parsed);
  }

  Future<void> _loadOrders({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      final orders = await _adminService.getAllOrders(
        status: _selectedStatus,
        fromDate: _selectedDateRange?.start,
        toDate: _selectedDateRange?.end,
      );

      if (!mounted) return;
      debugPrint('AdminOrdersScreen: loaded ${orders.length} orders');
      setState(() {
        _orders = orders;
        _isLoading = false;
        _loadError = null;
        _syncUnassignedWarnings(orders);
      });
    } catch (e, stackTrace) {
      debugPrint('AdminOrdersScreen: failed to load orders: $e');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = BackendResolver.toUserMessage(
          e,
          fallback: 'Could not load orders.',
        );
        _orders = [];
      });
    }
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _selectedDateRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month, now.day - 7),
            end: now,
          ),
    );

    if (picked != null) {
      setState(() => _selectedDateRange = picked);
      await _loadOrders();
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedStatus = null;
      _selectedDateRange = null;
    });
    _loadOrders();
  }

  Future<void> _assignRider(String orderId, String riderId) async {
    setState(() => _assigningOrderId = orderId);
    try {
      await _adminService.assignRiderToOrder(orderId, riderId);
      if (!mounted) return;
      final parsedOrderId = int.tryParse(orderId);
      if (parsedOrderId != null) {
        setState(() => _unassignedOrderIds.remove(parsedOrderId));
      }
      Navigator.of(context).pop(); // Close sheet
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rider assigned successfully'),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to assign rider: $e'),
          backgroundColor: AppColors.primary,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _assigningOrderId = null);
      }
    }
  }

  Future<void> _showAssignRiderSheet(Map<String, dynamic> order) async {
    try {
      final riders = await _adminService.getAvailableRiders();
      if (!mounted) return;

      if (riders.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No available riders at the moment'),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) {
          return Padding(
            padding: modalSheetInsets(context, horizontal: 16, top: 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  'Assign Rider',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (_, index) {
                      final rider = riders[index];
                      final user = rider['user'] as Map<String, dynamic>? ?? {};
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor:
                              AppColors.primaryHover.withValues(alpha: 0.2),
                          child: const Icon(
                            Icons.delivery_dining,
                            color: AppColors.primary,
                          ),
                        ),
                        title: Text(user['name'] ?? 'Rider'),
                        subtitle: Text(user['phone'] ?? 'N/A'),
                        trailing: _assigningOrderId == order['id']
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              )
                            : TextButton(
                                onPressed: () =>
                                    _assignRider(order['id'], rider['id']),
                                child: const Text('Assign'),
                              ),
                      );
                    },
                    separatorBuilder: (_, __) => const Divider(height: 0),
                    itemCount: riders.length,
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load riders: $e'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  Future<void> _confirmCancelOrder(String orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text(
          'This will cancel the order and notify the assigned delivery partner.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Back'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _updatingOrderId = orderId);
    try {
      await _adminService.cancelOrder(orderId);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Order cancelled'),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadOrders();
    } catch (e) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to cancel order: $e'),
          backgroundColor: AppColors.primary,
        ),
      );
    } finally {
      if (mounted) setState(() => _updatingOrderId = null);
    }
  }

  Future<void> _confirmStatusUpdate(
    String orderId,
    String status,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Order Status'),
        content: Text('Change status to ${_formatStatus(status)}?'),
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
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _updateOrderStatus(orderId, status);
    }
  }

  Future<void> _updateOrderStatus(String orderId, String status) async {
    Map<String, dynamic>? existingOrder;
    for (final candidate in _orders) {
      if ((candidate['id'] ?? '').toString() == orderId) {
        existingOrder = candidate;
        break;
      }
    }
    if (existingOrder != null &&
        !_adminService.canAdminTransitionOrderStatus(
          (existingOrder['status'] ?? '').toString(),
          status,
        )) {
      if (!mounted) return;
      final current = _formatStatus(existingOrder['status']);
      final next = _formatStatus(status);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot change order from $current to $next'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (existingOrder != null &&
        _adminService.isSameBackendOrderStatus(
          status,
          (existingOrder['status'] ?? '').toString(),
        )) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order is already ${_formatStatus(existingOrder['status'])}',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _updatingOrderId = orderId);
    try {
      await _adminService.updateOrderStatus(orderId, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order marked as ${_formatStatus(status)}'),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: AppColors.primary,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingOrderId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.greyLight,
      drawer: AdminNavigationDrawer(
        currentSection: AdminNavSection.orders,
        onLogout: () => AdminNavigationDrawer.confirmLogout(context),
      ),
      appBar: AppBar(
        title: const Text('Manage Orders'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          if (_selectedStatus != null || _selectedDateRange != null)
            TextButton(
              onPressed: _clearFilters,
              child: const Text('Clear Filters'),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildFilterSection(),
          const SizedBox(height: 16),
          ...List.generate(4, (_) => const OrderCardSkeleton()),
        ],
      );
    }

    if (_loadError != null) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _buildFilterSection(),
          ),
          Expanded(
            child: ErrorStateWidget(
              title: 'Unable to load orders',
              message: _loadError,
              icon: Icons.error_outline_rounded,
              iconColor: AppColors.primary,
              onRetry: _loadOrders,
            ),
          ),
        ],
      );
    }

    if (_orders.isEmpty) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _buildFilterSection(),
          ),
          Expanded(
            child: EmptyStateWidget(
              title: _selectedStatus != null || _selectedDateRange != null
                  ? 'No orders found'
                  : 'No orders yet',
              message: _selectedStatus != null || _selectedDateRange != null
                  ? 'Try changing the status or date filters.'
                  : 'Orders will appear here once customers start placing them.',
              illustration: const Icon(
                Icons.receipt_long,
                size: 64,
                color: AppColors.textSecondary,
              ),
              buttonLabel: 'Refresh',
              onAction: _loadOrders,
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _orders.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              children: [
                _buildFilterSection(),
                const SizedBox(height: 16),
              ],
            );
          }
          return _buildOrderCard(_orders[index - 1]);
        },
      ),
    );
  }

  Widget _buildFilterSection() {
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
              'Filters',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _statusFilters.map((filter) {
                final isSelected = _selectedStatus == filter['value'];
                return ChoiceChip(
                  label: Text(filter['label'] ?? ''),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      _selectedStatus = filter['value'];
                    });
                    _loadOrders();
                  },
                  selectedColor: AppColors.primary.withValues(alpha: 0.1),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectDateRange,
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _selectedDateRange == null
                          ? 'Select Date Range'
                          : '${DateFormat('MMM d').format(_selectedDateRange!.start)} - ${DateFormat('MMM d').format(_selectedDateRange!.end)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final user = order['user'] as Map<String, dynamic>? ?? {};
    final items = (order['items'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final createdAt = DateTime.tryParse(order['created_at'] ?? '') ??
        DateTime.now();
    final assignmentData = order['assignment'];

    Map<String, dynamic>? assignment;
    if (assignmentData is List && assignmentData.isNotEmpty) {
      assignment = Map<String, dynamic>.from(assignmentData.first);
    } else if (assignmentData is Map<String, dynamic>) {
      assignment = Map<String, dynamic>.from(assignmentData);
    }

    final rider = assignment?['rider'] as Map<String, dynamic>? ?? {};
    final riderUser = rider['user'] as Map<String, dynamic>? ?? {};

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.divider, width: 1),
      ),
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Order #${order['id'] ?? ''}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (_isUnassignedOrder(order['id']))
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.warning.withValues(alpha: 0.5),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    size: 14,
                                    color: AppColors.warning,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'No rider',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${user['name'] ?? 'Customer'} • ${user['phone'] ?? 'N/A'}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _dateFormat.format(createdAt.toLocal()),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            _statusColor(order['status']).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _formatStatus(order['status']),
                        style: TextStyle(
                          color: _statusColor(order['status']),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '₹${_formatAmount(order['total_price'])}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Items',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    items.map((item) {
                      final product =
                          item['product'] as Map<String, dynamic>? ?? {};
                      final productName =
                          product['name'] ?? item['name'] ?? 'Product';
                      final quantity = item['quantity'] ?? 1;
                      return '$productName x$quantity';
                    }).take(3).join(', '),
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  if (items.length > 3)
                    Text(
                      '+ ${items.length - 3} more items',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
              ),
            if (assignment != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.delivery_dining,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            riderUser['name'] ?? 'Assigned Rider',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            riderUser['phone'] ?? 'N/A',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            'Status: ${_formatStatus(assignment['status'])}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showAssignRiderSheet(order),
                  icon: Icon(
                    assignment == null ? Icons.delivery_dining : Icons.swap_horiz,
                  ),
                  label: Text(
                    assignment == null ? 'Assign Rider' : 'Reassign Rider',
                  ),
                  style: _actionButtonStyle(),
                ),
                if (!_isCancelled(order['status']))
                  OutlinedButton.icon(
                    onPressed: _updatingOrderId == order['id']
                        ? null
                        : () => _confirmCancelOrder(order['id']),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel'),
                    style: _actionButtonStyle(foreground: AppColors.primary),
                  ),
                if (_updatingOrderId == order['id'])
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                else
                  Builder(
                    builder: (context) {
                      final currentStatus =
                          (order['status'] ?? '').toString();
                      final validTargets = _adminService
                          .validAdminStatusTargets(currentStatus);

                      if (validTargets.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      final nextStatus = validTargets.first;
                      final actionLabel =
                          _adminService.adminStatusActionLabel(nextStatus);

                      return OutlinedButton.icon(
                        onPressed: _updatingOrderId == order['id']
                            ? null
                            : () => _confirmStatusUpdate(
                                  order['id'],
                                  nextStatus,
                                ),
                        icon: const Icon(Icons.arrow_forward, size: 18),
                        label: Text(actionLabel),
                        style: _actionButtonStyle(),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _normalizedStatus(dynamic status) =>
      status?.toString().trim().toLowerCase() ?? '';

  bool _isCancelled(dynamic status) =>
      _normalizedStatus(status) == 'cancelled';

  ButtonStyle _actionButtonStyle({Color? foreground}) {
    return OutlinedButton.styleFrom(
      foregroundColor: foreground,
      minimumSize: const Size(0, 44),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  String _formatStatus(String? status) {
    final normalized = _normalizedStatus(status);
    if (normalized.isEmpty) return 'Unknown';
    return normalized
        .split('_')
        .map((part) =>
            part.isEmpty ? part : part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  String _formatAmount(dynamic amount) {
    if (amount == null) return '0';
    if (amount is num) return amount.toStringAsFixed(2);
    return double.tryParse(amount.toString())?.toStringAsFixed(2) ?? '0';
  }

  Color _statusColor(String? status) {
    switch (_normalizedStatus(status)) {
      case 'placed':
        return Colors.blue;
      case 'packed':
        return AppColors.warning;
      case 'accepted':
        return Colors.blue;
      case 'assigned':
        return AppColors.warning;
      case 'on_way':
        return Colors.blue;
      case 'delivered':
        return AppColors.success;
      case 'cancelled':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }
}

