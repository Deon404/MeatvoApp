import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/order_model.dart';
import '../../features/tracking/order_tracking_subscription.dart';
import '../../services/order_service.dart';
import '../../services/socket_service.dart';
import '../../services/cart_service.dart';
import '../../services/payment_service.dart';
import '../../core/constants/app_constants.dart';
import '../../design_system/tokens/meatvo_colors.dart';
import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../utils/address_display_util.dart';
import '../../utils/order_eta_util.dart';
import '../../utils/order_status_util.dart';
import '../../utils/eta_display_util.dart';
import '../../services/maps_service.dart';
import '../../widgets/maps/delivery_tracking_map.dart';
import '../../widgets/order/order_cancel_grace_banner.dart';
import '../../widgets/order/order_delivery_otp_card.dart';
import '../../widgets/order/order_tracking_bottom_sheet.dart';
import '../../widgets/order/order_tracking_header.dart';
import '../../widgets/order/order_tracking_hero_card.dart';
import '../../widgets/order/order_tracking_illustration.dart';
import '../../widgets/delivery/delivery_partner_contact_card.dart';
import '../payment/payment_processing_screen.dart';
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
  OrderModel? _order;
  bool _isLoading = true;
  bool _isRefreshing = false;
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
  int? _liveEtaMinutes;
  DateTime? _liveEstimatedAt;
  double? _resolvedDeliveryLat;
  double? _resolvedDeliveryLng;
  bool _showPartnerCardAnimation = false;
  bool _socketReconnecting = false;
  bool _socketEverConnected = false;
  String? _routeDistance;
  int? _routeEtaMinutes;
  String? _deliveryOtp;
  bool _otpLoading = false;
  String? _otpError;
  bool _otpFetchAttempted = false;

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

  Future<void> _loadOrderDetails({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _isRefreshing = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final order = await _orderService.getOrderById(widget.orderId);
      final deliveryCoords = await _resolveDeliveryCoordinates(order);
      if (mounted) {
        setState(() {
          _order = order;
          _liveRiderLat = order.riderLatitude;
          _liveRiderLng = order.riderLongitude;
          _liveEtaMinutes = order.etaMinutes;
          _liveEstimatedAt = resolveDisplayEstimatedAt(
            etaMinutes: order.etaMinutes,
            fallbackEstimatedAt: order.estimatedDeliveryTime,
          );
          _resolvedDeliveryLat = deliveryCoords?['lat'];
          _resolvedDeliveryLng = deliveryCoords?['lng'];
          _isLoading = false;
          _isRefreshing = false;
        });
        _startTrackingIfActive(order);
        _maybeFetchDeliveryOtp(order);
        if (order.status == 'delivered') {
          _loadReview();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load order details: $e';
          _isLoading = false;
          _isRefreshing = false;
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
          _order = updated;
          if (_liveRiderLat == null && updated.riderLatitude != null) {
            _liveRiderLat = updated.riderLatitude;
            _liveRiderLng = updated.riderLongitude;
          }
          if (updated.etaMinutes != null) {
            _liveEtaMinutes = updated.etaMinutes;
          }
          _liveEstimatedAt = resolveDisplayEstimatedAt(
            etaMinutes: _liveEtaMinutes ?? updated.etaMinutes,
            liveEstimatedAt: _liveEstimatedAt,
            fallbackEstimatedAt: updated.estimatedDeliveryTime,
          );
          if (normalizeOrderStatus(updated.status) == 'delivered' ||
              isOrderCancelled(updated.status)) {
            _liveEtaMinutes = null;
            _liveEstimatedAt = null;
          }
        });
        _maybeFetchDeliveryOtp(updated);
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
      onEtaUpdate: (update) {
        if (!mounted) return;
        setState(() {
          final status = _order?.status ?? '';
          final distanceKm = parseRouteDistanceKm(_routeDistance) ?? 0;
          _liveEtaMinutes = isOrderOutForDelivery(status)
              ? update.etaMinutes
              : composeCustomerEtaMinutes(
                  status: status,
                  travelMinutes: update.etaMinutes,
                  distanceKm: distanceKm,
                );
          _liveEstimatedAt = DateTime.now().add(
            Duration(minutes: _liveEtaMinutes ?? update.etaMinutes),
          );
          if (update.riderLat != null && update.riderLng != null) {
            _liveRiderLat = update.riderLat;
            _liveRiderLng = update.riderLng;
          }
        });
      },
      onConnectionState: (connected) {
        if (!mounted) return;
        setState(() {
          if (connected) _socketEverConnected = true;
          // Only warn after a successful connection was lost (not on first connect).
          _socketReconnecting = _socketEverConnected && !connected;
        });
      },
    );
  }

  void _maybeFetchDeliveryOtp(OrderModel order) {
    if (!isDeliveryOtpVisible(order.status)) {
      if (_deliveryOtp != null || _otpFetchAttempted) {
        setState(() {
          _deliveryOtp = null;
          _otpError = null;
          _otpFetchAttempted = false;
        });
      }
      return;
    }
    if (_otpFetchAttempted || _otpLoading) return;

    setState(() {
      _otpLoading = true;
      _otpError = null;
      _otpFetchAttempted = true;
    });

    _orderService.getDeliveryOtp(widget.orderId).then((otp) {
      if (!mounted) return;
      setState(() {
        _deliveryOtp = otp;
        _otpLoading = false;
        if (otp == null) {
          _otpError = 'Could not load delivery OTP';
        }
      });
    }).catchError((e) {
      if (!mounted) return;
      setState(() {
        _otpLoading = false;
        _otpError = 'Could not load delivery OTP';
      });
    });
  }

  void _retryFetchOtp() {
    setState(() {
      _otpFetchAttempted = false;
      _otpError = null;
    });
    if (_order != null) _maybeFetchDeliveryOtp(_order!);
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
            style: TextButton.styleFrom(foregroundColor: MeatvoColors.error),
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
            backgroundColor: MeatvoColors.success,
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
            backgroundColor: MeatvoColors.error,
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
            backgroundColor: MeatvoColors.success,
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
            backgroundColor: MeatvoColors.error,
          ),
        );
      }
    }
  }

  void _onRouteInfo({
    required String? eta,
    required String? distance,
    required int? etaMinutes,
  }) {
    if (!mounted) return;
    setState(() {
      _routeDistance = distance;
      if (etaMinutes != null) _routeEtaMinutes = etaMinutes;
    });
  }

  int? get _riderBasedEtaMinutes {
    final lat = _liveRiderLat ?? _order?.riderLatitude;
    final lng = _liveRiderLng ?? _order?.riderLongitude;
    final customerLat = _resolvedDeliveryLat;
    final customerLng = _resolvedDeliveryLng;
    if (lat == null ||
        lng == null ||
        customerLat == null ||
        customerLng == null) {
      return null;
    }
    return computeRiderCustomerEta(
      status: _order?.status ?? '',
      riderLat: lat,
      riderLng: lng,
      customerLat: customerLat,
      customerLng: customerLng,
    );
  }

  String? get _riderBasedDistanceText {
    final lat = _liveRiderLat ?? _order?.riderLatitude;
    final lng = _liveRiderLng ?? _order?.riderLongitude;
    final customerLat = _resolvedDeliveryLat;
    final customerLng = _resolvedDeliveryLng;
    if (lat == null ||
        lng == null ||
        customerLat == null ||
        customerLng == null) {
      return null;
    }
    final km = distanceKmBetween(
      startLat: lat,
      startLng: lng,
      endLat: customerLat,
      endLng: customerLng,
    );
    return formatDistanceKm(km * 1.2);
  }

  int? get _headerEtaMinutes {
    final status = _order?.status ?? '';
    final riderEta = _riderBasedEtaMinutes;
    if (isOrderOutForDelivery(status)) {
      return _liveEtaMinutes ??
          _routeEtaMinutes ??
          riderEta ??
          _order?.etaMinutes;
    }

    return _routeEtaMinutes ??
        riderEta ??
        _liveEtaMinutes ??
        _order?.etaMinutes;
  }

  String? get _headerDistanceText =>
      _riderBasedDistanceText ?? _routeDistance;

  DateTime? get _displayEstimatedAt => resolveDisplayEstimatedAt(
        etaMinutes: _headerEtaMinutes,
        liveEstimatedAt: _liveEstimatedAt,
        fallbackEstimatedAt: _order?.estimatedDeliveryTime,
      );

  bool _shouldShowRiderSection() {
    if (_order == null) return false;
    return shouldShowPartnerSection(_order!.status);
  }

  bool get _showLiveMap {
    if (_order == null) return false;
    final hasRiderGps =
        (_liveRiderLat ?? _order!.riderLatitude) != null &&
        (_liveRiderLng ?? _order!.riderLongitude) != null;
    final hasDeliveryCoords =
        _resolvedDeliveryLat != null && _resolvedDeliveryLng != null;
    return shouldShowLiveMap(
      _order!.status,
      hasRiderGps: hasRiderGps,
      hasDeliveryCoords: hasDeliveryCoords,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: mv.surfaceWarm,
        body: Center(
          child: CircularProgressIndicator(color: mv.brandPrimary),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: mv.surfaceWarm,
        appBar: AppBar(
          backgroundColor: mv.surfaceWarm,
          elevation: 0,
        ),
        body: SafeArea(child: _buildErrorState()),
      );
    }

    if (_order == null) {
      return Scaffold(
        backgroundColor: mv.surfaceWarm,
        appBar: AppBar(
          backgroundColor: mv.surfaceWarm,
          elevation: 0,
        ),
        body: SafeArea(child: _buildEmptyState()),
      );
    }

    return _buildTrackingLayout();
  }

  Widget _buildTrackingLayout() {
    final order = _order!;
    final hasDeliveryCoords =
        _resolvedDeliveryLat != null && _resolvedDeliveryLng != null;
    final isDelivered = isOrderCompleted(order.status);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: _showLiveMap && hasDeliveryCoords
                ? DeliveryTrackingMap(
                    expandToFill: true,
                    hideTopBanner: true,
                    onRouteInfo: _onRouteInfo,
                    riderLatitude: _liveRiderLat ?? order.riderLatitude,
                    riderLongitude: _liveRiderLng ?? order.riderLongitude,
                    deliveryLatitude: _resolvedDeliveryLat,
                    deliveryLongitude: _resolvedDeliveryLng,
                    deliveryAddress: order.deliveryAddress,
                    riderName: order.riderName,
                    orderStatus: order.status,
                  )
                : OrderTrackingIllustration(status: order.status),
          ),
          if (_showLiveMap)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 72,
              right: 16,
              child: _LiveMapBadge(),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: OrderTrackingHeader(
              status: order.status,
              riderName: order.riderName,
              etaMinutes: _headerEtaMinutes,
              distanceText: _headerDistanceText,
              deliveredAt: order.deliveredAt,
              isRefreshing: _isRefreshing,
              onBack: () => Navigator.of(context).pop(),
              onRefresh: () => _loadOrderDetails(refresh: true),
            ),
          ),
          if (_socketReconnecting)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 56,
              left: 16,
              right: 16,
              child: Material(
                color: MeatvoColors.warning.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Reconnecting… updates fall back to 30s polling',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          OrderTrackingBottomSheet(
            orderId: widget.orderId,
            status: order.status,
            heroCard: OrderTrackingHeroCard(
              status: order.status,
              deliveryAddress: order.deliveryAddress,
              etaMinutes: _headerEtaMinutes,
              estimatedDeliveryTime: _displayEstimatedAt,
              deliverySlotLabel: order.deliverySlotLabel,
              progressFraction: trackingProgressFraction(order.status),
            ),
            graceBanner: OrderCancelGraceBanner(
              createdAt: order.createdAt,
              status: order.status,
              isCancelling: _isCancelling,
              onCancel: _cancelOrder,
            ),
            otpCard: isDeliveryOtpVisible(order.status)
                ? OrderDeliveryOtpCard(
                    otp: _deliveryOtp,
                    isLoading: _otpLoading,
                    errorMessage: _otpError,
                    onRetry: _retryFetchOtp,
                  )
                : null,
            partnerSection: _shouldShowRiderSection()
                ? DeliveryPartnerSheetCard(
                    order: order,
                    showAnimation: _showPartnerCardAnimation,
                  )
                : null,
            reorderButton: isDelivered
                ? SizedBox(
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
                                  MeatvoColors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.replay_rounded),
                      label: Text(_isReordering ? 'Adding...' : 'Reorder'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MeatvoColors.brandPrimary,
                        foregroundColor: MeatvoColors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  )
                : null,
            detailsContent: _buildSheetDetails(),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetDetails() {
    final mv = context.meatvo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildOrderItems(),
        SizedBox(height: mv.spacing.md),
        _buildDeliveryAddress(),
        SizedBox(height: mv.spacing.md),
        _buildPriceBreakdown(),
        SizedBox(height: mv.spacing.md),
        _buildPaymentDetailsSection(),
        if (_order!.status == 'delivered') ...[
          SizedBox(height: mv.spacing.md),
          _buildReviewSection(),
        ],
        SizedBox(height: mv.spacing.lg),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: MeatvoColors.error),
            const SizedBox(height: 16),
            Text(
              'Error Loading Order',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: MeatvoColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: MeatvoColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadOrderDetails,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: MeatvoColors.brandPrimary,
                foregroundColor: MeatvoColors.white,
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

  Widget _buildOrderItems() {
    if (_order == null || _order!.items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      color: MeatvoColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: MeatvoColors.border, width: 1),
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
                color: MeatvoColors.textPrimary,
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
                    color: MeatvoColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.quantity} ${item.unit} × ₹${item.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: MeatvoColors.textSecondary,
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
              color: MeatvoColors.textPrimary,
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
      color: MeatvoColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: MeatvoColors.border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: MeatvoColors.brandPrimary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Delivery Address',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: MeatvoColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              formatAddressForDisplay(_order!.deliveryAddress),
              style: const TextStyle(
                fontSize: 14,
                color: MeatvoColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceBreakdown() {
    if (_order == null) return const SizedBox.shrink();

    final discount = _order!.discountAmount ?? 0;
    final deliveryCharge = _order!.deliveryCharge ?? 0;
    final isFreeDelivery = deliveryCharge == 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MeatvoColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: MeatvoColors.black.withValues(alpha: 0.04),
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
              color: MeatvoColors.textPrimary,
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
                  isFreeDelivery ? MeatvoColors.success : null,
            ),
          if (discount > 0) ...[
            const SizedBox(height: 8),
            _buildPriceRow(
              'Discount',
              '-₹${discount.toStringAsFixed(0)}',
              valueColor: MeatvoColors.success,
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: MeatvoColors.border),
          ),
          _buildPriceRow(
            'Total',
            '₹${_order!.finalAmount.toStringAsFixed(0)}',
            bold: true,
            valueColor: MeatvoColors.brandPrimary,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetailsSection() {
    if (_order == null) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      color: MeatvoColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: MeatvoColors.border, width: 1),
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
                color: MeatvoColors.textPrimary,
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
              _getPaymentStatusLabel(
                _order!.paymentStatus,
                paymentMethod: _order!.paymentMethod,
              ),
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
            // Gateway transaction details (Cashfree)
            if (_order!.paymentMethod == 'online') ...[
              const SizedBox(height: 12),
              _buildPaymentDetailRow(
                'Payment Gateway',
                'Cashfree',
                icon: Icons.account_balance_wallet_outlined,
              ),
            ],
            if (_order!.paymentMethodDetails != null &&
                _order!.paymentMethodDetails!.isNotEmpty &&
                _hasGatewayTransactionDetails(_order!.paymentMethodDetails!)) ...[
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 8, bottom: 8),
                title: const Text(
                  'Transaction Details',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MeatvoColors.textPrimary,
                  ),
                ),
                children: _buildGatewayTransactionRows(
                  _order!.paymentMethodDetails!,
                ),
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
                    foregroundColor: MeatvoColors.brandPrimary,
                    side: const BorderSide(color: MeatvoColors.brandPrimary),
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
          Icon(icon, size: 18, color: statusColor ?? MeatvoColors.textSecondary),
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
                  color: MeatvoColors.textSecondary,
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
                        color: statusColor ?? MeatvoColors.textPrimary,
                      ),
                    ),
                  ),
                  if (isCopyable)
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      color: MeatvoColors.textSecondary,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: value));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copied to clipboard'),
                            duration: Duration(seconds: 2),
                            backgroundColor: MeatvoColors.success,
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

  String _getPaymentStatusLabel(String? status, {String? paymentMethod}) {
    if ((status == null || status.isEmpty) &&
        paymentMethod?.toLowerCase() == 'cod') {
      return 'Pay on delivery';
    }
    switch (status) {
      case 'completed':
        return 'Paid';
      case 'pending':
        return 'Pending';
      case 'failed':
        return 'Failed';
      default:
        return status?.isNotEmpty == true ? status! : 'Pending';
    }
  }

  Color _getPaymentStatusColor(String? status) {
    switch (status) {
      case 'completed':
        return MeatvoColors.success;
      case 'pending':
        return MeatvoColors.warning;
      case 'failed':
        return MeatvoColors.error;
      default:
        return MeatvoColors.textSecondary;
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

  bool _hasGatewayTransactionDetails(Map<String, dynamic> details) {
    const keys = [
      'gateway_payment_id',
      'cf_payment_id',
      'gateway_order_id',
      'cf_order_id',
      'payment_session_id',
    ];
    return keys.any((key) {
      final value = details[key];
      return value != null && value.toString().trim().isNotEmpty;
    });
  }

  List<Widget> _buildGatewayTransactionRows(Map<String, dynamic> details) {
    final rows = <Widget>[];

    void addRow(String label, String? key) {
      final raw = details[key];
      if (raw == null || raw.toString().trim().isEmpty) return;
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 8));
      rows.add(
        _buildPaymentDetailRow(
          label,
          raw.toString(),
          isCopyable: true,
        ),
      );
    }

    addRow('Cashfree Payment ID', 'gateway_payment_id');
    addRow('Cashfree Payment ID', 'cf_payment_id');
    addRow('Cashfree Order ID', 'gateway_order_id');
    addRow('Cashfree Order ID', 'cf_order_id');
    addRow('Payment Session', 'payment_session_id');

    return rows;
  }

  Map<String, dynamic> _deliveryAddressPayload(OrderModel order) {
    return {
      if (order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty)
        'text': order.deliveryAddress,
      if (order.deliveryLatitude != null) 'latitude': order.deliveryLatitude,
      if (order.deliveryLongitude != null) 'longitude': order.deliveryLongitude,
    };
  }

  Future<void> _retryPayment() async {
    if (_order == null) return;

    setState(() => _isRetryingPayment = true);

    try {
      if (!mounted) return;
      setState(() => _isRetryingPayment = false);

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PaymentProcessingScreen(
            order: _order!,
            deliveryAddress: _deliveryAddressPayload(_order!),
            paymentService: _paymentService,
            amount: _order!.finalAmount,
          ),
        ),
      );

      if (mounted) await _loadOrderDetails();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRetryingPayment = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Failed to retry payment: $e'),
          backgroundColor: MeatvoColors.error,
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
            color: MeatvoColors.textSecondary,
            fontSize: 13,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? MeatvoColors.textPrimary,
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
                foregroundColor: MeatvoColors.error,
                side: const BorderSide(color: MeatvoColors.error),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        if (canCancel) const SizedBox(height: 12),
        if (isDelivered)
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
                          MeatvoColors.white,
                        ),
                      ),
                    )
                  : const Icon(Icons.replay_rounded),
              label: Text(_isReordering ? 'Adding...' : 'Reorder'),
              style: ElevatedButton.styleFrom(
                backgroundColor: MeatvoColors.brandPrimary,
                foregroundColor: MeatvoColors.white,
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
      color: MeatvoColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: MeatvoColors.border, width: 1),
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
                    color: MeatvoColors.textPrimary,
                  ),
                ),
                if (_existingReview != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: MeatvoColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Reviewed',
                      style: TextStyle(
                        fontSize: 12,
                        color: MeatvoColors.success,
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
              color: MeatvoColors.divider.withValues(alpha: 0.3),
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
                    color: MeatvoColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  feedback,
                  style: const TextStyle(
                    fontSize: 14,
                    color: MeatvoColors.textPrimary,
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
            foregroundColor: MeatvoColors.brandPrimary,
            side: const BorderSide(color: MeatvoColors.brandPrimary),
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
              color: MeatvoColors.textSecondary,
            ),
          ),
        ),
        Row(
          children: List.generate(5, (index) {
            return Icon(
              index < rating ? Icons.star : Icons.star_border,
              color: MeatvoColors.warning,
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
        backgroundColor: MeatvoColors.brandPrimary,
        foregroundColor: MeatvoColors.white,
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
              backgroundColor: MeatvoColors.success,
            ),
          );
        },
      ),
    );
  }
}

class _LiveMapBadge extends StatefulWidget {
  @override
  State<_LiveMapBadge> createState() => _LiveMapBadgeState();
}

class _LiveMapBadgeState extends State<_LiveMapBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(
              alpha: 0.85 + _controller.value * 0.15,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.success.withValues(alpha: 0.3),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 8, color: AppColors.white),
              SizedBox(width: 6),
              Text(
                'LIVE',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );
      },
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
          backgroundColor: MeatvoColors.error,
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
            backgroundColor: MeatvoColors.error,
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
            color: MeatvoColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (index) {
            return GestureDetector(
              onTap: () => onRatingChanged(index + 1),
              child: Icon(
                index < (rating ?? 0) ? Icons.star : Icons.star_border,
                color: MeatvoColors.warning,
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
            backgroundColor: MeatvoColors.brandPrimary,
            foregroundColor: MeatvoColors.white,
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
                    valueColor: AlwaysStoppedAnimation<Color>(MeatvoColors.white),
                  ),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }
}
