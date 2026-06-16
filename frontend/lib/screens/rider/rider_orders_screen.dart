import 'package:flutter/material.dart';
import '../../services/rider_service.dart';
import '../../core/constants/app_constants.dart';
import '../../utils/address_display_util.dart';
import '../../utils/order_display_util.dart';
import '../../utils/responsive_helper.dart';
import 'rider_order_detail_screen.dart';

/// Rider Orders Screen - List of all rider orders with filters
class RiderOrdersScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final void Function(Future<void> Function() refresh)? onRegisterRefresh;

  const RiderOrdersScreen({
    super.key,
    this.onBack,
    this.onRegisterRefresh,
  });

  @override
  State<RiderOrdersScreen> createState() => _RiderOrdersScreenState();
}

class _RiderOrdersScreenState extends State<RiderOrdersScreen>
    with SingleTickerProviderStateMixin {
  final RiderService _riderService = RiderService();
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _filteredOrders = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedStatus;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadOrders();
    widget.onRegisterRefresh?.call(_loadOrders);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        switch (_tabController.index) {
          case 0:
            _selectedStatus = null;
            break;
          case 1:
            _selectedStatus = 'assigned';
            break;
          case 2:
            _selectedStatus = 'accepted';
            break;
          case 3:
            _selectedStatus = 'picked_up';
            break;
          case 4:
            _selectedStatus = 'delivered';
            break;
        }
        _applyFilter();
      });
    }
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final orders = await _riderService.getRiderOrders();
      if (mounted) {
        setState(() {
          _orders = List<Map<String, dynamic>>.from(orders);
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load orders: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilter() {
    setState(() {
      if (_selectedStatus == null) {
        _filteredOrders = _orders;
      } else {
        _filteredOrders = _orders.where((assignment) {
          final status = assignment['status'] as String?;
          return status == _selectedStatus;
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('My Orders'),
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.surface,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Assigned'),
            Tab(text: 'Accepted'),
            Tab(text: 'Picked Up'),
            Tab(text: 'Delivered'),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              )
            : _errorMessage != null
                ? _buildErrorState()
                : _filteredOrders.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadOrders,
                        color: AppColors.primary,
                        child: ListView.builder(
                          padding: EdgeInsets.all(R.sw(4, context)),
                          itemCount: _filteredOrders.length,
                          itemBuilder: (context, index) {
                            return _buildOrderCard(_filteredOrders[index]);
                          },
                        ),
                      ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> assignment) {
    final order = assignment['order'] as Map<String, dynamic>?;
    if (order == null) return const SizedBox.shrink();

    final status = assignment['status'] as String? ?? 'assigned';
    final orderTitle = riderOrderTitle(order);
    final customer = order['user'] as Map<String, dynamic>?;
    final customerPhone = (customer?['phone'] ?? order['phone'] ?? '')
        .toString()
        .trim();
    final deliveryAddress = formatAddressForDisplay(
      order['delivery_address'] ?? order['address'],
    );
    final hasCustomerName =
        customer?['name']?.toString().trim().isNotEmpty ?? false;
    final orderId = order['id'] as String;
    final totalPrice = (order['total_price'] as num?)?.toDouble() ?? 0.0;
    final orderStatus = order['status'] as String? ?? 'placed';
    final assignedAt = assignment['assigned_at'] as String?;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.divider, width: 1),
      ),
      margin: EdgeInsets.only(bottom: R.sh(1.5, context)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RiderOrderDetailScreen(
                assignmentId: assignment['id'] as String,
              ),
            ),
          ).then((_) => _loadOrders());
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(R.sw(4, context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          orderTitle,
                          style: TextStyle(
                            fontSize: R.fontSize(16, context),
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (hasCustomerName) ...[
                          SizedBox(height: R.sh(0.5, context)),
                          Text(
                            'Order #${formatOrderDisplayId(orderId)}',
                            style: TextStyle(
                              fontSize: R.fontSize(12, context),
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        if (deliveryAddress.isNotEmpty &&
                            deliveryAddress != 'Address not available') ...[
                          SizedBox(height: R.sh(0.5, context)),
                          Text(
                            deliveryAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: R.fontSize(12, context),
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        if (customerPhone.isNotEmpty) ...[
                          SizedBox(height: R.sh(0.5, context)),
                          Text(
                            customerPhone,
                            style: TextStyle(
                              fontSize: R.fontSize(12, context),
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: R.sw(2, context),
                      vertical: R.sh(0.5, context),
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getStatusLabel(status),
                      style: TextStyle(
                        fontSize: R.fontSize(12, context),
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(status),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: R.sh(1.5, context)),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${formatOrderDisplayId(orderId)}',
                          style: TextStyle(
                            fontSize: R.fontSize(12, context),
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (assignedAt != null) ...[
                          SizedBox(height: R.sh(0.5, context)),
                          Text(
                            _formatDate(assignedAt),
                            style: TextStyle(
                              fontSize: R.fontSize(11, context),
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    '₹${_formatCurrency(totalPrice)}',
                    style: TextStyle(
                      fontSize: R.fontSize(18, context),
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: R.sh(1, context)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: R.sw(2, context),
                  vertical: R.sh(0.5, context),
                ),
                decoration: BoxDecoration(
                  color:
                      _getOrderStatusColor(orderStatus).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _getOrderStatusLabel(orderStatus),
                  style: TextStyle(
                    fontSize: R.fontSize(11, context),
                    color: _getOrderStatusColor(orderStatus),
                  ),
                ),
              ),
              SizedBox(height: R.sh(1.5, context)),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RiderOrderDetailScreen(
                          assignmentId: assignment['id'] as String,
                        ),
                      ),
                    ).then((_) => _loadOrders());
                  },
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: Text(
                    'View Details',
                    style: TextStyle(fontSize: R.fontSize(14, context)),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ],
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
              'Error Loading Orders',
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
              onPressed: _loadOrders,
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
    return Center(
      child: Padding(
        padding: EdgeInsets.all(R.sw(6, context)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox,
              size: 64,
              color: AppColors.surface,
            ),
            SizedBox(height: R.sh(2, context)),
            Text(
              'No Orders Found',
              style: TextStyle(
                fontSize: R.fontSize(18, context),
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: R.sh(1, context)),
            Text(
              _selectedStatus == null
                  ? 'You don\'t have any orders assigned yet'
                  : 'No orders with status "${_getStatusLabel(_selectedStatus!)}"',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: R.fontSize(14, context),
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'assigned':
        return Colors.blue;
      case 'accepted':
        return AppColors.success;
      case 'picked_up':
        return AppColors.warning;
      case 'delivered':
        return AppColors.success;
      case 'cancelled':
        return Colors.red;
      default:
        return AppColors.surface;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'assigned':
        return 'Assigned';
      case 'accepted':
        return 'Accepted';
      case 'picked_up':
        return 'Picked Up';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status.toUpperCase();
    }
  }

  Color _getOrderStatusColor(String status) {
    switch (status) {
      case 'placed':
      case 'pending':
        return AppColors.surface;
      case 'accepted':
      case 'confirmed':
        return Colors.blue;
      case 'preparing':
        return AppColors.warning;
      case 'out_for_delivery':
      case 'on_way':
        return Colors.blue;
      case 'delivered':
        return AppColors.success;
      case 'cancelled':
        return Colors.red;
      default:
        return AppColors.surface;
    }
  }

  String _getOrderStatusLabel(String status) {
    switch (status) {
      case 'placed':
        return 'Order Placed';
      case 'accepted':
        return 'Accepted';
      case 'confirmed':
        return 'Confirmed';
      case 'preparing':
        return 'Preparing';
      case 'out_for_delivery':
        return 'Out for Delivery';
      case 'on_way':
        return 'On the Way';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(2);
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          return '${difference.inMinutes} minutes ago';
        }
        return '${difference.inHours} hours ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return dateString;
    }
  }
}
