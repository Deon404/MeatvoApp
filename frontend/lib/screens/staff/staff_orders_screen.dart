import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/staff_service.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/error_state.dart';
import 'staff_theme.dart';
import 'widgets/staff_order_card.dart';

class StaffOrdersScreen extends ConsumerStatefulWidget {
  const StaffOrdersScreen({
    super.key,
    this.onRegisterCallbacks,
  });

  /// Called from dashboard to wire socket refresh + tab navigation.
  final void Function(StaffOrdersScreenController controller)? onRegisterCallbacks;

  @override
  ConsumerState<StaffOrdersScreen> createState() => StaffOrdersScreenState();
}

/// External control for kitchen tab navigation and reload.
class StaffOrdersScreenController {
  StaffOrdersScreenController({
    required this.reloadOrders,
    required this.goToNewTab,
    required this.goToPreparingTab,
  });

  final Future<void> Function({bool showLoading}) reloadOrders;
  final VoidCallback goToNewTab;
  final VoidCallback goToPreparingTab;
}

class StaffOrdersScreenState extends ConsumerState<StaffOrdersScreen> {
  int _selectedTab = 0;
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _updatingOrderId;

  int get _newCount =>
      _orders.where((o) => (o['status'] ?? '') == 'confirmed').length;

  int get _preparingCount =>
      _orders.where((o) => (o['status'] ?? '') == 'packing_started').length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onRegisterCallbacks?.call(
        StaffOrdersScreenController(
          reloadOrders: _loadOrders,
          goToNewTab: () {
            if (mounted) setState(() => _selectedTab = 0);
          },
          goToPreparingTab: () {
            if (mounted) setState(() => _selectedTab = 1);
          },
        ),
      );
    });
    _loadOrders();
  }

  Future<void> _loadOrders({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final orders = await ref.read(staffServiceProvider).getKitchenOrders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    if (_selectedTab == 0) {
      return _orders
          .where((order) => (order['status'] ?? '') == 'confirmed')
          .toList();
    }
    return _orders
        .where((order) => (order['status'] ?? '') == 'packing_started')
        .toList();
  }

  void _setOrderStatusLocally(String orderId, String status) {
    setState(() {
      _orders = _orders.map((order) {
        if (order['id']?.toString() == orderId) {
          return {...order, 'status': status};
        }
        return order;
      }).toList();
    });
  }

  Future<void> _startPreparing(String orderId) async {
    final previousStatus = _orders
        .firstWhere(
          (o) => o['id']?.toString() == orderId,
          orElse: () => {'status': 'confirmed'},
        )['status']
        ?.toString();

    setState(() => _updatingOrderId = orderId);
    _setOrderStatusLocally(orderId, 'packing_started');

    try {
      await ref.read(staffServiceProvider).startPreparing(orderId);
      if (!mounted) return;
      setState(() => _selectedTab = 1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Preparation started'),
          backgroundColor: StaffColors.surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadOrders(showLoading: false);
    } catch (e) {
      if (!mounted) return;
      _setOrderStatusLocally(orderId, previousStatus ?? 'confirmed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: StaffColors.accent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _updatingOrderId = null);
    }
  }

  Future<void> _markReady(String orderId) async {
    setState(() => _updatingOrderId = orderId);
    try {
      await ref.read(staffServiceProvider).markReady(orderId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Order marked ready for pickup'),
          backgroundColor: StaffColors.surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadOrders(showLoading: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: StaffColors.accent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _updatingOrderId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StaffColors.background,
      appBar: staffAppBar(
        title: 'Butcher Queue',
        actions: [
          IconButton(
            onPressed: _isLoading ? null : () => _loadOrders(),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              StaffSpacing.md,
              StaffSpacing.sm,
              StaffSpacing.md,
              StaffSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _QueueTabButton(
                    label: 'New',
                    count: _newCount,
                    selected: _selectedTab == 0,
                    onTap: () => setState(() => _selectedTab = 0),
                  ),
                ),
                const SizedBox(width: StaffSpacing.sm),
                Expanded(
                  child: _QueueTabButton(
                    label: 'Preparing',
                    count: _preparingCount,
                    selected: _selectedTab == 1,
                    onTap: () => setState(() => _selectedTab = 1),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: StaffColors.accent),
      );
    }

    if (_errorMessage != null) {
      return ErrorStateWidget(
        title: 'Could not load orders',
        message: _errorMessage!,
        onRetry: _loadOrders,
        fullScreen: false,
      );
    }

    final orders = _filteredOrders;
    if (orders.isEmpty) {
      return EmptyStateWidget(
        title: _selectedTab == 0 ? 'No new orders' : 'No orders preparing',
        message: _selectedTab == 0
            ? 'Confirmed orders will appear here.'
            : 'Orders you start preparing will show here.',
        fullScreen: false,
      );
    }

    return RefreshIndicator(
      color: StaffColors.accent,
      backgroundColor: StaffColors.surface,
      onRefresh: () => _loadOrders(showLoading: false),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          StaffSpacing.md,
          0,
          StaffSpacing.md,
          StaffSpacing.lg,
        ),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          final orderId = order['id']?.toString() ?? '';
          final status = (order['status'] ?? '').toString().toLowerCase();
          final isUpdating = _updatingOrderId == orderId;

          return StaffOrderCard(
            order: order,
            isUpdating: isUpdating,
            onStartPreparing:
                status == 'confirmed' ? () => _startPreparing(orderId) : null,
            onMarkReady:
                status == 'packing_started' ? () => _markReady(orderId) : null,
          );
        },
      ),
    );
  }
}

class _QueueTabButton extends StatelessWidget {
  const _QueueTabButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayLabel = count > 0 ? '$label ($count)' : label;

    return Material(
      color: selected ? StaffColors.accent : Colors.transparent,
      borderRadius: BorderRadius.circular(StaffRadius.button),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(StaffRadius.button),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(StaffRadius.button),
            border: Border.all(
              color: selected ? StaffColors.accent : StaffColors.border,
            ),
            color: selected ? StaffColors.accent : StaffColors.surface,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            child: Text(
              displayLabel,
              style: selected ? StaffTextStyles.tabActive : StaffTextStyles.tabInactive,
            ),
          ),
        ),
      ),
    );
  }
}
