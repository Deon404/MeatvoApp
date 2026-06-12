import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/order_model.dart';
import '../../services/rider_service.dart';
import '../../services/rider_location_service.dart';
import '../../services/socket_service.dart';
import '../../services/maps_service.dart';
import '../../core/constants/app_constants.dart';
import '../../utils/address_display_util.dart';
import '../../utils/order_display_util.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/maps/rider_location_tracker.dart';
import '../../widgets/maps/rider_navigation_map.dart';

/// Rider Order Detail Screen - Detailed view with actions for a single order assignment
class RiderOrderDetailScreen extends StatefulWidget {
  final String assignmentId;

  const RiderOrderDetailScreen({
    super.key,
    required this.assignmentId,
  });

  @override
  State<RiderOrderDetailScreen> createState() =>
      _RiderOrderDetailScreenState();
}

class _RiderOrderDetailScreenState extends State<RiderOrderDetailScreen> {
  final RiderService _riderService = RiderService();
  final RiderLocationService _locationService = RiderLocationService();
  final SocketService _socketService = SocketService();
  final MapsService _mapsService = MapsService();
  Map<String, dynamic>? _assignment;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
    _setupSocketListeners();
  }

  Future<void> _setupSocketListeners() async {
    try {
      await _socketService.connect();
      _socketService.on('order:assignment_cancelled', (data) {
        if (!mounted) return;
        final cancelledOrderId =
            data is Map ? data['orderId']?.toString() : null;
        if (cancelledOrderId == null ||
            cancelledOrderId != _getActualOrderId()) {
          return;
        }

        _locationService.stopSendingLocation();
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Order Cancelled'),
            content: const Text('Customer has cancelled this order.'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC8102E),
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      });
    } catch (e) {
      debugPrint('[RiderOrderDetail] Socket setup failed: $e');
    }
  }

  @override
  void dispose() {
    _socketService.off('order:assignment_cancelled');
    _locationService.stopSendingLocation();
    super.dispose();
  }

  String _orderIdFromAssignment() {
    final order = _assignment?['order'] as Map<String, dynamic>?;
    final orderId = order?['id']?.toString();
    debugPrint('[RiderOrderDetail] Assignment ID: ${widget.assignmentId}, Order ID: $orderId');
    return orderId ?? widget.assignmentId;
  }
  
  String _getActualOrderId() {
    final order = _assignment?['order'] as Map<String, dynamic>?;
    return order?['id']?.toString() ?? widget.assignmentId;
  }

  OrderModel? _getOrderModel() {
    final order = _assignment?['order'] as Map<String, dynamic>?;
    if (order == null) return null;
    try {
      return OrderModel.fromJson(order);
    } catch (e) {
      debugPrint('Error converting assignment to OrderModel: $e');
      return null;
    }
  }

  bool _shouldTrackLocation() {
    final assignmentStatus =
        (_assignment?['status'] as String? ?? '').toLowerCase();
    final order = _assignment?['order'] as Map<String, dynamic>?;
    final orderStatus = (order?['status'] as String? ?? '').toLowerCase();

    if (assignmentStatus == 'delivered' ||
        orderStatus == 'delivered' ||
        orderStatus == 'cancelled') {
      return false;
    }

    return assignmentStatus == 'accepted' || orderStatus == 'out_for_delivery';
  }

  void _syncLocationTracking() {
    if (_shouldTrackLocation()) {
      _locationService.startSendingLocation(_orderIdFromAssignment());
    } else {
      _locationService.stopSendingLocation();
    }
  }

  String _resolveOrderStatus(Map<String, dynamic>? order) {
    if (order == null) return 'placed';
    final raw = order['status'] ?? order['order_status'];
    if (raw == null || raw.toString().trim().isEmpty) return 'placed';
    return raw
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll('-', '_');
  }

  Future<void> _loadOrderDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final assignment =
          await _riderService.getOrderAssignment(widget.assignmentId);
      if (mounted) {
        setState(() {
          _assignment = assignment;
          _isLoading = false;
        });
        _syncLocationTracking();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load order details: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _acceptOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Order'),
        content: const Text('Are you sure you want to accept this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      final orderId = _getActualOrderId();
      debugPrint('[RiderOrderDetail] Accepting order: $orderId');
      await _riderService.acceptOrder(orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order accepted successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        await _loadOrderDetails();
        _syncLocationTracking();
      }
    } catch (e) {
      debugPrint('[RiderOrderDetail] Accept error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _rejectOrder() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejecting this order:'),
            SizedBox(height: R.sh(2, context)),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Enter rejection reason...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true || reasonController.text.trim().isEmpty) return;

    setState(() => _isProcessing = true);
    try {
      final orderId = _getActualOrderId();
      debugPrint('[RiderOrderDetail] Rejecting order: $orderId');
      await _riderService.rejectOrder(orderId, reasonController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order rejected'),
            backgroundColor: AppColors.warning,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('[RiderOrderDetail] Reject error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _markPickedUp() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Picked Up'),
        content: const Text('Have you collected all items from the store?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Picked Up'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      final orderId = _getActualOrderId();
      debugPrint('[RiderOrderDetail] Marking picked up: $orderId');
      await _riderService.markOrderPickedUp(orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order marked as picked up'),
            backgroundColor: AppColors.success,
          ),
        );
        await _loadOrderDetails();
        _syncLocationTracking();
      }
    } catch (e) {
      debugPrint('[RiderOrderDetail] Mark picked up error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _markOnTheWay() async {
    setState(() => _isProcessing = true);
    try {
      final orderId = _getActualOrderId();
      debugPrint('[RiderOrderDetail] Marking on the way: $orderId');
      await _riderService.markOrderOnTheWay(orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order marked as on the way'),
            backgroundColor: AppColors.success,
          ),
        );
        await _loadOrderDetails();
        _syncLocationTracking();
      }
    } catch (e) {
      debugPrint('[RiderOrderDetail] Mark on the way error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _markDelivered() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(Icons.check_circle,
                color: AppColors.success, size: 24),
            SizedBox(width: R.sw(2, context)),
            const Text('Confirm Delivery'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Have you successfully delivered this order to the customer?',
              style: TextStyle(fontSize: R.fontSize(14, context)),
            ),
            SizedBox(height: R.sh(1.5, context)),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                fontSize: R.fontSize(12, context),
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Confirm Delivery'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: R.sw(4, context),
                vertical: R.sh(1.5, context),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      final orderId = _getActualOrderId();
      debugPrint('[RiderOrderDetail] Marking delivered: $orderId');
      await _riderService.markOrderDelivered(orderId);
      _locationService.stopSendingLocation();
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 50,
                  ),
                ),
                SizedBox(height: R.sh(2, context)),
                Text(
                  'Order Delivered!',
                  style: TextStyle(
                    fontSize: R.fontSize(20, context),
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
                SizedBox(height: R.sh(1, context)),
                Text(
                  'Order has been marked as delivered successfully.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: R.fontSize(14, context),
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: R.sh(3, context)),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                          vertical: R.sh(1.5, context)),
                    ),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        );
        await _loadOrderDetails();
      }
    } catch (e) {
      debugPrint('[RiderOrderDetail] Mark delivered error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark as delivered: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFFAF9F7),
      appBar: AppBar(
        title: Text('Order #${formatOrderDisplayId(widget.assignmentId)}'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFC8102E),
                ),
              )
            : _errorMessage != null
                ? _buildErrorState()
                : _assignment == null
                    ? _buildEmptyState()
                    : Column(
                        children: [
                          Expanded(
                            child: RefreshIndicator(
                              onRefresh: _loadOrderDetails,
                              color: const Color(0xFFC8102E),
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildTopCard(),
                                    const SizedBox(height: 12),
                                    _buildAddressCard(),
                                    const SizedBox(height: 12),
                                    _buildPaymentCard(),
                                    const SizedBox(height: 12),
                                    _buildOrderItemsCard(),
                                    const SizedBox(height: 12),
                                    _buildNavigateButton(),
                                    const SizedBox(height: 80),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          _buildStickyBottom(),
                        ],
                      ),
      ),
    );
  }

  Widget _buildTopCard() {
    final status = _assignment?['status'] as String? ?? 'assigned';
    final order = _assignment?['order'] as Map<String, dynamic>?;
    final orderId = order?['id']?.toString() ?? widget.assignmentId;
    final user = order?['user'] as Map<String, dynamic>?;
    final customerName = (user?['name'] ??
            order?['customerName'] ??
            order?['customer_name'])
        ?.toString()
        .trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Ongoing Trip',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B6B6B),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFC8102E).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFC8102E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '#${formatOrderDisplayId(orderId)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          if (customerName != null && customerName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              customerName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddressCard() {
    final order = _assignment?['order'] as Map<String, dynamic>?;
    if (order == null) return const SizedBox.shrink();

    final user = order['user'] as Map<String, dynamic>?;
    final customerPhone = (user?['phone'] ?? order['customer_phone'] ?? order['phone'] ?? '').toString().trim();
    final storePhone = '1800-XXX-XXXX';
    final rawAddressData = order['delivery_address'] ?? order['address'];
    final deliveryAddress = formatAddressForDisplay(rawAddressData);
    final storeAddress = 'Meatvo Store, Main Branch';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.radio_button_checked,
                  color: Color(0xFFE65100),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pickup Address',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B6B6B),
                      ),
                    ),
                    Text(
                      storeAddress,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => launchUrl(Uri.parse('tel:$storePhone')),
                icon: const Icon(
                  Icons.call,
                  color: Color(0xFFC8102E),
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 18, top: 8, bottom: 8),
            child: Row(
              children: List.generate(
                20,
                (index) => Expanded(
                  child: Container(
                    height: 1,
                    color: index.isEven ? const Color(0xFFEEEEEE) : Colors.transparent,
                  ),
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Color(0xFF2ECC71),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Delivery Address',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B6B6B),
                      ),
                    ),
                    Text(
                      deliveryAddress,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (customerPhone.isNotEmpty)
                IconButton(
                  onPressed: () => launchUrl(Uri.parse('tel:$customerPhone')),
                  icon: const Icon(
                    Icons.call,
                    color: Color(0xFFC8102E),
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard() {
    final order = _assignment?['order'] as Map<String, dynamic>?;
    if (order == null) return const SizedBox.shrink();

    final paymentMethod = order['payment_method'] as String? ?? 'cod';
    final isCOD = paymentMethod.toLowerCase() == 'cod';
    final totalAmount = (order['total_price'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Method',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B6B6B),
                      ),
                    ),
                    Text(
                      isCOD ? 'Cash on Delivery' : 'Online Payment',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
              ),
              if (isCOD)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Collect Cash',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE65100),
                    ),
                  ),
                ),
            ],
          ),
          if (isCOD) ...[
            const SizedBox(height: 8),
            const Text(
              'Please collect from customer',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B6B6B),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '₹${totalAmount.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFFC8102E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemsCard() {
    final order = _assignment?['order'] as Map<String, dynamic>?;
    final items = order?['items'] as List<dynamic>? ?? [];

    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Items',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          ...items.map((item) => _buildOrderItemRow(item as Map<String, dynamic>)),
        ],
      ),
    );
  }

  Widget _buildOrderItemRow(Map<String, dynamic> item) {
    final product = item['product'] as Map<String, dynamic>?;
    final productName = product?['name'] as String? ??
        item['product_name'] as String? ??
        'Product';
    final quantity = (item['quantity'] as num?)?.round() ?? 0;
    final itemPrice = (item['item_price'] as num?)?.toDouble() ?? 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              productName,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
          Text(
            '${quantity}x',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B6B6B),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '₹${itemPrice.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigateButton() {
    final order = _assignment?['order'] as Map<String, dynamic>?;
    final coords = resolveAddressCoords(order);

    if (coords.lat == null || coords.lng == null) {
      return const SizedBox.shrink();
    }

    return OutlinedButton.icon(
      onPressed: () => _mapsService.launchNavigation(coords.lat!, coords.lng!),
      icon: const Icon(
        Icons.navigation,
        color: Color(0xFFC8102E),
        size: 20,
      ),
      label: const Text(
        'Open Navigation',
        style: TextStyle(
          color: Color(0xFFC8102E),
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFC8102E)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        minimumSize: const Size(double.infinity, 48),
      ),
    );
  }

  Widget _buildStickyBottom() {
    final status = _assignment?['status'] as String? ?? 'assigned';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: _buildActionButtonsNew(status),
      ),
    );
  }

  Widget _buildActionButtonsNew(String status) {
    if (status == 'assigned') {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isProcessing ? null : _rejectOrder,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFC8102E)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _isProcessing ? 'Processing...' : 'Reject',
                style: const TextStyle(
                  color: Color(0xFFC8102E),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _acceptOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC8102E),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _isProcessing ? 'Processing...' : 'Accept',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      );
    } else if (status == 'accepted') {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isProcessing ? null : _markPickedUp,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFC8102E)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _isProcessing ? 'Processing...' : 'Mark Picked Up',
                style: const TextStyle(
                  color: Color(0xFFC8102E),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _markDelivered,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC8102E),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _isProcessing ? 'Processing...' : 'Mark Delivered',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      );
    } else if (status == 'picked_up') {
      return ElevatedButton(
        onPressed: _isProcessing ? null : _markDelivered,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFC8102E),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(double.infinity, 50),
        ),
        child: Text(
          _isProcessing ? 'Processing...' : 'Mark Delivered',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else if (status == 'delivered') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Color(0xFF2ECC71),
              size: 24,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delivered Successfully',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2ECC71),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildNavigationDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.delivery_dining,
                  size: 48,
                  color: Colors.white,
                ),
                SizedBox(height: 12),
                Text(
                  'Delivery Partner',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Active Orders'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet),
            title: const Text('Earnings'),
            onTap: () {
              Navigator.pop(context);
              // Navigate to earnings screen if available
            },
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile'),
            onTap: () {
              Navigator.pop(context);
              // Navigate to profile screen if available
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              // Navigate to settings screen if available
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () {
              Navigator.pop(context);
              // Handle logout
            },
          ),
        ],
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
              'Error Loading Order',
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
              onPressed: _loadOrderDetails,
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
      child: Text('Order not found'),
    );
  }









}
