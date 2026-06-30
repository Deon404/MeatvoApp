import 'package:flutter/material.dart';
import '../../models/order_model.dart';
import '../../services/rider_service.dart';
import '../../services/rider_location_service.dart';
import '../../services/socket_service.dart';
import '../../services/maps_service.dart';
import '../../services/contact_action_service.dart';
import '../../core/constants/app_constants.dart';
import '../../config/store_config.dart';
import '../../utils/address_display_util.dart';
import '../../utils/order_display_util.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/maps/rider_location_tracker.dart';
import '../../widgets/maps/rider_navigation_map.dart';
import 'batch_delivery_screen.dart';
import 'widgets/delivery_otp_dialog.dart';

/// Rider Order Detail Screen - Detailed view with actions for a single order assignment
class RiderOrderDetailScreen extends StatefulWidget {
  final String assignmentId;
  final List<String>? batchOrderIds;

  const RiderOrderDetailScreen({
    super.key,
    required this.assignmentId,
    this.batchOrderIds,
  });

  @override
  State<RiderOrderDetailScreen> createState() =>
      _RiderOrderDetailScreenState();
}

class _RiderOrderDetailScreenState extends State<RiderOrderDetailScreen> {
  final RiderService _riderService = RiderService();
  final SocketService _socketService = SocketService();
  final MapsService _mapsService = MapsService();
  final ContactActionService _contactService = ContactActionService();
  final RiderLocationService _locationService = RiderLocationService();
  Map<String, dynamic>? _assignment;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isProcessing = false;
  bool _isCancelDialogShowing = false;

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
        if (_isCancelDialogShowing) return;
        if (!mounted) return;
        final cancelledOrderId =
            data is Map ? data['orderId']?.toString() : null;
        if (cancelledOrderId == null ||
            cancelledOrderId != _getActualOrderId()) {
          return;
        }

        _locationService.stopSendingLocation();
        _isCancelDialogShowing = true;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Order Cancelled'),
            content: const Text('Customer has cancelled this order.'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  _isCancelDialogShowing = false;
                  Navigator.of(dialogContext, rootNavigator: true).pop();
                  if (mounted) {
                    Navigator.of(context, rootNavigator: true).pop();
                  }
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

  Future<void> _loadOrderDetails({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final assignment = await _riderService.getOrderAssignment(
        widget.assignmentId,
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _assignment = assignment;
          _isLoading = false;
        });
        _syncLocationTracking();
      }
    } catch (e) {
      if (!mounted) return;
      if (e is OrderNoLongerAvailableException) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.of(context).pop();
        });
      } else {
        setState(() {
          _errorMessage = _friendlyLoadError(e);
          _isLoading = false;
        });
      }
    }
  }

  String _friendlyLoadError(Object error) {
    final message = error.toString();
    if (message.contains('429') || message.toLowerCase().contains('too many requests')) {
      return 'Server is busy (too many requests). Please wait a few seconds and tap Retry.';
    }
    if (message.contains('Not allowed') || message.contains('not assigned')) {
      return 'You do not have access to this order. It may have been reassigned or is still being prepared.';
    }
    return 'Failed to load order details: $error';
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

    final orderId = _getActualOrderId();
    final ready = await _riderService.isOrderReadyForAccept(
      orderId,
      forceRefresh: true,
    );
    if (!ready && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This order is still being prepared. You can accept it once it is packed.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final batchIds = widget.batchOrderIds
          ?.map((id) => id.toString())
          .where((id) => id.isNotEmpty)
          .toList();
      final isBatch = batchIds != null && batchIds.length > 1;

      if (isBatch) {
        debugPrint('[RiderOrderDetail] Accepting batch: $batchIds');
        await _riderService.acceptOrders(batchIds);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${batchIds.length} orders accepted!'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => BatchDeliveryScreen(orderIds: batchIds),
            ),
          );
        }
        return;
      }

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

  Future<void> _markFailedDelivery() async {
    const reasons = <Map<String, String>>[
      {'value': 'CUSTOMER_UNREACHABLE', 'label': 'Customer Unreachable'},
      {'value': 'WRONG_ADDRESS', 'label': 'Wrong Address'},
      {'value': 'CUSTOMER_REFUSED', 'label': 'Customer Refused'},
    ];

    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Failed Delivery'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons
              .map(
                (r) => ListTile(
                  title: Text(r['label']!),
                  onTap: () => Navigator.pop(context, r['value']),
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selected == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Failed Delivery'),
        content: const Text(
          'Mark this order as failed? You must return the package to the store before the manager can resolve it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      await _riderService.markFailedDelivery(_getActualOrderId(), selected);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed delivery recorded. Return to store.'),
            backgroundColor: AppColors.warning,
          ),
        );
        await _loadOrderDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _reportOperationalException(String exceptionType, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: Text(
          'Report "$label" to the store manager? Your delivery will not be cancelled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Report'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      await _riderService.reportOperationalException(
        _getActualOrderId(),
        exceptionType,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label reported to admin'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Widget _buildOperationalExceptionButtons() {
    return Column(
      children: [
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isProcessing
                    ? null
                    : () => _reportOperationalException(
                          'DELAYED_VEHICLE',
                          'Delayed (vehicle issue)',
                        ),
                child: const Text(
                  'Delayed',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _isProcessing
                    ? null
                    : () => _reportOperationalException(
                          'COLD_CHAIN_ISSUE',
                          'Cold Chain Issue',
                        ),
                child: const Text(
                  'Cold Chain',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _isProcessing
                    ? null
                    : () => _reportOperationalException(
                          'NEED_ASSISTANCE',
                          'Need Assistance',
                        ),
                child: const Text(
                  'Assistance',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmReturnToStore() async {
    const conditions = <Map<String, String>>[
      {'value': 'RESELLABLE', 'label': 'Resellable — product is still good'},
      {'value': 'PARTIAL_SPOILAGE', 'label': 'Partial spoilage'},
      {'value': 'DISCARD', 'label': 'Discard — not safe to resell'},
    ];

    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Return to Store'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Confirm you have returned the package to the store.'),
            const SizedBox(height: 12),
            ...conditions.map(
              (c) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(c['label']!),
                onTap: () => Navigator.pop(context, c['value']),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selected == null) return;

    setState(() => _isProcessing = true);
    try {
      await _riderService.confirmReturnToStore(_getActualOrderId(), selected);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Return to store confirmed'),
            backgroundColor: AppColors.success,
          ),
        );
        await _loadOrderDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to confirm return: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _markDelivered() async {
    final order = _assignment?['order'] as Map<String, dynamic>?;
    final paymentMethod = (order?['payment_method'] as String? ?? 'cod').toLowerCase();
    final isCOD = paymentMethod == 'cod';
    final totalAmount = (order?['total_price'] as num?)?.toDouble() ?? 0.0;

    if (isCOD) {
      final cashConfirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Collect Cash'),
          content: Text(
            'Confirm you collected ₹${totalAmount.toStringAsFixed(0)} in cash from the customer before marking delivered.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not yet'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              child: const Text('Cash Collected'),
            ),
          ],
        ),
      );
      if (!mounted || cashConfirmed != true) return;
    }

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

    if (!mounted || confirmed != true) return;

    final otp = await showDeliveryOtpDialog(context);
    if (!mounted || otp == null) return;

    setState(() => _isProcessing = true);
    try {
      final orderId = _getActualOrderId();
      debugPrint('[RiderOrderDetail] Marking delivered: $orderId');

      await _riderService.markOrderDelivered(orderId, otp: otp);
      _locationService.stopSendingLocation();
      if (!mounted) return;

      final done = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
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
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: R.sh(1.5, context)),
                  ),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      );

      if (!mounted) return;
      if (done == true) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('[RiderOrderDetail] Mark delivered error: $e');
      if (mounted) {
        final message = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message.isEmpty ? 'Failed to mark as delivered' : message),
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
    final resolvedStatus = _resolveActionStatus();
    final topLabel = resolvedStatus == 'preparing'
        ? 'Order Being Prepared'
        : 'Ongoing Trip';
    final badgeText = resolvedStatus == 'preparing'
        ? 'PREPARING'
        : status.replaceAll('_', ' ').toUpperCase();
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
              Text(
                topLabel,
                style: const TextStyle(
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
                  badgeText,
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

  Future<void> _handleContactCall(String phone) async {
    final success = await _contactService.makeCall(phone);
    if (!success && mounted && context.mounted) {
      _contactService.showContactError(context, 'call', phone);
    }
  }

  Future<void> _handleContactSms(String phone) async {
    final success = await _contactService.sendSMS(phone);
    if (!success && mounted && context.mounted) {
      _contactService.showContactError(context, 'message', phone);
    }
  }

  Widget _buildAddressCard() {
    final order = _assignment?['order'] as Map<String, dynamic>?;
    if (order == null) return const SizedBox.shrink();

    final user = order['user'] as Map<String, dynamic>?;
    final customerPhone = (user?['phone'] ?? order['customer_phone'] ?? order['phone'] ?? '').toString().trim();
    const String? storePhone = null; // No phone configured yet
    final rawAddressData = order['delivery_address'] ?? order['address'];
    final deliveryAddress = formatAddressForDisplay(rawAddressData);
    final storeAddress = StoreConfig.storeAddress;
    final storeName = StoreConfig.storeName;

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
                      storeName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
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
              if (storePhone != null)
                IconButton(
                  onPressed: () => _handleContactCall(storePhone),
                  icon: const Icon(
                    Icons.call,
                    color: Color(0xFFC8102E),
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              else
                const SizedBox.shrink(),
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _handleContactSms(customerPhone),
                      icon: const Icon(
                        Icons.message_outlined,
                        color: Color(0xFFC8102E),
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    IconButton(
                      onPressed: () => _handleContactCall(customerPhone),
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

  String _resolveActionStatus() {
    final assignmentStatus =
        (_assignment?['status'] as String? ?? 'assigned').toLowerCase();
    final order = _assignment?['order'] as Map<String, dynamic>?;
    final orderStatus = _resolveOrderStatus(order);

    if (orderStatus == 'failed_delivery') {
      final returnedAt = order?['returned_at'];
      if (returnedAt == null || returnedAt.toString().isEmpty) {
        return 'awaiting_return';
      }
      return 'return_confirmed';
    }

    if (orderStatus == 'on_the_way') return 'on_the_way';
    if (orderStatus == 'picked_up') return 'picked_up';
    if (orderStatus == 'out_for_delivery' && assignmentStatus == 'accepted') {
      return 'accepted';
    }
    if (assignmentStatus == 'assigned') {
      const inFlightStatuses = {
        'out_for_delivery',
        'picked_up',
        'on_the_way',
        'rider_nearby',
        'rider_accepted',
      };
      if (orderStatus == 'packed') {
        return assignmentStatus; // Ready to accept
      }
      if (!inFlightStatuses.contains(orderStatus)) {
        return 'preparing';
      }
    }
    return assignmentStatus;
  }

  Widget _buildStickyBottom() {
    final status = _resolveActionStatus();

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
    if (status == 'preparing') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFE082)),
            ),
            child: const Text(
              'This order is still being prepared at the store. You can accept it once it is packed.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B6B6B)),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _isProcessing ? null : _rejectOrder,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFC8102E)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _isProcessing ? 'Processing...' : 'Decline Assignment',
              style: const TextStyle(
                color: Color(0xFFC8102E),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

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
      return ElevatedButton(
        onPressed: _isProcessing ? null : _markPickedUp,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFC8102E),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(double.infinity, 50),
        ),
        child: Text(
          _isProcessing ? 'Processing...' : 'Mark Picked Up',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else if (status == 'picked_up' || status == 'on_the_way' || status == 'accepted') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (status == 'picked_up')
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isProcessing ? null : _markOnTheWay,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFC8102E)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _isProcessing ? 'Processing...' : 'On The Way',
                      style: const TextStyle(
                        color: Color(0xFFC8102E),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (status == 'picked_up') const SizedBox(width: 12),
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
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isProcessing ? null : _markFailedDelivery,
              icon: const Icon(Icons.error_outline, size: 18),
              label: const Text('Failed Delivery'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.warning,
                side: const BorderSide(color: AppColors.warning),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          _buildOperationalExceptionButtons(),
        ],
      );
    } else if (status == 'awaiting_return') {
      return ElevatedButton.icon(
        onPressed: _isProcessing ? null : _confirmReturnToStore,
        icon: const Icon(Icons.store, size: 20),
        label: Text(
          _isProcessing ? 'Processing...' : 'Confirm Return to Store',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.warning,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(double.infinity, 50),
        ),
      );
    } else if (status == 'return_confirmed') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warning),
        ),
        child: const Row(
          children: [
            Icon(Icons.store, color: AppColors.warning),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Returned to store. Waiting for manager to resolve.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
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
              onPressed: () => _loadOrderDetails(forceRefresh: true),
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
