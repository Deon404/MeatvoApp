import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../services/rider_service.dart';
import '../../utils/address_display_util.dart';
import '../../utils/order_display_util.dart';
import '../../widgets/skeletons/shimmer_base.dart';
import 'rider_order_detail_screen.dart';

/// Orders tab — history and active deliveries for the rider.
class RiderOrdersScreen extends StatefulWidget {
  const RiderOrdersScreen({
    super.key,
    this.onRegisterRefresh,
  });

  final void Function(Future<void> Function() refresh)? onRegisterRefresh;

  @override
  State<RiderOrdersScreen> createState() => _RiderOrdersScreenState();
}

class _RiderOrdersScreenState extends State<RiderOrdersScreen>
    with SingleTickerProviderStateMixin {
  final RiderService _riderService = RiderService();
  late final TabController _tabController;

  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _errorMessage;

  static const _tabs = ['Active', 'Completed', 'All'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    widget.onRegisterRefresh?.call(_loadOrders);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final orders = await _riderService.getRiderOrders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _filteredOrders() {
    final tab = _tabs[_tabController.index];
    if (tab == 'All') return _orders;
    if (tab == 'Completed') {
      return _orders.where((a) {
        final status = (a['status'] as String? ?? '').toLowerCase();
        return status == 'delivered' || status == 'cancelled';
      }).toList();
    }
    return _orders.where((a) {
      final status = (a['status'] as String? ?? '').toLowerCase();
      return status != 'delivered' && status != 'cancelled';
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredOrders();

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F7),
      appBar: AppBar(
        title: const Text('My Orders'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadOrders,
        child: _buildBody(filtered),
      ),
    );
  }

  Widget _buildBody(List<Map<String, dynamic>> filtered) {
    if (_isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: List.generate(
          4,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ShimmerBase(
              child: Container(
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Icon(Icons.error_outline, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(onPressed: _loadOrders, child: const Text('Retry')),
          ),
        ],
      );
    }

    if (filtered.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Icon(Icons.inbox_outlined, size: 56, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(
            'No ${_tabs[_tabController.index].toLowerCase()} orders',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pull down to refresh',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: filtered.length,
      itemBuilder: (context, index) => _OrderCard(
        assignment: filtered[index],
        onTap: () async {
          final assignmentId = filtered[index]['id']?.toString() ?? '';
          if (assignmentId.isEmpty) return;
          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => RiderOrderDetailScreen(assignmentId: assignmentId),
            ),
          );
          if (mounted) await _loadOrders();
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.assignment, required this.onTap});

  final Map<String, dynamic> assignment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final order = assignment['order'] as Map<String, dynamic>?;
    if (order == null) return const SizedBox.shrink();

    final status = assignment['status'] as String? ?? 'assigned';
    final orderId = order['id']?.toString() ?? '';
    final title = riderOrderTitle(order);
    final address = order['delivery_address'] ?? order['address'];
    final addressText = formatAddressForDisplay(address);
    final totalPrice = (order['total_price'] as num?)?.toDouble() ?? 0.0;

    final (Color accent, String label) = switch (status) {
      'assigned' => (Colors.blue, 'New'),
      'accepted' => (AppColors.success, 'Active'),
      'picked_up' => (AppColors.warning, 'Picked Up'),
      'delivered' => (AppColors.success, 'Delivered'),
      'cancelled' => (AppColors.textSecondary, 'Cancelled'),
      _ => (AppColors.primary, status),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '#${formatOrderDisplayId(orderId)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  addressText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      '₹${totalPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
