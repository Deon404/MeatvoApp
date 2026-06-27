import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/meatvo_swipe_tabs.dart';
import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../../services/socket_service.dart';
import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../design_system/tokens/meatvo_colors.dart';
import '../../design_system/tokens/meatvo_spacing.dart';
import '../../utils/app_transitions.dart';
import '../../utils/eta_display_util.dart';
import '../../utils/order_display_util.dart';
import '../../utils/order_status_util.dart';
import '../../utils/order_payment_util.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/error_state.dart';
import '../../widgets/common/shimmer_loader.dart';
import 'order_detail_screen.dart';

/// Orders Screen - Display order history with status tracking
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  final OrderService _orderService = OrderService();
  final SocketService _socketService = SocketService();
  final TextEditingController _searchController = TextEditingController();
  List<OrderModel> _orders = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String? _errorMessage;
  String _searchQuery = '';
  Timer? _socketReloadDebounce;
  final Map<String, int> _liveEtaMinutes = {};
  final Map<String, DateTime> _liveEstimatedAt = {};
  void Function(dynamic)? _etaHandler;
  late TabController _tabController;
  late MeatvoSwipeTabsHelper _tabHelper;

  static const _filters = [
    ('all', 'All'),
    ('active', 'Active'),
    ('completed', 'Completed'),
    ('cancelled', 'Cancelled'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _filters.length, vsync: this);
    _tabHelper = MeatvoSwipeTabsHelper(
      tabs: _filters.map((f) => MeatvoTabItem(label: f.$2)).toList(),
      controller: _tabController,
      onIndexChanged: (_) => setState(() {}),
    );
    _tabController.addListener(_tabHelper.handleTabChange);
    _searchController.addListener(_onSearchChanged);
    _loadOrders();
    _setupSocketListener();
  }

  void _setupSocketListener() {
    _socketService.connect();
    _socketService.onOrderUpdate(_onOrderStatusSocketEvent);
    _etaHandler = _onEtaSocketEvent;
    _socketService.onEtaUpdate(_etaHandler!);
  }

  void _onEtaSocketEvent(dynamic data) {
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);
    final orderId = map['orderId']?.toString();
    if (orderId == null) return;

    final etaRaw = map['eta'] ?? map['etaMinutes'] ?? map['eta_minutes'];
    final etaMinutes = etaRaw is num
        ? etaRaw.round()
        : int.tryParse(etaRaw?.toString() ?? '');
    if (etaMinutes == null) return;

    if (!mounted) return;
    setState(() {
      _liveEtaMinutes[orderId] = etaMinutes;
      _liveEstimatedAt[orderId] =
          DateTime.now().add(Duration(minutes: etaMinutes));
    });
  }

  void _syncLiveEtaFromOrders(List<OrderModel> orders) {
    _liveEtaMinutes.removeWhere(
      (orderId, _) => !orders.any((o) => o.id == orderId),
    );
    _liveEstimatedAt.removeWhere(
      (orderId, _) => !orders.any((o) => o.id == orderId),
    );

    for (final order in orders) {
      if (!isOrderActive(order.status)) {
        _liveEtaMinutes.remove(order.id);
        _liveEstimatedAt.remove(order.id);
        continue;
      }
      if (order.etaMinutes != null) {
        _liveEtaMinutes[order.id] = order.etaMinutes!;
      }
      final resolved = resolveDisplayEstimatedAt(
        etaMinutes: order.etaMinutes,
        fallbackEstimatedAt: order.estimatedDeliveryTime,
      );
      if (resolved != null) {
        _liveEstimatedAt[order.id] = resolved;
      } else {
        _liveEstimatedAt.remove(order.id);
      }
    }
  }

  void _onOrderStatusSocketEvent(dynamic _) {
    _socketReloadDebounce?.cancel();
    _socketReloadDebounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _loadOrders();
    });
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_tabHelper.handleTabChange);
    _tabController.dispose();
    _socketReloadDebounce?.cancel();
    _socketService.offOrderUpdate();
    if (_etaHandler != null) {
      _socketService.offEtaUpdate();
      _etaHandler = null;
    }
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final orders = await _orderService.getUserOrders();
      if (mounted) {
        setState(() {
          _orders = orders;
          _syncLiveEtaFromOrders(orders);
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

  Future<void> _openOrderDetail(String orderId) async {
    await context.pushSlideRight(OrderDetailScreen(orderId: orderId));
    if (!mounted) return;
    await _loadOrders();
  }

  List<OrderModel> _ordersForFilter(String filter) {
    List<OrderModel> result;
    switch (filter) {
      case 'active':
        result =
            _orders.where((order) => isOrderActive(order.status)).toList();
        break;
      case 'completed':
        result =
            _orders.where((order) => isOrderCompleted(order.status)).toList();
        break;
      case 'cancelled':
        result =
            _orders.where((order) => isOrderCancelled(order.status)).toList();
        break;
      default:
        result = List<OrderModel>.from(_orders);
    }

    if (_searchQuery.isNotEmpty) {
      result = result.where((order) {
        final id = formatOrderDisplayId(order.id).toLowerCase();
        final items = order.items
            .map((item) => item.productName.toLowerCase())
            .join(' ');
        return id.contains(_searchQuery) || items.contains(_searchQuery);
      }).toList();
    }

    return result;
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final mv = context.meatvo;
    final textTheme = Theme.of(context).textTheme;
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: mv.surfaceWarm,
      appBar: AppBar(
        backgroundColor: mv.surfaceWarm,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: canPop
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: mv.textPrimary,
                ),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search orders...',
                  hintStyle: textTheme.bodyMedium?.copyWith(color: mv.textMuted),
                  border: InputBorder.none,
                  isDense: true,
                ),
                style: textTheme.titleMedium?.copyWith(
                      color: mv.textPrimary,
                    ),
              )
            : Text(
                'My Orders',
                style: textTheme.titleLarge?.copyWith(
                      color: mv.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
        centerTitle: !_isSearching,
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close_rounded : Icons.search_rounded,
              color: mv.textPrimary,
            ),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: _isLoading
            ? const ShimmerLoader.listTile(count: 4)
            : _errorMessage != null
                ? _buildErrorState()
                : MeatvoSwipeTabs(
                    controller: _tabController,
                    isScrollable: false,
                    tabs: _filters
                        .map((f) => MeatvoTabItem(label: f.$2))
                        .toList(),
                    children: [
                      for (final filter in _filters)
                        _buildOrdersTabPage(filter.$1, mv),
                    ],
                  ),
      ),
    );
  }

  Widget _buildOrdersTabPage(String filter, MeatvoThemeData mv) {
    final orders = _ordersForFilter(filter);

    if (orders.isEmpty) {
      return _buildEmptyStateForFilter(filter);
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: mv.brandPrimary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          mv.spacing.md,
          0,
          mv.spacing.md,
          MeatvoSpacing.lg,
        ),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          return _buildOrderCard(orders[index], mv);
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return ErrorStateWidget(
      title: 'Unable to load orders',
      message: _errorMessage,
      onRetry: _loadOrders,
    );
  }

  Widget _buildEmptyStateForFilter(String filter) {
    if (_searchQuery.isNotEmpty) {
      return const EmptyStateWidget(
        title: 'No orders found',
        message: 'Try a different search term.',
      );
    }

    switch (filter) {
      case 'active':
        return const EmptyStateWidget(
          title: 'No active orders',
          message: 'You don\'t have any active orders at the moment.',
        );
      case 'completed':
        return const EmptyStateWidget(
          title: 'No completed orders yet',
          message: 'Your completed orders will appear here.',
        );
      case 'cancelled':
        return const EmptyStateWidget(
          title: 'No cancelled orders',
          message: 'You haven\'t cancelled any orders.',
        );
      default:
        return EmptyStateWidget.orders();
    }
  }

  Widget _buildOrderCard(OrderModel order, MeatvoThemeData mv) {
    final awaitingPayment = isOrderAwaitingPayment(order);
    final isActive = isOrderActive(order.status);
    final showTrack = isActive && !awaitingPayment;

    return Container(
      margin: EdgeInsets.symmetric(vertical: mv.spacing.xxs + 2),
      decoration: BoxDecoration(
        color: mv.surfaceCard,
        borderRadius: BorderRadius.circular(mv.radii.lg),
        boxShadow: mv.shadowCard,
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _openOrderDetail(order.id);
        },
        borderRadius: BorderRadius.circular(mv.radii.lg),
        child: Padding(
          padding: EdgeInsets.all(mv.spacing.sm + 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#ORD-${formatOrderDisplayId(order.id)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: mv.textMuted,
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildStatusBadge(order, mv),
                      if (isActive && !awaitingPayment) ...[
                        SizedBox(height: mv.spacing.xxs),
                        _buildActiveEtaLabel(order, mv),
                      ],
                    ],
                  ),
                ],
              ),
              SizedBox(height: mv.spacing.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _buildItemsSummary(order),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: mv.textPrimary,
                      ),
                    ),
                  ),
                  SizedBox(width: mv.spacing.xs),
                  Text(
                    _formatDate(order.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: mv.textMuted,
                    ),
                  ),
                ],
              ),
              if (isActive && !awaitingPayment) ...[
                SizedBox(height: mv.spacing.sm),
                _buildProgressBar(order.status, mv),
              ],
              SizedBox(height: mv.spacing.sm),
              Row(
                children: [
                  Text(
                    '₹${order.finalAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: mv.brandPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (awaitingPayment)
                    _buildPayNowButton(order.id, mv)
                  else if (showTrack)
                    _buildTrackButton(order.id, mv),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatETA(DateTime? etaTime, int? etaMinutes) {
    return formatOrderDistanceEta(
      context,
      estimatedDeliveryTime: etaTime,
      etaMinutes: etaMinutes,
    );
  }

  Widget _buildActiveEtaLabel(OrderModel order, MeatvoThemeData mv) {
    final liveMinutes = _liveEtaMinutes[order.id] ?? order.etaMinutes;
    final liveAt = _liveEstimatedAt[order.id] ?? order.estimatedDeliveryTime;

    return Text(
      _formatETA(liveAt, liveMinutes),
      style: TextStyle(
        fontSize: 11,
        color: mv.textMuted,
      ),
    );
  }

  Widget _buildProgressBar(String status, MeatvoThemeData mv) {
    final filledSegments = _orderProgressSegments(status);

    return Row(
      children: List.generate(4, (index) {
        final isFilled = index < filledSegments;
        return Expanded(
          child: Container(
            height: 3,
            margin: EdgeInsets.only(right: index < 3 ? 4 : 0),
            decoration: BoxDecoration(
              color: isFilled ? mv.brandPrimary : mv.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPayNowButton(String orderId, MeatvoThemeData mv) {
    return SizedBox(
      height: 32,
      child: FilledButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          _openOrderDetail(orderId);
        },
        style: FilledButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: mv.spacing.sm),
          backgroundColor: mv.brandPrimary,
          foregroundColor: MeatvoColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(mv.radii.sm),
          ),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text(
          'Pay now',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildTrackButton(String orderId, MeatvoThemeData mv) {
    return SizedBox(
      height: 32,
      child: OutlinedButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          _openOrderDetail(orderId);
        },
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: mv.spacing.sm),
          side: BorderSide(color: mv.brandPrimary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(mv.radii.sm),
          ),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          'Track Order',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: mv.brandPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(OrderModel order, MeatvoThemeData mv) {
    if (isPaymentFailed(order)) {
      return _statusBadgeChip(
        label: 'Payment failed',
        backgroundColor: mv.error.withValues(alpha: 0.12),
        textColor: mv.error,
        mv: mv,
      );
    }

    if (isOrderAwaitingPayment(order)) {
      return _statusBadgeChip(
        label: 'Payment pending',
        backgroundColor: MeatvoColors.warning.withValues(alpha: 0.15),
        textColor: MeatvoColors.warning,
        mv: mv,
      );
    }

    late final Color backgroundColor;
    late final Color textColor;
    late final String label;

    switch (normalizeOrderStatus(order.status)) {
      case 'delivered':
        backgroundColor = mv.freshBadge.withValues(alpha: 0.15);
        textColor = mv.freshBadge;
        label = 'Delivered';
        break;
      case 'cancelled':
        backgroundColor = MeatvoColors.primaryLight;
        textColor = mv.error;
        label = 'Cancelled';
        break;
      case 'placed':
      case 'pending':
        backgroundColor = MeatvoColors.warning.withValues(alpha: 0.15);
        textColor = MeatvoColors.warning;
        label = 'Placed';
        break;
      default:
        backgroundColor = MeatvoColors.primaryLight.withValues(alpha: 0.5);
        textColor = mv.brandPrimary;
        label = 'Active';
    }

    return _statusBadgeChip(
      label: label,
      backgroundColor: backgroundColor,
      textColor: textColor,
      mv: mv,
    );
  }

  Widget _statusBadgeChip({
    required String label,
    required Color backgroundColor,
    required Color textColor,
    required MeatvoThemeData mv,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(mv.radii.pill),
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

  String _buildItemsSummary(OrderModel order) {
    if (order.items.isEmpty) return 'No items';
    return order.items.map((item) => item.productName).join(', ');
  }

  int _orderProgressSegments(String status) {
    switch (normalizeOrderStatus(status)) {
      case 'placed':
      case 'pending':
        return 1;
      case 'confirmed':
      case 'accepted':
      case 'preparing':
      case 'packed':
        return 2;
      case 'out_for_delivery':
      case 'assigned':
      case 'picked_up':
      case 'on_way':
        return 3;
      case 'delivered':
        return 4;
      default:
        return 1;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
