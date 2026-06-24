import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../config/store_config.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/map_markers.dart';
import '../../services/admin_service.dart';
import '../../utils/address_display_util.dart' show formatAddressForDisplay, resolveAddressCoords;
import '../../utils/responsive_helper.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/error_state.dart';
import '../../widgets/admin/admin_navigation_drawer.dart';

/// Admin map view of active orders with location pins.
class AdminOrdersMapScreen extends StatefulWidget {
  const AdminOrdersMapScreen({super.key});

  @override
  State<AdminOrdersMapScreen> createState() => _AdminOrdersMapScreenState();
}

class _AdminOrdersMapScreenState extends State<AdminOrdersMapScreen>
    with TickerProviderStateMixin {
  final _adminService = AdminService();
  final _dateFormat = DateFormat('MMM d, yyyy');

  GoogleMapController? _mapController;
  late TabController _tabController;

  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _routeStops = [];
  Map<String, dynamic>? _selectedStop;

  Set<Marker> _markers = {};

  bool _isLoading = true;
  String? _loadError;
  String? _assigningOrderId;

  Map<String, BitmapDescriptor> _markerCache = {};

  static const _inactiveStatuses = {
    'delivered',
    'cancelled',
    'refunded',
    'failed',
    'payment_pending',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  String get _dateChipLabel {
    final now = DateTime.now();
    if (_selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day) {
      return 'Today';
    }
    return _dateFormat.format(_selectedDate);
  }

  String get _locationSummaryLabel {
    final withoutLocation = _orders.length - _routeStops.length;
    if (withoutLocation <= 0) return 'all located';
    return '$withoutLocation without location';
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
      _selectedStop = null;
      _markerCache = {};
    });

    try {
      final start = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      final end = start.add(const Duration(days: 1));

      final orders = await _adminService.getAllOrders(fromDate: start, toDate: end);
      final activeOrders = orders.where(_isActiveOrder).toList();

      if (!mounted) return;
      setState(() {
        _orders = activeOrders;
        _routeStops = _buildStopsFromOrderList(activeOrders);
        _isLoading = false;
      });

      await _buildActiveOrderMapElements();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _isLoading = false;
        _orders = [];
        _routeStops = [];
      });
    }
  }

  bool _isActiveOrder(Map<String, dynamic> order) {
    final status = (order['status'] ?? '').toString().toLowerCase();
    if (status.isEmpty) return false;
    return !_inactiveStatuses.contains(status);
  }

  Future<void> _buildActiveOrderMapElements() async {
    final storeLocation = LatLng(
      StoreConfig.storeLatitude,
      StoreConfig.storeLongitude,
    );

    final markers = <Marker>{};
    final storeMarker = await _createStoreMarker(storeLocation);
    markers.add(storeMarker);

    final orderStops = _buildStopsFromOrders();
    for (final stop in orderStops) {
      final marker = await _createOrderMarker(stop);
      markers.add(marker);
    }

    setState(() => _markers = markers);

    if (_mapController != null && markers.length > 1) {
      _fitCameraToBounds();
    }
  }

  List<Map<String, dynamic>> _buildStopsFromOrders() =>
      _buildStopsFromOrderList(_orders);

  List<Map<String, dynamic>> _buildStopsFromOrderList(
    List<Map<String, dynamic>> orders,
  ) {
    final stops = <Map<String, dynamic>>[];

    for (final order in orders) {
      final coords = resolveAddressCoords(order);
      final lat = coords.lat;
      final lng = coords.lng;
      if (lat == null || lng == null || lat == 0 || lng == 0) continue;

      final user = order['user'] as Map<String, dynamic>? ?? {};
      stops.add({
        'orderId': (order['id'] ?? '').toString(),
        'customerName': user['name'] ?? 'Customer',
        'customerPhone': user['phone'] ?? '',
        'address': _orderAddress(order),
        'latitude': lat,
        'longitude': lng,
        'status': (order['status'] ?? '').toString(),
        'order': order,
      });
    }

    return stops;
  }

  String _orderAddress(Map<String, dynamic> order) {
    final address = order['delivery_address'] ?? order['address'];
    return formatAddressForDisplay(address);
  }

  Future<Marker> _createStoreMarker(LatLng position) async {
    final icon = await MapMarkers.storeMarker();

    return Marker(
      markerId: const MarkerId('store'),
      position: position,
      icon: icon,
      anchor: const Offset(0.5, 0.5),
      zIndex: 2,
    );
  }

  Future<Marker> _createOrderMarker(Map<String, dynamic> stop) async {
    final orderId = stop['orderId'] as String;
    final status = _resolveMarkerStatus(stop);
    final cacheKey = 'order_$orderId';

    BitmapDescriptor icon;
    if (_markerCache.containsKey(cacheKey)) {
      icon = _markerCache[cacheKey]!;
    } else {
      icon = await MapMarkers.orderIdPin(
        orderId,
        assigned: status == 'assigned',
      );
      _markerCache[cacheKey] = icon;
    }

    return Marker(
      markerId: MarkerId('order_$orderId'),
      position: LatLng(
        stop['latitude'] as double,
        stop['longitude'] as double,
      ),
      icon: icon,
      anchor: const Offset(0.5, 1.0),
      onTap: () => _onMarkerTapped(stop),
    );
  }

  String _resolveMarkerStatus(Map<String, dynamic> stop) {
    final order = stop['order'] as Map<String, dynamic>?;
    if (order != null && order['assignment'] != null) return 'assigned';

    final raw = (stop['status'] ?? '').toString().toUpperCase();
    if (raw == 'ASSIGNED' || raw == 'assigned') return 'assigned';
    if (raw == 'PACKED' || raw == 'packed') return 'packed';
    return 'confirmed';
  }

  void _onMarkerTapped(Map<String, dynamic> stop) {
    setState(() => _selectedStop = stop);
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(
          stop['latitude'] as double,
          stop['longitude'] as double,
        ),
        15,
      ),
    );
  }

  void _fitCameraToBounds() {
    if (_markers.isEmpty) return;

    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (final marker in _markers) {
      final lat = marker.position.latitude;
      final lng = marker.position.longitude;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        72,
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (picked == null) return;
    setState(() => _selectedDate = picked);
    await _loadData();
  }

  Map<String, dynamic>? _findOrder(String orderId) {
    for (final order in _orders) {
      if ((order['id'] ?? '').toString() == orderId) return order;
    }
    return null;
  }

  Future<void> _assignRider(String orderId, String riderId) async {
    setState(() => _assigningOrderId = orderId);
    try {
      await _adminService.assignRiderToOrder(orderId, riderId);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rider assigned successfully'),
          backgroundColor: AppColors.success,
        ),
      );
      setState(() => _selectedStop = null);
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to assign rider: $e'),
          backgroundColor: AppColors.primary,
        ),
      );
    } finally {
      if (mounted) setState(() => _assigningOrderId = null);
    }
  }

  Future<void> _showAssignRiderSheet({required String orderId}) async {
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
                      final user =
                          rider['user'] as Map<String, dynamic>? ?? {};
                      final isLoading = _assigningOrderId == orderId;

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
                        trailing: isLoading
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
                                    _assignRider(orderId, rider['id']),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AdminNavigationDrawer(
        currentSection: AdminNavSection.routeMap,
        onLogout: () => AdminNavigationDrawer.confirmLogout(context),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _loadError != null
              ? ErrorStateWidget(
                  title: 'Unable to load map data',
                  message: _loadError,
                  icon: Icons.map_outlined,
                  iconColor: AppColors.primary,
                  onRetry: _loadData,
                )
              : Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(
                          StoreConfig.storeLatitude,
                          StoreConfig.storeLongitude,
                        ),
                        zoom: 13,
                      ),
                      markers: _markers,
                      polylines: const {},
                      myLocationEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      onMapCreated: (controller) {
                        _mapController = controller;
                        if (_markers.length > 1) _fitCameraToBounds();
                      },
                      onTap: (_) => setState(() => _selectedStop = null),
                    ),
                    SafeArea(child: Builder(builder: _buildTopBar)),
                    if (_selectedStop != null)
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: MediaQuery.sizeOf(context).height * 0.34,
                        child: _buildOrderPopup(_selectedStop!),
                      ),
                    DraggableScrollableSheet(
                      initialChildSize: 0.32,
                      minChildSize: 0.18,
                      maxChildSize: 0.72,
                      builder: (context, scrollController) {
                        return _buildBottomSheet(scrollController);
                      },
                    ),
                  ],
                ),
    );
  }

  Widget _buildTopBar(BuildContext scaffoldContext) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Scaffold.of(scaffoldContext).openDrawer(),
            icon: const Icon(Icons.menu),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'Orders Map',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          ActionChip(
            label: Text(_dateChipLabel),
            avatar: const Icon(Icons.calendar_today, size: 16),
            onPressed: _selectDate,
            backgroundColor: Colors.white,
            side: const BorderSide(color: AppColors.divider),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildOrderPopup(Map<String, dynamic> stop) {
    final orderId = stop['orderId'] as String;
    final order = _findOrder(orderId);
    final status = order?['status'] ?? stop['status'];
    final amount = order?['total_price'] ?? 0;

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order #$orderId',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _selectedStop = null),
                  icon: const Icon(Icons.close, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Text(
              stop['customerName'] as String? ?? 'Customer',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildStatusBadge(status),
                const Spacer(),
                Text(
                  '₹${_formatAmount(amount)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showAssignRiderSheet(orderId: orderId),
                icon: const Icon(Icons.delivery_dining, size: 18),
                label: const Text('Assign Rider'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheet(ScrollController scrollController) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _buildSummaryCard(),
          ),
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'Active Orders'),
              Tab(text: 'All Orders'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildActiveOrdersTab(scrollController),
                _buildAllOrdersTab(scrollController),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.greyLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Text(
        '$_dateChipLabel: ${_orders.length} active orders | '
        '${_routeStops.length} on map | $_locationSummaryLabel',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildActiveOrdersTab(ScrollController scrollController) {
    final stops = _routeStops;

    if (stops.isEmpty) {
      return EmptyStateWidget(
        title: _orders.isEmpty ? 'No active orders' : 'No locations on map',
        message: _orders.isEmpty
            ? 'Active orders for $_dateChipLabel will appear here.'
            : '${_orders.length} active order(s) found but none have delivery coordinates.',
        illustration: const Icon(
          Icons.location_off_outlined,
          size: 48,
          color: AppColors.textSecondary,
        ),
        buttonLabel: 'Refresh',
        onAction: _loadData,
        fullScreen: false,
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: stops.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, index) {
        final stop = stops[index];
        return _buildActiveOrderRow(stop);
      },
    );
  }

  Widget _buildActiveOrderRow(Map<String, dynamic> stop) {
    final orderId = stop['orderId'] as String;
    final status = stop['status'];

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary),
        ),
        child: Text(
          '#$orderId',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ),
      title: Text(
        stop['customerName'] as String? ?? 'Customer',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        (stop['address'] as String?)?.isNotEmpty == true
            ? stop['address'] as String
            : 'Tap to view on map',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: _buildStatusBadge(status),
      onTap: () => _onMarkerTapped(stop),
    );
  }

  Widget _buildAllOrdersTab(ScrollController scrollController) {
    if (_orders.isEmpty) {
      return EmptyStateWidget(
        title: 'No active orders',
        message: 'Active orders for $_dateChipLabel will appear here.',
        illustration: const Icon(
          Icons.receipt_long,
          size: 48,
          color: AppColors.textSecondary,
        ),
        buttonLabel: 'Refresh',
        onAction: _loadData,
        fullScreen: false,
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _orders.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, index) => _buildCompactOrderRow(_orders[index]),
    );
  }

  Widget _buildCompactOrderRow(Map<String, dynamic> order) {
    final user = order['user'] as Map<String, dynamic>? ?? {};
    final orderId = (order['id'] ?? '').toString();

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          Text(
            '#$orderId',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              user['name'] ?? 'Customer',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: _buildStatusBadge(order['status']),
      ),
      trailing: Text(
        '₹${_formatAmount(order['total_price'])}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      onTap: () {
        final coords = resolveAddressCoords(order);
        final lat = coords.lat;
        final lng = coords.lng;
        if (lat != null && lng != null) {
          _onMarkerTapped({
            'orderId': orderId,
            'customerName': user['name'] ?? 'Customer',
            'latitude': lat,
            'longitude': lng,
            'status': order['status'],
            'order': order,
          });
        }
      },
    );
  }

  Widget _buildStatusBadge(dynamic status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _formatStatus(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Color _statusColor(dynamic status) {
    final value = (status ?? '').toString().toLowerCase();
    switch (value) {
      case 'packed':
        return AppColors.bluePrimary;
      case 'assigned':
        return AppColors.textSecondary;
      case 'accepted':
      case 'confirmed':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatStatus(dynamic status) {
    final value = (status ?? '').toString();
    if (value.isEmpty) return 'Unknown';
    return value
        .split('_')
        .map((part) =>
            part.isEmpty ? part : part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  String _formatAmount(dynamic amount) {
    if (amount == null) return '0';
    if (amount is num) return amount.toStringAsFixed(0);
    return double.tryParse(amount.toString())?.toStringAsFixed(0) ?? '0';
  }
}
