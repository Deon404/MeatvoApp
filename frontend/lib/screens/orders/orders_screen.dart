import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../../services/socket_service.dart';
import '../../design_system/tokens/meatvo_spacing.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_transitions.dart';
import '../../utils/eta_display_util.dart';
import '../../utils/order_display_util.dart';
import '../../utils/order_status_util.dart';
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

class _OrdersScreenState extends State<OrdersScreen> {
  static const Color _primaryRed = Color(0xFFC8102E);
  static const Color _chipUnselectedText = Color(0xFF6B6B6B);
  static const Color _chipBorder = Color(0xFFEEEEEE);
  static const Color _progressUnfilled = Color(0xFFEEEEEE);

  final OrderService _orderService = OrderService();
  final SocketService _socketService = SocketService();
  final TextEditingController _searchController = TextEditingController();
  List<OrderModel> _orders = [];
  List<OrderModel> _filteredOrders = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String? _errorMessage;
  String _selectedFilter = 'all';
  String _searchQuery = '';
  Timer? _socketReloadDebounce;

  static const _filters = [
    ('all', 'All'),
    ('active', 'Active'),
    ('completed', 'Completed'),
    ('cancelled', 'Cancelled'),
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadOrders();
    _setupSocketListener();
  }

  void _setupSocketListener() {
    _socketService.connect();
    _socketService.onOrderUpdate(_onOrderStatusSocketEvent);
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
      _applyFilter();
    });
  }

  @override
  void dispose() {
    _socketReloadDebounce?.cancel();
    _socketService.offOrderUpdate();
    _searchController.dispose();
    super.dispose();
  }

  void _selectFilter(String filter) {
    if (_selectedFilter == filter) return;
    setState(() {
      _selectedFilter = filter;
      _applyFilter();
    });
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

  Future<void> _openOrderDetail(String orderId) async {
    await context.pushSlideRight(OrderDetailScreen(orderId: orderId));
    if (!mounted) return;
    await _loadOrders();
  }

  void _applyFilter() {
    List<OrderModel> result;
    switch (_selectedFilter) {
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

    _filteredOrders = result;
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
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppThemeColors.background,
      appBar: AppBar(
        backgroundColor: AppThemeColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: canPop
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppThemeColors.textPrimary,
                ),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search orders...',
                  border: InputBorder.none,
                  isDense: true,
                ),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppThemeColors.textPrimary,
                    ),
              )
            : Text(
                'My Orders',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppThemeColors.textPrimary,
                    ),
              ),
        centerTitle: !_isSearching,
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close_rounded : Icons.search_rounded,
              color: AppThemeColors.textPrimary,
            ),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFilterChips(),
            Expanded(
              child: _isLoading
                  ? const ShimmerLoader.listTile(count: 4)
                  : _errorMessage != null
                      ? _buildErrorState()
                      : _filteredOrders.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: _loadOrders,
                              color: AppThemeColors.primary,
                              child: ListView.builder(
                                padding: EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  MeatvoSpacing.lg,
                                ),
                                itemCount: _filteredOrders.length,
                                itemBuilder: (context, index) {
                                  return _buildOrderCard(
                                      _filteredOrders[index]);
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          for (var i = 0; i < _filters.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _buildFilterChip(_filters[i].$1, _filters[i].$2),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _selectFilter(value);
      },
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? _primaryRed : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _primaryRed : _chipBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : _chipUnselectedText,
          ),
        ),
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

  Widget _buildEmptyState() {
    if (_searchQuery.isNotEmpty) {
      return const EmptyStateWidget(
        title: 'No orders found',
        message: 'Try a different search term.',
      );
    }

    switch (_selectedFilter) {
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

  Widget _buildOrderCard(OrderModel order) {
    final isActive = isOrderActive(order.status);
    final showTrack = isActive;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _openOrderDetail(order.id);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#ORD-${formatOrderDisplayId(order.id)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: _chipUnselectedText,
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildStatusBadge(order.status),
                      if (isActive &&
                          order.estimatedDeliveryTime != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          formatDeliveryByTime(order.estimatedDeliveryTime!),
                          style: const TextStyle(
                            fontSize: 12,
                            color: _chipUnselectedText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _buildItemsSummary(order),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(order.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: _chipUnselectedText,
                    ),
                  ),
                ],
              ),
              if (isActive) ...[
                const SizedBox(height: 12),
                _buildProgressBar(order.status),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    '₹${order.finalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _primaryRed,
                    ),
                  ),
                  const Spacer(),
                  if (showTrack) _buildTrackButton(order.id),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(String status) {
    final filledSegments = _orderProgressSegments(status);

    return Row(
      children: List.generate(4, (index) {
        final isFilled = index < filledSegments;
        return Expanded(
          child: Container(
            height: 3,
            margin: EdgeInsets.only(right: index < 3 ? 4 : 0),
            decoration: BoxDecoration(
              color: isFilled ? _primaryRed : _progressUnfilled,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTrackButton(String orderId) {
    return SizedBox(
      height: 32,
      child: OutlinedButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          _openOrderDetail(orderId);
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          side: const BorderSide(color: _primaryRed),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text(
          'Track Order',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _primaryRed,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    late final Color backgroundColor;
    late final Color textColor;
    late final String label;

    switch (normalizeOrderStatus(status)) {
      case 'delivered':
        backgroundColor = const Color(0xFFE8F5E9);
        textColor = const Color(0xFF2E7D32);
        label = 'Delivered';
        break;
      case 'cancelled':
        backgroundColor = const Color(0xFFFCEBEB);
        textColor = const Color(0xFFC62828);
        label = 'Cancelled';
        break;
      case 'placed':
      case 'pending':
        backgroundColor = const Color(0xFFFFF3E0);
        textColor = const Color(0xFFE65100);
        label = 'Placed';
        break;
      default:
        backgroundColor = const Color(0xFFFFF3E0);
        textColor = const Color(0xFFE65100);
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
