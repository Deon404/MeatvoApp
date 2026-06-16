import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/order_model.dart';
import '../../features/tracking/order_tracking_subscription.dart';
import '../../services/order_service.dart';
import '../../services/socket_service.dart';
import '../../services/cart_service.dart';
import '../../services/payment_service.dart';
import '../../services/auth_service.dart';
import '../../core/constants/app_constants.dart';
import '../../utils/eta_display_util.dart';
import '../../utils/order_display_util.dart';
import '../../utils/order_status_util.dart';
import '../../utils/responsive_helper.dart';
import '../../services/maps_service.dart';
import '../../widgets/maps/delivery_tracking_map.dart';
import '../../widgets/order_status_live_indicator.dart';
import '../../widgets/delivery/delivery_partner_contact_card.dart';
import '../cart/cart_screen.dart';

/// Order Detail Screen - Detailed view of a single order
class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final OrderService _orderService = OrderService();
  final CartService _cartService = CartService();
  final PaymentService _paymentService = PaymentService();
  final AuthService _authService = AuthService();
  OrderModel? _order;
  OrderModel? _previousOrder; // Track previous order state for status change detection
  bool _isLoading = true;
  String? _errorMessage;
  bool _isCancelling = false;
  bool _isReordering = false;
  bool _isRetryingPayment = false;
  Map<String, dynamic>? _existingReview;
  bool _isLoadingReview = false;
  final OrderTrackingSubscription _tracking = OrderTrackingSubscription();
  final MapsService _mapsService = MapsService();
  double? _liveRiderLat;
  double? _liveRiderLng;
  double? _resolvedDeliveryLat;
  double? _resolvedDeliveryLng;
  String? _routeEta;
  String? _routeDistance;
  bool _showPartnerCardAnimation = false;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
    SocketService().connect();
    _listenToPartnerAcceptance();
  }

  void _listenToPartnerAcceptance() {
    SocketService().onPartnerAccepted((data) {
      if (!mounted) return;
      if (data['orderId']?.toString() == widget.orderId.toString()) {
        setState(() {
          _showPartnerCardAnimation = true;
        });
        _loadOrderDetails();
      }
    });
  }

  @override
  void dispose() {
    _tracking.dispose();
    _paymentService.dispose();
    super.dispose();
  }

  Future<void> _loadReview() async {
    if (_order?.status != 'delivered') return;

    setState(() => _isLoadingReview = true);
    try {
      final review = await _orderService.getOrderReview(widget.orderId);
      if (mounted) {
        setState(() {
          _existingReview = review;
          _isLoadingReview = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingReview = false);
      }
    }
  }

  Future<void> _loadOrderDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final order = await _orderService.getOrderById(widget.orderId);
      final deliveryCoords = await _resolveDeliveryCoordinates(order);
      if (mounted) {
        setState(() {
          _order = order;
          _liveRiderLat = order.riderLatitude;
          _liveRiderLng = order.riderLongitude;
          _resolvedDeliveryLat = deliveryCoords?['lat'];
          _resolvedDeliveryLng = deliveryCoords?['lng'];
          _isLoading = false;
        });
        _startTrackingIfActive(order);
        if (order.status == 'delivered') {
          _loadReview();
        }
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

  Future<Map<String, double>?> _resolveDeliveryCoordinates(
    OrderModel order,
  ) async {
    if (order.deliveryLatitude != null && order.deliveryLongitude != null) {
      return {
        'lat': order.deliveryLatitude!,
        'lng': order.deliveryLongitude!,
      };
    }

    final address = order.deliveryAddress?.trim();
    if (address == null || address.isEmpty) return null;

    try {
      final coords = await _mapsService.getCoordinatesFromAddress(address);
      if (coords == null) return null;
      final lat = coords['latitude'] ?? coords['lat'];
      final lng = coords['longitude'] ?? coords['lng'];
      if (lat == null || lng == null) return null;
      return {'lat': lat, 'lng': lng};
    } catch (_) {
      return null;
    }
  }

  bool _shouldShowTrackingMap() {
    if (_order == null) return false;
    if (!isOrderTrackable(_order!.status)) return false;
    return _resolvedDeliveryLat != null && _resolvedDeliveryLng != null;
  }

  void _startTrackingIfActive(OrderModel order) {
    final status = order.status.toLowerCase();
    if (status == 'delivered' || status == 'cancelled') {
      _tracking.stop();
      return;
    }
    _tracking.start(
      orderId: widget.orderId,
      onOrderUpdate: (updated) {
        if (!mounted) return;
        setState(() {
          _previousOrder = _order;
          _order = updated;
          if (_liveRiderLat == null && updated.riderLatitude != null) {
            _liveRiderLat = updated.riderLatitude;
            _liveRiderLng = updated.riderLongitude;
          }
        });
        if (updated.status == 'delivered') {
          _loadReview();
        }
      },
      onRiderLocation: (lat, lng) {
        if (!mounted) return;
        setState(() {
          _liveRiderLat = lat;
          _liveRiderLng = lng;
        });
      },
    );
  }

  Future<void> _cancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text(
          'Are you sure you want to cancel this order? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isCancelling = true;
    });

    try {
      await _orderService.cancelOrder(widget.orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order cancelled successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        await _loadOrderDetails();
      }
    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message.startsWith('Failed to cancel order')
                ? message
                : 'Failed to cancel order: $message'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCancelling = false;
        });
      }
    }
  }

  Future<void> _reorder() async {
    if (_order == null || _order!.items.isEmpty) return;

    setState(() {
      _isReordering = true;
    });

    try {
      // Add all order items to cart
      for (final item in _order!.items) {
        // Try to extract variant ID from order item if available
        // Note: OrderItem doesn't have variantId, so we'll add without variant
        // The cart service will handle it based on product_id
        await _cartService.addToCart(
          item.productId,
          item.quantity.round(),
          unit: item.unit,
          variantId: null, // Variant ID not available in OrderItem
        );
      }

      if (mounted) {
        setState(() {
          _isReordering = false;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Items added to cart successfully!'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate to cart screen
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CartScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isReordering = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add items to cart: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final showTrackingMap = !_isLoading &&
        _errorMessage == null &&
        _order != null &&
        _shouldShowTrackingMap();

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.warmBg,
      extendBodyBehindAppBar: false,
      appBar: showTrackingMap
          ? null
          : AppBar(
              title: Text('Order #${formatOrderDisplayId(widget.orderId)}'),
            ),
      body: SafeArea(
        top: !showTrackingMap,
        left: !showTrackingMap,
        right: !showTrackingMap,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : _errorMessage != null
                ? _buildErrorState()
                : _order == null
                    ? _buildEmptyState()
                    : showTrackingMap
                        ? _buildTrackingLayout()
                        : _buildStandardLayout(),
      ),
    );
  }

  Widget _buildStandardLayout() {
    final etaBanner = _buildEtaBanner();

    return RefreshIndicator(
      onRefresh: _loadOrderDetails,
      color: AppColors.primary,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + keyboardInset(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(),
            if (etaBanner != null) ...[
              const SizedBox(height: 12),
              etaBanner,
            ],
            const SizedBox(height: 16),
            if (_order!.riderId != null)
              DeliveryPartnerContactCard(
                order: _order!,
                showAnimation: _showPartnerCardAnimation,
                onRefresh: _loadOrderDetails,
              ),
            if (_order!.riderId != null) const SizedBox(height: 16),
            _buildOrderItems(),
            const SizedBox(height: 16),
            _buildDeliveryAddress(),
            const SizedBox(height: 16),
            _buildPriceBreakdown(),
            const SizedBox(height: 16),
            _buildPaymentDetailsSection(),
            const SizedBox(height: 16),
            if (_order!.status == 'delivered') ...[
              _buildReviewSection(),
              const SizedBox(height: 16),
            ],
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingLayout() {
    final etaBanner = _buildEtaBanner();

    return Column(
      children: [
        _buildTrackingHeader(),
        Expanded(
          flex: 52,
          child: DeliveryTrackingMap(
            expandToFill: true,
            riderLatitude: _liveRiderLat ?? _order!.riderLatitude,
            riderLongitude: _liveRiderLng ?? _order!.riderLongitude,
            deliveryLatitude: _resolvedDeliveryLat,
            deliveryLongitude: _resolvedDeliveryLng,
            deliveryAddress: _order!.deliveryAddress,
            riderName: _order!.riderName,
            orderStatus: _order!.status,
            hideTopBanner: true,
            onRouteInfo: ({
              required eta,
              required distance,
              required etaMinutes,
            }) {
              if (!mounted) return;
              setState(() {
                _routeEta = eta;
                _routeDistance = distance;
              });
            },
          ),
        ),
        Expanded(
          flex: 48,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSheetHeader(),
                  if (etaBanner != null) ...[
                    const SizedBox(height: 12),
                    etaBanner,
                  ],
                  const SizedBox(height: 16),
                  CompactStatusTimeline(currentStatus: _order!.status),
                  const SizedBox(height: 16),
                  if (_order!.riderId != null)
                    DeliveryPartnerContactCard(
                      order: _order!,
                      showAnimation: _showPartnerCardAnimation,
                      onRefresh: _loadOrderDetails,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrackingHeader() {
    final hasRider = _liveRiderLat != null || _order?.riderLatitude != null;
    final statusColor = hasRider ? AppColors.success : AppColors.info;
    final statusImage = orderTrackingImageForStatus(_order!.status);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final topInset = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: SizedBox(
        width: screenWidth,
        child: Container(
          width: screenWidth,
          padding: EdgeInsets.fromLTRB(8, topInset + 4, 8, 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [statusColor, statusColor.withValues(alpha: 0.9)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: statusColor.withValues(alpha: 0.22),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.maybePop(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.white,
                size: 18,
              ),
              tooltip: 'Back',
            ),
            ClipOval(
              child: Image.asset(
                statusImage,
                width: 34,
                height: 34,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 34,
                  height: 34,
                  color: AppColors.white.withValues(alpha: 0.2),
                  child: const Icon(
                    Icons.image_not_supported_outlined,
                    size: 18,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getTrackingHeadline(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (_routeEta != null) ...[
                        const Icon(
                          Icons.access_time_rounded,
                          size: 13,
                          color: AppColors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _routeEta!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white,
                            height: 1.1,
                          ),
                        ),
                        if (_routeDistance != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              color: AppColors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                      if (_routeDistance != null)
                        Flexible(
                          child: Text(
                            _routeDistance!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.white,
                              height: 1.1,
                            ),
                          ),
                        ),
                      if (_routeEta == null && _routeDistance == null)
                        Flexible(
                          child: Text(
                            _getEtaText(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.white.withValues(alpha: 0.95),
                              height: 1.1,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _loadOrderDetails,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
              icon: const Icon(
                Icons.refresh_rounded,
                color: AppColors.white,
                size: 20,
              ),
              tooltip: 'Refresh',
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Order #${formatOrderDisplayId(widget.orderId)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ),
        _buildOrderListStatusBadge(_order!.status),
      ],
    );
  }

  Widget _buildOrderListStatusBadge(String status) {
    late final Color backgroundColor;
    late final Color textColor;
    late final String label;

    switch (normalizeOrderStatus(status)) {
      case 'delivered':
        backgroundColor = AppColors.success.withValues(alpha: 0.15);
        textColor = AppColors.success;
        label = 'Delivered';
        break;
      case 'cancelled':
        backgroundColor = AppColors.accentLight;
        textColor = AppColors.error;
        label = 'Cancelled';
        break;
      case 'placed':
      case 'pending':
        backgroundColor = AppColors.warning.withValues(alpha: 0.15);
        textColor = AppColors.warning;
        label = 'Placed';
        break;
      default:
        backgroundColor = AppColors.warning.withValues(alpha: 0.15);
        textColor = AppColors.warning;
        label = 'Active';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Error Loading Order',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadOrderDetails,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(child: Text('Order not found'));
  }

  Widget? _buildEtaBanner() {
    if (_order == null) return null;

    final status = _order!.status.toLowerCase();
    if (status == 'delivered' || status == 'cancelled') return null;

    final eta = _order!.estimatedDeliveryTime;
    if (eta == null) return null;

    final isDelayed = isEtaPassed(eta);
    final minutesLabel = formatMinutesAway(_order!.etaMinutes, eta);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDelayed ? etaOrangeBg : etaGreenBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.access_time,
            color: isDelayed ? etaOrange : etaGreen,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDelayed
                      ? 'Taking a bit longer than expected'
                      : 'Estimated Delivery',
                  style: TextStyle(
                    fontSize: isDelayed ? 13 : 11,
                    color: isDelayed ? etaOrange : AppColors.textSecondary,
                    fontWeight:
                        isDelayed ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (!isDelayed) ...[
                  const SizedBox(height: 2),
                  Text(
                    formatDeliveryByTime(eta),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: etaGreen,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!isDelayed && minutesLabel.isNotEmpty)
            Text(
              minutesLabel,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    if (_order == null) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      color: AppColors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Status',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _buildStatusBadge(_order!.status),
            const SizedBox(height: 12),
            _buildStatusTimeline(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color backgroundColor;
    Color textColor;
    String label;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'placed':
      case 'pending':
        backgroundColor = AppColors.warning.withValues(alpha: 0.2);
        textColor = AppColors.warning;
        label = 'Order Placed';
        icon = Icons.shopping_bag;
        break;
      case 'confirmed':
        backgroundColor = AppColors.info.withValues(alpha: 0.2);
        textColor = AppColors.info;
        label = 'Order Confirmed';
        icon = Icons.check_circle;
        break;
      case 'preparing':
        backgroundColor = AppColors.warning.withValues(alpha: 0.2);
        textColor = AppColors.warning;
        label = 'Preparing';
        icon = Icons.restaurant;
        break;
      case 'out_for_delivery':
        backgroundColor = AppColors.info.withValues(alpha: 0.2);
        textColor = AppColors.info;
        label = 'Out for Delivery';
        icon = Icons.local_shipping;
        break;
      case 'delivered':
        backgroundColor = AppColors.success.withValues(alpha: 0.2);
        textColor = AppColors.success;
        label = 'Delivered';
        icon = Icons.check_circle;
        break;
      case 'cancelled':
        backgroundColor = AppColors.error.withValues(alpha: 0.2);
        textColor = AppColors.error;
        label = 'Cancelled';
        icon = Icons.cancel;
        break;
      default:
        backgroundColor = AppColors.info.withValues(alpha: 0.2);
        textColor = AppColors.info;
        label = status;
        icon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
          // Live indicator for active orders
          OrderStatusLiveIndicator(
            status: _order!.status,
            previousStatus: _previousOrder?.status,
            showLiveBadge: !['delivered', 'cancelled'].contains(_order!.status.toLowerCase()),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTimeline() {
    if (_order == null) return const SizedBox.shrink();

    // Use the new StatusTimelineWidget with real-time updates
    return StatusTimelineWidget(
      currentStatus: _order!.status,
      statusTimestamps: {
        'placed': _order!.createdAt,
        'confirmed': _order!.updatedAt,
        'delivered': _order!.deliveredAt,
      },
    );
  }

  Widget _buildOrderItems() {
    if (_order == null || _order!.items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      color: AppColors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Items',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ..._order!.items.map((item) => _buildOrderItem(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItem(OrderItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.quantity} ${item.unit} × ₹${item.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '₹${item.totalPrice.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryAddress() {
    if (_order == null) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      color: AppColors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Delivery Address',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _order!.deliveryAddress ?? 'Address not available',
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

  String _getTrackingHeadline() {
    final status = _order?.status.toLowerCase() ?? '';
    switch (status) {
      case 'placed':
      case 'pending':
        return 'Order placed successfully';
      case 'confirmed':
      case 'accepted':
        return 'Order confirmed';
      case 'preparing':
      case 'packed':
        return 'Preparing your order';
      case 'out_for_delivery':
      case 'on_way':
        return 'Arriving soon';
      case 'assigned':
        return _order?.riderName != null
            ? '${_order!.riderName} is on the way'
            : 'Rider assigned';
      case 'picked_up':
        return 'Order picked up';
      default:
        return 'Tracking your order';
    }
  }

  String _getEtaText() {
    final status = _order?.status.toLowerCase() ?? '';
    final hasRiderLocation =
        _liveRiderLat != null || _order?.riderLatitude != null;

    if (hasRiderLocation &&
        (status == 'out_for_delivery' ||
            status == 'on_way' ||
            status == 'assigned' ||
            status == 'picked_up')) {
      return 'Live tracking • delivery partner on the move';
    }

    switch (status) {
      case 'out_for_delivery':
      case 'on_way':
        return 'ETA • approx. 15–25 mins';
      case 'picked_up':
        return 'Leaving store shortly';
      case 'assigned':
        return 'Rider heading to pickup';
      case 'preparing':
      case 'packed':
        return 'Fresh cuts being prepared';
      case 'confirmed':
      case 'accepted':
        return 'Assigning delivery partner soon';
      default:
        return 'We will notify you at every step';
    }
  }

  Widget _buildPriceBreakdown() {
    if (_order == null) return const SizedBox.shrink();

    final discount = _order!.discountAmount ?? 0;
    final deliveryCharge = _order!.deliveryCharge ?? 0;
    final isFreeDelivery = deliveryCharge == 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bill Summary',
            style: TextStyle(
              color: AppColors.textDark,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildPriceRow(
            'Item total',
            '₹${_order!.totalAmount.toStringAsFixed(0)}',
          ),
          const SizedBox(height: 8),
          if (_order!.deliveryCharge != null)
            _buildPriceRow(
              'Delivery',
              isFreeDelivery
                  ? 'FREE'
                  : '₹${deliveryCharge.toStringAsFixed(0)}',
              valueColor:
                  isFreeDelivery ? AppColors.success : null,
            ),
          if (discount > 0) ...[
            const SizedBox(height: 8),
            _buildPriceRow(
              'Discount',
              '-₹${discount.toStringAsFixed(0)}',
              valueColor: AppColors.success,
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: AppColors.border),
          ),
          _buildPriceRow(
            'Total',
            '₹${_order!.finalAmount.toStringAsFixed(0)}',
            bold: true,
            valueColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetailsSection() {
    if (_order == null) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      color: AppColors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            // Payment Method
            _buildPaymentDetailRow(
              'Payment Method',
              _order!.paymentMethod == 'cod'
                  ? 'Cash on Delivery'
                  : 'Online Payment',
              icon: _order!.paymentMethod == 'cod'
                  ? Icons.money
                  : Icons.payment,
            ),
            const SizedBox(height: 12),
            // Payment Status
            _buildPaymentDetailRow(
              'Payment Status',
              _getPaymentStatusLabel(_order!.paymentStatus),
              statusColor: _getPaymentStatusColor(_order!.paymentStatus),
              icon: _getPaymentStatusIcon(_order!.paymentStatus),
            ),
            // Payment ID (if online payment and completed)
            if (_order!.paymentMethod == 'online' &&
                _order!.paymentId != null &&
                _order!.paymentId!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildPaymentDetailRow(
                'Payment ID',
                _order!.paymentId!,
                icon: Icons.receipt_long,
                isCopyable: true,
              ),
            ],
            // Payment Details (Razorpay details)
            if (_order!.paymentMethodDetails != null &&
                _order!.paymentMethodDetails!.isNotEmpty) ...[
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 8, bottom: 8),
                title: const Text(
                  'Transaction Details',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                children: [
                  if (_order!.paymentMethodDetails!['phonepe_transaction_id'] !=
                      null)
                    _buildPaymentDetailRow(
                      'PhonePe Transaction ID',
                      _order!.paymentMethodDetails!['phonepe_transaction_id']
                          as String,
                      isCopyable: true,
                    ),
                  if (_order!.paymentMethodDetails!['phonepe_merchant_transaction_id'] !=
                      null) ...[
                    const SizedBox(height: 8),
                    _buildPaymentDetailRow(
                      'PhonePe Merchant Transaction ID',
                      _order!.paymentMethodDetails!['phonepe_merchant_transaction_id']
                          as String,
                      isCopyable: true,
                    ),
                  ],
                ],
              ),
            ],
            // Retry Payment Button (if failed)
            if (_order!.paymentStatus == 'failed' &&
                _order!.paymentMethod == 'online') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isRetryingPayment ? null : () => _retryPayment(),
                  icon: _isRetryingPayment
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(
                    _isRetryingPayment ? 'Processing...' : 'Retry Payment',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentDetailRow(
    String label,
    String value, {
    IconData? icon,
    Color? statusColor,
    bool isCopyable = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: statusColor ?? AppColors.textSecondary),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: statusColor ?? AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (isCopyable)
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      color: AppColors.textSecondary,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: value));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copied to clipboard'),
                            duration: Duration(seconds: 2),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getPaymentStatusLabel(String? status) {
    switch (status) {
      case 'completed':
        return 'Paid';
      case 'pending':
        return 'Pending';
      case 'failed':
        return 'Failed';
      default:
        return status ?? 'Unknown';
    }
  }

  Color _getPaymentStatusColor(String? status) {
    switch (status) {
      case 'completed':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'failed':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getPaymentStatusIcon(String? status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'pending':
        return Icons.pending;
      case 'failed':
        return Icons.error_outline;
      default:
        return Icons.info_outline;
    }
  }

  Future<void> _retryPayment() async {
    if (_order == null) return;

    setState(() {
      _isRetryingPayment = true;
    });

    try {
      // Get user profile for payment details
      final userProfile = await _authService.getCurrentUserProfile();
      if (userProfile == null) {
        throw Exception('User not logged in');
      }

      // Get user phone number from stored profile
      final userPhoneNumber = userProfile.phoneNumber;
      if (userPhoneNumber == null || userPhoneNumber.isEmpty) {
        throw Exception('Phone number not available');
      }

      final phoneNumber = userPhoneNumber.replaceAll('+91', '');
      final customerName = userProfile.name ?? 'Customer';
      final customerEmail = userProfile.email ?? 'customer@meatvo.com';

      // Initiate payment retry
      await _paymentService.initiatePayment(
        orderId: _order!.id,
        userId: userProfile.id,
        amount: _order!.finalAmount,
        customerName: customerName,
        customerEmail: customerEmail,
        customerPhone: phoneNumber,
        onSuccess: (Map<String, dynamic> response) async {
          if (!context.mounted) return;
          setState(() {
            _isRetryingPayment = false;
          });

          final messenger = ScaffoldMessenger.maybeOf(context);
          messenger?.showSnackBar(
            const SnackBar(
              content: Text('Payment successful!'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 3),
            ),
          );

          await _loadOrderDetails();
        },
        onFailure: (String errorMessage) {
          if (!context.mounted) return;
          setState(() {
            _isRetryingPayment = false;
          });

          final messenger = ScaffoldMessenger.maybeOf(context);
          messenger?.showSnackBar(
            SnackBar(
              content: Text('Payment failed: $errorMessage'),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 4),
            ),
          );

          _loadOrderDetails();
        },
      );
    } catch (e) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      setState(() {
        _isRetryingPayment = false;
      });

      messenger?.showSnackBar(
        SnackBar(
          content: Text('Failed to retry payment: $e'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildPriceRow(
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textMedium,
            fontSize: 13,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppColors.textDark,
            fontSize: 13,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    if (_order == null) return const SizedBox.shrink();

    final canCancel = ['placed', 'confirmed'].contains(_order!.status);
    final isDelivered = _order!.status == 'delivered';

    return Column(
      children: [
        if (canCancel)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isCancelling ? null : _cancelOrder,
              icon: _isCancelling
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cancel),
              label: Text(_isCancelling ? 'Cancelling...' : 'Cancel Order'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        if (canCancel) const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isReordering ? null : _reorder,
            icon: _isReordering
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.white,
                      ),
                    ),
                  )
                : const Icon(Icons.shopping_cart),
            label: Text(
              _isReordering
                  ? 'Adding...'
                  : (isDelivered ? 'Reorder' : 'Add to Cart'),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewSection() {
    if (_order == null || _order!.status != 'delivered') {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      color: AppColors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Rate Your Order',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (_existingReview != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Reviewed',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoadingReview)
              const Center(child: CircularProgressIndicator())
            else if (_existingReview != null)
              _buildExistingReview()
            else
              _buildReviewForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildExistingReview() {
    final review = _existingReview!;
    final riderRating = review['rider_rating'] as int?;
    final productRating = review['product_quality_rating'] as int?;
    final deliveryRating = review['delivery_speed_rating'] as int?;
    final feedback = review['feedback'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (riderRating != null) ...[
          _buildRatingRow('Rider', riderRating),
          const SizedBox(height: 8),
        ],
        if (productRating != null) ...[
          _buildRatingRow('Product Quality', productRating),
          const SizedBox(height: 8),
        ],
        if (deliveryRating != null) ...[
          _buildRatingRow('Delivery Speed', deliveryRating),
          const SizedBox(height: 8),
        ],
        if (feedback != null && feedback.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.divider.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Feedback:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  feedback,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _showReviewDialog(),
          icon: const Icon(Icons.edit),
          label: const Text('Edit Review'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingRow(String label, int rating) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Row(
          children: List.generate(5, (index) {
            return Icon(
              index < rating ? Icons.star : Icons.star_border,
              color: AppColors.warning,
              size: 20,
            );
          }),
        ),
      ],
    );
  }

  Widget _buildReviewForm() {
    return ElevatedButton.icon(
      onPressed: () => _showReviewDialog(),
      icon: const Icon(Icons.star),
      label: const Text('Rate & Review'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Future<void> _showReviewDialog() async {
    int? riderRating;
    int? productRating;
    int? deliveryRating;
    final feedbackController = TextEditingController(
      text: _existingReview?['feedback'] as String? ?? '',
    );

    // Pre-fill ratings if review exists
    if (_existingReview != null) {
      riderRating = _existingReview!['rider_rating'] as int?;
      productRating = _existingReview!['product_quality_rating'] as int?;
      deliveryRating = _existingReview!['delivery_speed_rating'] as int?;
    }

    final hasRider = _order?.riderId != null && _order!.riderId!.isNotEmpty;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    await showDialog(
      context: context,
      builder: (dialogContext) => _ReviewDialog(
        orderId: widget.orderId,
        hasRider: hasRider,
        initialRiderRating: riderRating,
        initialProductRating: productRating,
        initialDeliveryRating: deliveryRating,
        initialFeedback: feedbackController.text,
        orderService: _orderService,
        onReviewSubmitted: () async {
          Navigator.pop(dialogContext);
          await _loadReview();
          if (!mounted) return;
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Review submitted successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
        },
      ),
    );
  }
}

/// Review Dialog Widget
class _ReviewDialog extends StatefulWidget {
  final String orderId;
  final bool hasRider;
  final int? initialRiderRating;
  final int? initialProductRating;
  final int? initialDeliveryRating;
  final String initialFeedback;
  final OrderService orderService;
  final VoidCallback onReviewSubmitted;

  const _ReviewDialog({
    required this.orderId,
    required this.hasRider,
    this.initialRiderRating,
    this.initialProductRating,
    this.initialDeliveryRating,
    required this.initialFeedback,
    required this.orderService,
    required this.onReviewSubmitted,
  });

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  int? _riderRating;
  int? _productRating;
  int? _deliveryRating;
  final _feedbackController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _riderRating = widget.initialRiderRating;
    _productRating = widget.initialProductRating;
    _deliveryRating = widget.initialDeliveryRating;
    _feedbackController.text = widget.initialFeedback;
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    // At least one rating is required
    if (_riderRating == null &&
        _productRating == null &&
        _deliveryRating == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide at least one rating'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await widget.orderService.submitReview(
        orderId: widget.orderId,
        riderRating: _riderRating,
        productQualityRating: _productRating,
        deliverySpeedRating: _deliveryRating,
        feedback: _feedbackController.text.trim().isEmpty
            ? null
            : _feedbackController.text.trim(),
      );

      widget.onReviewSubmitted();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit review: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildStarRating({
    required String label,
    required int? rating,
    required Function(int) onRatingChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (index) {
            return GestureDetector(
              onTap: () => onRatingChanged(index + 1),
              child: Icon(
                index < (rating ?? 0) ? Icons.star : Icons.star_border,
                color: AppColors.warning,
                size: 32,
              ),
            );
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rate Your Order'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.hasRider) ...[
              _buildStarRating(
                label: 'Rider Service',
                rating: _riderRating,
                onRatingChanged: (rating) {
                  setState(() => _riderRating = rating);
                },
              ),
              const SizedBox(height: 20),
            ],
            _buildStarRating(
              label: 'Product Quality',
              rating: _productRating,
              onRatingChanged: (rating) {
                setState(() => _productRating = rating);
              },
            ),
            const SizedBox(height: 20),
            _buildStarRating(
              label: 'Delivery Speed',
              rating: _deliveryRating,
              onRatingChanged: (rating) {
                setState(() => _deliveryRating = rating);
              },
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _feedbackController,
              decoration: const InputDecoration(
                labelText: 'Feedback (optional)',
                hintText: 'Share your experience...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReview,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                  ),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }
}
