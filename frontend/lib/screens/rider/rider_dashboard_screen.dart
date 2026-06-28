import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../models/earnings_data.dart';
import '../../services/push_notification_service.dart';
import '../../services/rider_service.dart';
import '../../services/socket_service.dart';
import '../../providers/rider_provider.dart';
import '../../config/store_config.dart';
import '../../core/constants/app_constants.dart';
import '../../utils/address_display_util.dart';
import '../../utils/order_display_util.dart';
import '../../utils/responsive_helper.dart';
import '../../services/maps_service.dart';
import '../../utils/role_access.dart';
import '../../utils/role_access_exception.dart';
import '../../widgets/skeletons/shimmer_base.dart';
import 'rider_orders_screen.dart';
import 'rider_profile_screen.dart';
import 'batch_delivery_screen.dart';
import 'rider_order_detail_screen.dart';
import 'widgets/rider_bottom_nav.dart';

/// Rider Dashboard Screen - Main screen for riders
class RiderDashboardScreen extends ConsumerStatefulWidget {
  const RiderDashboardScreen({super.key});

  @override
  ConsumerState<RiderDashboardScreen> createState() =>
      _RiderDashboardScreenState();
}

class _RiderDashboardScreenState extends ConsumerState<RiderDashboardScreen> {
  final RiderService _riderService = RiderService();
  final SocketService _socketService = SocketService();
  final MapsService _mapsService = MapsService();
  final PushNotificationService _pushNotifications = PushNotificationService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  Map<String, dynamic>? _riderProfile;
  EarningsData? _earnings;
  List<Map<String, dynamic>> _activeOrders = [];
  bool _isLoading = true;
  bool _isLoadingOrders = true;
  bool _isLoadingEarnings = true;
  String? _loadError;
  String? _ordersError;
  String? _earningsError;
  int _currentIndex = 0;
  final List<GlobalKey<NavigatorState>> _tabNavigatorKeys =
      List.generate(3, (_) => GlobalKey<NavigatorState>());
  Future<void> Function()? _refreshOrdersTab;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeDashboard());
  }

  Future<void> _initializeDashboard() async {
    try {
      final allowed = await ensureDeliveryPartnerAccess(context);
      if (!mounted) return;
      if (!allowed) {
        setState(() => _isLoading = false);
        return;
      }

      await _loadDashboardData();
      // Realtime setup must not block the home tab spinner.
      unawaited(_subscribeToOrderAssignments());
      unawaited(_subscribeToAssignmentSocketEvents());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.toString();
      });
    } finally {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _socketService.offOrderAssigned();
    _socketService.offOrderAutoAccepted();
    _socketService.offRouteZoneAssigned();
    _socketService.offOrderAssignmentCancelled();
    _riderService.disposeRealtime();
    ref.read(riderAssignmentAlertsProvider.notifier).clear();
    _audioPlayer.dispose();
    super.dispose();
  }

  int? _parseOrderId(dynamic data) {
    if (data is Map) {
      final raw = data['orderId'] ?? data['order_id'] ?? data['id'];
      return int.tryParse(raw?.toString() ?? '');
    }
    return int.tryParse(data?.toString() ?? '');
  }

  List<int> _parseOrderIds(dynamic data) {
    if (data is Map) {
      final rawList = data['orderIds'] ?? data['order_ids'];
      if (rawList is List && rawList.isNotEmpty) {
        return rawList
            .map((value) => int.tryParse(value?.toString() ?? ''))
            .whereType<int>()
            .toList();
      }
    }
    final single = _parseOrderId(data);
    return single == null ? <int>[] : [single];
  }

  String _batchAlertKey(List<int> orderIds) {
    final sorted = [...orderIds]..sort();
    return sorted.join(',');
  }

  bool _isBatchAssignment(dynamic data) {
    if (data is Map) {
      if (data['isBatch'] == true) return true;
      return _parseOrderIds(data).length > 1;
    }
    return false;
  }

  void _showAssignmentSnackBar({
    required String message,
    String? orderId,
    bool isError = false,
  }) {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? AppColors.primary : AppColors.success,
        action: orderId == null
            ? null
            : SnackBarAction(
                label: 'View',
                textColor: Colors.white,
                onPressed: () {
                  if (!context.mounted) return;
                  _pushOnTab(
                    0,
                    RiderOrderDetailScreen(assignmentId: orderId),
                  );
                },
              ),
      ),
    );
  }

  String _extractAddressText(dynamic addr) {
    if (addr == null) return 'Address not available';
    if (addr is String) return addr.isNotEmpty ? addr : 'Address not available';
    if (addr is Map) {
      final formatted = addr['formatted'] ?? addr['formatted_address'];
      if (formatted != null && formatted.toString().isNotEmpty) {
        return formatted.toString();
      }
      final text = addr['text'] ?? addr['raw'] ?? addr['address'];
      if (text != null && text.toString().isNotEmpty) {
        return text.toString();
      }
    }
    return 'Address not available';
  }

  Map<String, dynamic> _assignmentToAlertData(Map<String, dynamic> assignment) {
    final order = assignment['order'] as Map<String, dynamic>? ?? {};
    return {
      'orderId': assignment['id'] ?? order['id'],
      'totalAmount': order['total_amount'] ?? order['totalAmount'] ?? order['total_price'],
      'total_amount': order['total_amount'] ?? order['totalAmount'],
      'total_price': order['total_price'] ?? order['total_amount'],
      'customerAddress': _extractAddressText(
          order['delivery_address'] ?? order['address']),
      'address': _extractAddressText(
          order['delivery_address'] ?? order['address']),
      'delivery_address': _extractAddressText(
          order['delivery_address'] ?? order['address']),
    };
  }

  void _notifyNewAssignment(dynamic data) {
    final orderIds = _parseOrderIds(data);
    _loadDashboardData(force: true);
    _refreshOrdersTab?.call();

    if (orderIds.isEmpty) {
      _showAssignmentSnackBar(message: 'New order assigned!');
      return;
    }

    final isBatch = _isBatchAssignment(data);
    final primaryOrderId = orderIds.first;
    final batchLabel = isBatch ? '${orderIds.length} nearby orders' : 'order #$primaryOrderId';

    _pushNotifications.showOrderAssignment(
      orderId: primaryOrderId,
      body: isBatch ? 'Batch delivery — tap to review $batchLabel' : 'Tap to view order #$primaryOrderId',
    );

    final alertKey = _batchAlertKey(orderIds);
    if (ref
        .read(riderAssignmentAlertsProvider.notifier)
        .containsAssignment(alertKey)) {
      return;
    }

    final alertData = data is Map
        ? Map<String, dynamic>.from(data)
        : <String, dynamic>{'orderId': primaryOrderId};
    alertData.putIfAbsent('orderId', () => primaryOrderId);
    alertData.putIfAbsent('orderIds', () => orderIds);
    alertData.putIfAbsent('isBatch', () => isBatch);
    alertData.putIfAbsent('batchCount', () => orderIds.length);
    _showNewOrderAlert(alertData, orderIds);
  }

  void _handleZoneAssigned(dynamic data) {
    final zoneId = data is Map ? data['zoneId']?.toString() : null;
    final orderCount = data is Map ? data['orderCount'] : null;
    _loadDashboardData(force: true);
    _refreshOrdersTab?.call();
    final countLabel = orderCount != null ? '$orderCount orders' : 'new orders';
    _showAssignmentSnackBar(
      message: zoneId == null
          ? 'New delivery zone assigned ($countLabel)'
          : 'Zone $zoneId assigned ($countLabel)',
    );
  }

  void _handleAssignmentAssigned(dynamic data) {
    if (data is! Map) {
      _notifyNewAssignment(data);
      return;
    }

    final map = Map<String, dynamic>.from(data);
    final rawOrderIds = map['orderIds'] as List?;
    final parsedOrderIds = rawOrderIds != null && rawOrderIds.isNotEmpty
        ? rawOrderIds
            .map((value) => int.tryParse(value.toString()))
            .whereType<int>()
            .toList()
        : () {
            final single = _parseOrderId(map);
            return single != null ? [single] : <int>[];
          }();

    final isBatch = map['isBatch'] == true;
    final batchCount = (map['batchCount'] as num?)?.toInt() ??
        (parsedOrderIds.isNotEmpty ? parsedOrderIds.length : 1);

    map['orderIds'] = parsedOrderIds;
    map['isBatch'] = isBatch;
    map['batchCount'] = batchCount;
    if (parsedOrderIds.isNotEmpty) {
      map.putIfAbsent('orderId', () => parsedOrderIds.first);
    }

    _notifyNewAssignment(map);
  }

  void _showNewOrderAlert(Map<dynamic, dynamic> orderData, List<int> orderIds) {
    if (!mounted || orderIds.isEmpty) return;

    final primaryOrderId = orderIds.first;
    final alertKey = _batchAlertKey(orderIds);
    final alerts = ref.read(riderAssignmentAlertsProvider.notifier);
    alerts.addAssignment(alertKey);
    alerts.addOrder(primaryOrderId.toString());

    try {
      _audioPlayer.play(AssetSource('sounds/new_order.mp3'));
    } catch (e) {
      debugPrint('Failed to play notification sound: $e');
    }

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NewOrderAlertSheet(
        orderData: orderData,
        onAccept: () => _acceptOrders(orderIds),
        onReject: () => _rejectOrders(orderIds, 'Declined from alert'),
        onTimeout: () => _handleAssignmentSheetTimeout(orderIds),
      ),
    ).whenComplete(() {
      final alerts = ref.read(riderAssignmentAlertsProvider.notifier);
      alerts.removeAssignment(alertKey);
      alerts.removeOrder(primaryOrderId.toString());
    });
  }

  Future<void> _acceptOrders(List<int> orderIds) async {
    if (!mounted || orderIds.isEmpty) return;

    try {
      final stringIds = orderIds.map((id) => id.toString()).toList();
      await _riderService.acceptOrders(stringIds);
      await _loadDashboardData(force: true);
      _refreshOrdersTab?.call();

      if (mounted) {
        final label = orderIds.length > 1
            ? '${orderIds.length} orders accepted!'
            : 'Order #${orderIds.first} accepted!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(label),
            backgroundColor: AppColors.success,
          ),
        );

        if (orderIds.length > 1) {
          _pushOnTab(0, BatchDeliveryScreen(orderIds: stringIds));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectOrders(List<int> orderIds, [String reason = '']) async {
    if (!mounted || orderIds.isEmpty) return;

    try {
      await _riderService.rejectOrders(
        orderIds.map((id) => id.toString()).toList(),
        reason,
      );
      await _loadDashboardData(force: true);
      _refreshOrdersTab?.call();

      if (mounted) {
        final label = orderIds.length > 1
            ? '${orderIds.length} orders declined'
            : 'Order #${orderIds.first} rejected';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(label),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleAssignmentSheetTimeout(List<int> orderIds) {
    if (!mounted || orderIds.isEmpty) return;
    final label = orderIds.length > 1
        ? '${orderIds.length} orders auto-assigned to nearest online rider'
        : 'Order #${orderIds.first} auto-assigned to nearest online rider';
    _showAssignmentSnackBar(
      message: label,
      orderId: orderIds.first.toString(),
    );
    _loadDashboardData(force: true);
    _refreshOrdersTab?.call();
  }

  void _handleOrderAutoAccepted(dynamic data) {
    final orderId = _parseOrderId(data);
    _loadDashboardData(force: true);
    _refreshOrdersTab?.call();
    if (orderId == null || !mounted) return;
    _showAssignmentSnackBar(
      message: 'Order #$orderId auto-accepted (nearest to store)',
      orderId: orderId.toString(),
    );
  }

  void _handleAssignmentCancelled(dynamic data) {
    final orderId = _parseOrderId(data);
    final reason = data is Map ? data['reason']?.toString() : null;
    if (mounted && orderId != null) {
      setState(() {
        _activeOrders.removeWhere((assignment) {
          final order = assignment['order'] as Map<String, dynamic>?;
          final id = order?['id']?.toString();
          return id == orderId.toString();
        });
      });
      if (reason == 'timeout' || reason == 'auto_reassigned') {
        ref
            .read(riderAssignmentAlertsProvider.notifier)
            .removeOrder(orderId.toString());
      }
    }
    _loadDashboardData(force: true);
    _refreshOrdersTab?.call();
    _showAssignmentSnackBar(
      message: orderId == null
          ? 'An order assignment was cancelled'
          : 'Order #$orderId assignment cancelled',
      isError: true,
    );
  }

  Future<void> _subscribeToAssignmentSocketEvents() async {
    try {
      await _socketService.connect();
      _socketService.onOrderAssigned(_handleAssignmentAssigned);
      _socketService.onOrderAutoAccepted(_handleOrderAutoAccepted);
      _socketService.onRouteZoneAssigned(_handleZoneAssigned);
      _socketService.onOrderAssignmentCancelled(_handleAssignmentCancelled);
    } catch (e) {
      debugPrint('Rider socket subscription failed: $e');
    }
  }

  /// Subscribe to realtime order assignments (polling fallback)
  Future<void> _subscribeToOrderAssignments() async {
    try {
      await _riderService.subscribeToOrderAssignments(
        onRoleAccessDenied: handleRoleAccessDenied,
        onNewAssignment: (assignment) {
          _notifyNewAssignment(_assignmentToAlertData(assignment));
        },
        onAssignmentUpdated: () {
          if (context.mounted) {
            _loadDashboardData(force: true);
          }
        },
      );
    } catch (e) {
      debugPrint('Error subscribing to order assignments: $e');
    }
  }

  DateTime? _lastLoadTime;

  List<Map<String, dynamic>> _filterActiveOrders(
    List<Map<String, dynamic>> orders,
  ) {
    return orders
        .where((assignment) {
          final status = (assignment['status'] as String? ?? '').toLowerCase();
          return status != 'delivered' && status != 'cancelled';
        })
        .toList()
      ..sort((a, b) {
        final aOrder = a['order'] as Map<String, dynamic>?;
        final bOrder = b['order'] as Map<String, dynamic>?;
        final aId = int.tryParse(
              aOrder?['id']?.toString() ?? a['id']?.toString() ?? '0',
            ) ??
            0;
        final bId = int.tryParse(
              bOrder?['id']?.toString() ?? b['id']?.toString() ?? '0',
            ) ??
            0;
        return bId.compareTo(aId);
      });
  }

  Future<void> _loadDashboardData({bool force = false}) async {
    // Debounce routine refreshes, but always reload on new assignments.
    final now = DateTime.now();
    if (!force &&
        _lastLoadTime != null &&
        now.difference(_lastLoadTime!) < const Duration(seconds: 3)) {
      debugPrint('[Dashboard] Skipping load - too soon after last load');
      return;
    }
    _lastLoadTime = now;

    final showFullScreenLoader = _riderProfile == null;
    setState(() {
      if (showFullScreenLoader) _isLoading = true;
      _isLoadingOrders = true;
      _isLoadingEarnings = true;
      _loadError = null;
      _ordersError = null;
      _earningsError = null;
    });

    // Profile first — home tab should not stay blank while orders query runs.
    try {
      final profile = await _riderService.getRiderProfile().timeout(
        const Duration(seconds: 25),
        onTimeout: () => throw TimeoutException(
          'Rider profile request timed out. Check your internet connection.',
        ),
      );

      if (mounted) {
        setState(() {
          _riderProfile = profile;
          _loadError = null;
          _isLoading = false;
        });
      }

      unawaited(_loadOrdersAndEarnings());
    } on RoleAccessException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingOrders = false;
          _isLoadingEarnings = false;
        });
        await handleRoleAccessDenied(e);
      }
    } on TimeoutException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingOrders = false;
          _isLoadingEarnings = false;
          _loadError = e.message ?? e.toString();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingOrders = false;
          _isLoadingEarnings = false;
          _loadError = e.toString();
        });
        if (e.toString().contains('429') ||
            e.toString().contains('Too many requests')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Too many requests. Please wait a moment.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading dashboard: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _loadOrdersAndEarnings() async {
    try {
      final orders = await _riderService.getRiderOrders().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException(
          'Orders request timed out. Pull down to retry.',
        ),
      );
      if (mounted) {
        setState(() {
          _activeOrders = _filterActiveOrders(orders);
          _ordersError = null;
          _isLoadingOrders = false;
        });
      }
    } on RoleAccessException catch (e) {
      if (mounted) {
        setState(() => _isLoadingOrders = false);
        await handleRoleAccessDenied(e);
      }
      return;
    } on TimeoutException catch (e) {
      if (mounted) {
        setState(() {
          _ordersError = e.message ?? e.toString();
          _isLoadingOrders = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _ordersError = e.toString();
          _isLoadingOrders = false;
        });
      }
    }

    await _loadEarnings();
  }

  Future<void> _loadEarnings() async {
    if (mounted) {
      setState(() {
        _isLoadingEarnings = true;
        _earningsError = null;
      });
    }
    try {
      final earnings = await _riderService.getRiderEarnings();
      if (mounted) {
        setState(() {
          _earnings = earnings;
          _isLoadingEarnings = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _earningsError = e.toString();
          _isLoadingEarnings = false;
        });
      }
    }
  }

  Future<void> _updateStatus(String status) async {
    try {
      double? lat;
      double? lng;
      if (status == 'available') {
        final position = await _mapsService.getCurrentLocation(
          forceRequest: true,
          timeLimit: const Duration(seconds: 10),
        );
        if (position != null) {
          lat = position.latitude;
          lng = position.longitude;
        }
      }
      await _riderService.updateRiderStatus(
        status,
        lat: lat,
        lng: lng,
      );
      if (mounted) {
        setState(() {
          _riderProfile = {
            ...?_riderProfile,
            'status': status,
            'online': status == 'available',
          };
        });
      }
      await _loadDashboardData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getCurrentStatus() {
    final status = _riderProfile?['status'] as String?;
    if (status != null && status.isNotEmpty) return status;
    final online = _riderProfile?['online'] == true;
    return online ? 'available' : 'offline';
  }

  Future<T?> _pushOnTab<T>(int tabIndex, Widget screen) {
    return _tabNavigatorKeys[tabIndex].currentState!.push<T>(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) {
      _tabNavigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          RiderTabNavigator(
            navigatorKey: _tabNavigatorKeys[0],
            root: _buildDashboardTab(),
          ),
          RiderTabNavigator(
            navigatorKey: _tabNavigatorKeys[1],
            root: RiderOrdersScreen(
              onRegisterRefresh: (refresh) {
                _refreshOrdersTab = refresh;
              },
            ),
          ),
          RiderTabNavigator(
            navigatorKey: _tabNavigatorKeys[2],
            root: const RiderProfileScreen(),
          ),
        ],
      ),
      bottomNavigationBar: RiderBottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }

  Widget _buildDashboardTab() {
    final isOnline = _getCurrentStatus() == 'available';

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFFAF9F7),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFC8102E),
                ),
              )
            : _loadError != null && _riderProfile == null && _activeOrders.isEmpty
                ? _buildLoadErrorState()
                : Column(
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadDashboardData,
                      color: const Color(0xFFC8102E),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildRiderInfoCardSimple(),
                            const SizedBox(height: 12),
                            _buildStatsCard(),
                            const SizedBox(height: 20),
                            if (_isLoadingOrders)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 32),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFFC8102E),
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            else if (_ordersError != null)
                              _buildOrdersErrorState()
                            else if (_activeOrders.isEmpty)
                              _buildEmptyState(isOnline)
                            else ...[
                              const Text(
                                'Active Orders',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ..._activeOrders.map((order) => _buildOrderCardNew(order)),
                            ],
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _buildSwipeToggleBottom(isOnline),
                ],
              ),
      ),
    );
  }

  Widget _buildOrdersErrorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: Color(0xFF9E9E9E),
          ),
          const SizedBox(height: 12),
          const Text(
            'Could not load orders',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _ordersError!,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B6B6B),
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => _loadOrdersAndEarnings(),
            child: const Text('Retry orders'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off,
              size: 64,
              color: Color(0xFF9E9E9E),
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not load rider dashboard',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _loadError!,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B6B6B),
              ),
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadDashboardData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC8102E),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiderInfoCardSimple() {
    final user = _riderProfile?['user'] as Map<String, dynamic>?;
    final rawName = _riderProfile?['name']?.toString().trim() ??
        user?['name']?.toString().trim() ??
        '';
    final phone = _riderProfile?['phone']?.toString().trim() ??
        user?['phone']?.toString().trim() ??
        '';
    final riderName =
        rawName.isNotEmpty ? rawName : (phone.isNotEmpty ? phone : 'Rider');
    final vehicleNumber = _riderProfile?['vehicleNumber']?.toString() ??
                          _riderProfile?['vehicle_number']?.toString() ??
                          'N/A';
    final initial = riderName.isNotEmpty ? riderName[0].toUpperCase() : 'R';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFC8102E),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  riderName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  vehicleNumber,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B6B6B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeToggleBottom(bool isOnline) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        child: _SwipeToToggle(
          isOnline: isOnline,
          onToggle: _toggleOnlineStatus,
        ),
      ),
    );
  }

  void _toggleOnlineStatus() {
    final currentStatus = _getCurrentStatus();
    final newStatus = currentStatus == 'available' ? 'offline' : 'available';
    _updateStatus(newStatus);
  }

  Widget _buildStatsCard() {
    final todayEarnings = _earnings?.today ?? 0.0;
    final weekEarnings = _earnings?.thisWeek ?? 0.0;
    final deliveries = _earnings?.completedDeliveries ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE31E24), Color(0xFFB71C1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33C8102E),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "TODAY'S EARNINGS",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          if (_isLoadingEarnings)
            const SizedBox(
              height: 36,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          else
            Text(
              '₹${todayEarnings.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          if (_earningsError != null) ...[
            const SizedBox(height: 4),
            Text(
              'Could not load earnings',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              _earningsPill('This Week', '₹${weekEarnings.toStringAsFixed(0)}'),
              const SizedBox(width: 10),
              _earningsPill('This Month', '$deliveries deliveries'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _earningsPill(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.white70),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFC8102E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF6B6B6B),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isOnline) {
    if (isOnline) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Icon(
              Icons.delivery_dining,
              size: 120,
              color: const Color(0xFFEEEEEE),
            ),
            const SizedBox(height: 16),
            const Text(
              'Stay Online',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You will receive pickup soon...',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B6B6B),
              ),
            ),
          ],
        ),
      );
    } else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            const Icon(
              Icons.power_settings_new,
              size: 64,
              color: Color(0xFF9E9E9E),
            ),
            const SizedBox(height: 16),
            const Text(
              'You are Offline',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Go online to receive orders',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B6B6B),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _toggleOnlineStatus,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC8102E),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Go Online',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildOrderCardNew(Map<String, dynamic> assignment) {
    final order = assignment['order'] as Map<String, dynamic>?;
    if (order == null) return const SizedBox.shrink();

    final status = assignment['status'] as String? ?? 'assigned';
    final orderId = order['id']?.toString() ?? '';
    final customerName = order['user'] is Map 
        ? (order['user'] as Map)['name']?.toString() ?? 'Customer'
        : 'Customer';
    final address = order['delivery_address'] ?? order['address'];
    final addressText = formatAddressForDisplay(address);
    final totalPrice = (order['total_price'] as num?)?.toDouble() ?? 0.0;

    final accentColor = switch (status) {
      'assigned' => const Color(0xFFE53935),
      'accepted' => const Color(0xFF2ECC71),
      'picked_up' => const Color(0xFFF39C12),
      'delivered' => const Color(0xFF9E9E9E),
      _ => const Color(0xFFC8102E),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '#$orderId',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B6B6B),
                ),
              ),
              const Spacer(),
              _buildStatusBadgeSimple(status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            customerName,
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
              color: Color(0xFF6B6B6B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '₹${totalPrice.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFC8102E),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  _pushOnTab(
                    0,
                    RiderOrderDetailScreen(
                      assignmentId: assignment['id'] as String,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC8102E),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  minimumSize: const Size(0, 36),
                ),
                child: const Text(
                  'View Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadgeSimple(String status) {
    Color color;
    String label;

    switch (status) {
      case 'assigned':
        color = Colors.blue;
        label = 'New';
        break;
      case 'accepted':
        color = const Color(0xFF2ECC71);
        label = 'Accepted';
        break;
      case 'picked_up':
        color = const Color(0xFFF39C12);
        label = 'Picked Up';
        break;
      case 'delivered':
        color = const Color(0xFF2ECC71);
        label = 'Delivered';
        break;
      default:
        color = const Color(0xFF6B6B6B);
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
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
      default:
        return status;
    }
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(2);
  }
}

/// Swipe To Toggle Widget - Swipe left/right to change online/offline status
class _SwipeToToggle extends StatefulWidget {
  final bool isOnline;
  final VoidCallback onToggle;

  const _SwipeToToggle({
    required this.isOnline,
    required this.onToggle,
  });

  @override
  State<_SwipeToToggle> createState() => _SwipeToToggleState();
}

class _SwipeToToggleState extends State<_SwipeToToggle>
    with SingleTickerProviderStateMixin {
  static const double _thumbSize = 52;
  static const double _trackPadding = 2;
  static const double _minDragPx = 80;
  static const double _commitThreshold = 0.72;

  late AnimationController _controller;
  double _dragPosition = 0.0;
  double _totalDragPx = 0.0;
  double _trackWidth = 0.0;
  bool _isDragging = false;

  double get _maxSlide =>
      (_trackWidth - (_trackPadding * 2) - _thumbSize).clamp(0.0, double.infinity);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _dragPosition = widget.isOnline ? 1.0 : 0.0;
    _controller.value = _dragPosition;
  }

  @override
  void didUpdateWidget(_SwipeToToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOnline != oldWidget.isOnline && !_isDragging) {
      _snapTo(widget.isOnline, animate: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _snapTo(bool online, {required bool animate}) {
    final target = online ? 1.0 : 0.0;
    _dragPosition = target;
    if (animate) {
      _controller.animateTo(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _controller.value = target;
    }
  }

  void _onDragStart(DragStartDetails details) {
    _totalDragPx = 0;
    _dragPosition = _controller.value;
    setState(() => _isDragging = true);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_maxSlide <= 0) return;
    final delta = details.primaryDelta ?? 0;
    _totalDragPx += delta.abs();
    _dragPosition = (_dragPosition + delta / _maxSlide).clamp(0.0, 1.0);
    _controller.value = _dragPosition;
  }

  void _onDragEnd(DragEndDetails details) {
    setState(() => _isDragging = false);

    // Tap or tiny nudge — snap back, never toggle
    if (_totalDragPx < _minDragPx) {
      _snapTo(widget.isOnline, animate: true);
      return;
    }

    final velocity = details.primaryVelocity ?? 0;
    bool commit = false;

    if (!widget.isOnline) {
      commit = _dragPosition >= _commitThreshold || velocity > 600;
    } else {
      commit = _dragPosition <= (1.0 - _commitThreshold) || velocity < -600;
    }

    if (commit) {
      widget.onToggle();
      _snapTo(!widget.isOnline, animate: true);
    } else {
      _snapTo(widget.isOnline, animate: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _trackWidth = constraints.maxWidth;
        final maxSlide = _maxSlide;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final progress = _controller.value;
              final backgroundColor = Color.lerp(
                const Color(0xFFEEEEEE),
                const Color(0xFF2ECC71),
                progress,
              )!;

              return Container(
                height: 56,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 60),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Offline',
                                  style: TextStyle(
                                    color: progress < 0.5
                                        ? const Color(0xFF9E9E9E)
                                        : Colors.white.withOpacity(0.3),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 60),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'Online',
                                  style: TextStyle(
                                    color: progress > 0.5
                                        ? Colors.white
                                        : Colors.black.withOpacity(0.1),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: _trackPadding + (progress * maxSlide),
                      top: _trackPadding,
                      child: Container(
                        width: _thumbSize,
                        height: _thumbSize,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(_thumbSize / 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          progress > 0.5
                              ? Icons.keyboard_double_arrow_left
                              : Icons.keyboard_double_arrow_right,
                          color: progress > 0.5
                              ? const Color(0xFF2ECC71)
                              : const Color(0xFF9E9E9E),
                          size: 28,
                        ),
                      ),
                    ),
                    if (!_isDragging && progress < 0.1)
                      Positioned(
                        right: 20,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Icon(
                            Icons.keyboard_double_arrow_right,
                            color: Colors.black.withOpacity(0.15),
                            size: 24,
                          ),
                        ),
                      ),
                    if (!_isDragging && progress > 0.9)
                      Positioned(
                        left: 20,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Icon(
                            Icons.keyboard_double_arrow_left,
                            color: Colors.white.withOpacity(0.4),
                            size: 24,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// New Order Alert Bottom Sheet Widget
class NewOrderAlertSheet extends StatelessWidget {
  static const int _defaultTimeoutSeconds = 10;

  final Map<dynamic, dynamic> orderData;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback? onTimeout;

  const NewOrderAlertSheet({
    super.key,
    required this.orderData,
    required this.onAccept,
    required this.onReject,
    this.onTimeout,
  });

  @override
  Widget build(BuildContext context) {
    final orderIds = _extractOrderIds(orderData);
    final isBatch = orderData['isBatch'] == true;
    final batchCount =
        (orderData['batchCount'] as num?)?.toInt() ?? orderIds.length;
    final orderId = orderData['orderId']?.toString() ??
        orderData['order_id']?.toString() ??
        (orderIds.isNotEmpty ? orderIds.first : 'N/A');
    final amount = orderData['totalAmount']?.toString() ??
        orderData['amount']?.toString() ??
        orderData['total_amount']?.toString() ??
        orderData['total_price']?.toString() ??
        '0';
    final customerAddress = formatAddressForDisplay(
      orderData['customerAddress'] ??
          orderData['delivery_address'] ??
          orderData['address'],
    );
    final rawDistance = orderData['distance'];
    final distance = (rawDistance != null &&
            double.tryParse(rawDistance.toString()) != null)
        ? '${double.parse(rawDistance.toString()).toStringAsFixed(1)} km'
        : '—';
    final timeoutMs = (orderData['timeout'] as num?)?.toInt() ??
        (((orderData['expiresIn'] as num?)?.toInt() ?? _defaultTimeoutSeconds) *
            1000);
    final timeoutSeconds = (timeoutMs / 1000).ceil().clamp(1, 120);
    final batchTotal = _sumBatchAmount(orderData, amount);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isBatch ? 'Batch Delivery Request' : 'New Order Request',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 1.0, end: 0.0),
                duration: Duration(seconds: timeoutSeconds),
                onEnd: () {
                  if (context.mounted) {
                    Navigator.pop(context);
                    onTimeout?.call();
                  }
                },
                builder: (ctx, value, _) => SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: value,
                        strokeWidth: 3,
                        color: const Color(0xFFC8102E),
                        backgroundColor: const Color(0xFFEEEEEE),
                      ),
                      Text(
                        '${(value * timeoutSeconds).ceil()}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (isBatch) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_shipping,
                    color: Color(0xFFE65100),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$batchCount Orders — Batch Delivery',
                    style: const TextStyle(
                      color: Color(0xFFE65100),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(orderIds.length, (index) {
              final id = orderIds[index];
              final address = _addressForOrderId(orderData, id, customerAddress);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFFC8102E),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Order #${formatOrderDisplayId(id)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 120,
                      child: Text(
                        address,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B6B6B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            Text(
              'Complete all $batchCount deliveries in one trip',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B6B6B),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  'Total earnings',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B6B6B),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '₹$batchTotal',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC8102E),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Order #${formatOrderDisplayId(orderId)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B6B6B),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    const Icon(
                      Icons.radio_button_checked,
                      color: Color(0xFFC8102E),
                      size: 18,
                    ),
                    Container(
                      width: 2,
                      height: 40,
                      color: const Color(0xFFEEEEEE),
                    ),
                    const Icon(
                      Icons.location_on,
                      color: Color(0xFF2ECC71),
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pickup',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B6B6B),
                        ),
                      ),
                      Text(
                        StoreConfig.storeName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Deliver to',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B6B6B),
                        ),
                      ),
                      Text(
                        customerAddress,
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Distance',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B6B6B),
                      ),
                    ),
                    Text(
                      distance,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Order Value',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B6B6B),
                      ),
                    ),
                    Text(
                      '₹$amount',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC8102E),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onReject();
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEEEEEE)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Decline',
                    style: TextStyle(
                      color: Color(0xFF6B6B6B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onAccept();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ECC71),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isBatch ? 'Accept $batchCount Orders' : 'Accept Trip',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _addressForOrderId(
    Map<dynamic, dynamic> orderData,
    String orderId,
    String fallbackAddress,
  ) {
    final batchOrders = orderData['batchOrders'];
    if (batchOrders is List) {
      for (final entry in batchOrders) {
        if (entry is! Map) continue;
        final entryId = entry['orderId']?.toString() ?? entry['order_id']?.toString();
        if (entryId == orderId) {
          return formatAddressForDisplay(entry['address']);
        }
      }
    }

    final primaryId = orderData['orderId']?.toString() ??
        orderData['order_id']?.toString();
    if (primaryId == orderId && fallbackAddress.isNotEmpty) {
      return fallbackAddress;
    }
    return fallbackAddress;
  }

  static List<String> _extractOrderIds(Map<dynamic, dynamic> orderData) {
    final rawList = orderData['orderIds'] ?? orderData['order_ids'];
    if (rawList is List && rawList.isNotEmpty) {
      return rawList.map((value) => value.toString()).toList();
    }
    final single = orderData['orderId'] ?? orderData['order_id'] ?? orderData['id'];
    return single == null ? <String>[] : [single.toString()];
  }

  static String _sumBatchAmount(Map<dynamic, dynamic> orderData, String fallback) {
    final batchOrders = orderData['batchOrders'];
    if (batchOrders is! List || batchOrders.isEmpty) {
      return fallback;
    }

    double total = 0;
    var hasAmount = false;
    for (final entry in batchOrders) {
      if (entry is! Map) continue;
      final raw = entry['totalAmount'] ?? entry['total_amount'] ?? entry['amount'];
      final value = double.tryParse(raw?.toString() ?? '');
      if (value != null) {
        total += value;
        hasAmount = true;
      }
    }
    return hasAmount ? total.toStringAsFixed(total % 1 == 0 ? 0 : 2) : fallback;
  }
}
