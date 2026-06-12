import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../models/earnings_data.dart';
import '../../services/push_notification_service.dart';
import '../../services/rider_service.dart';
import '../../services/socket_service.dart';
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
import 'rider_order_detail_screen.dart';
import 'delivery_map_screen.dart';

/// Rider Dashboard Screen - Main screen for riders
class RiderDashboardScreen extends StatefulWidget {
  const RiderDashboardScreen({super.key});

  @override
  State<RiderDashboardScreen> createState() => _RiderDashboardScreenState();
}

class _RiderDashboardScreenState extends State<RiderDashboardScreen> {
  final RiderService _riderService = RiderService();
  final SocketService _socketService = SocketService();
  final MapsService _mapsService = MapsService();
  final PushNotificationService _pushNotifications = PushNotificationService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  Map<String, dynamic>? _riderProfile;
  EarningsData? _earnings;
  List<Map<String, dynamic>> _activeOrders = [];
  bool _isLoading = true;
  bool _isLoadingEarnings = true;
  String? _earningsError;
  int _currentIndex = 0;
  Future<void> Function()? _refreshOrdersTab;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeDashboard());
  }

  Future<void> _initializeDashboard() async {
    final allowed = await ensureDeliveryPartnerAccess(context);
    if (!allowed || !mounted) return;

    await _loadDashboardData();
    await _subscribeToOrderAssignments();
    await _subscribeToAssignmentSocketEvents();
  }

  @override
  void dispose() {
    _socketService.offOrderAssigned();
    _socketService.offRouteZoneAssigned();
    _socketService.offOrderAssignmentCancelled();
    _riderService.unsubscribeFromOrderAssignments();
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RiderOrderDetailScreen(
                        assignmentId: orderId,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _handleZoneAssigned(dynamic data) {
    final zoneId = data is Map ? data['zoneId']?.toString() : null;
    final orderCount = data is Map ? data['orderCount'] : null;
    _loadDashboardData();
    _refreshOrdersTab?.call();
    final countLabel = orderCount != null ? '$orderCount orders' : 'new orders';
    _showAssignmentSnackBar(
      message: zoneId == null
          ? 'New delivery zone assigned ($countLabel)'
          : 'Zone $zoneId assigned ($countLabel)',
    );
  }

  void _handleAssignmentAssigned(dynamic data) {
    final orderId = _parseOrderId(data);
    _loadDashboardData();
    _refreshOrdersTab?.call();
    
    if (orderId != null) {
      _pushNotifications.showOrderAssignment(
        orderId: orderId,
        body: 'Tap to view order #$orderId',
      );
      
      // Show prominent alert bottom sheet with sound
      _showNewOrderAlert(data is Map ? data : {'orderId': orderId});
    } else {
      _showAssignmentSnackBar(
        message: 'New order assigned!',
        orderId: orderId?.toString(),
      );
    }
  }

  void _showNewOrderAlert(Map<dynamic, dynamic> orderData) {
    if (!mounted) return;
    
    // Play notification sound
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
        onAccept: () => _acceptOrder(orderData['orderId']),
        onReject: () => _rejectOrder(orderData['orderId'], 'Declined from alert'),
        onTimeout: () => _rejectOrder(orderData['orderId'], 'timeout'),
      ),
    );
  }

  Future<void> _acceptOrder(dynamic orderId) async {
    if (!mounted) return;
    
    final parsedOrderId = _parseOrderId(orderId);
    if (parsedOrderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid order ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await _riderService.acceptOrder(parsedOrderId.toString());
      await _loadDashboardData();
      _refreshOrdersTab?.call();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order #$parsedOrderId accepted!'),
            backgroundColor: AppColors.success,
          ),
        );
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

  Future<void> _rejectOrder(dynamic orderId, [String reason = '']) async {
    if (!mounted) return;
    
    final parsedOrderId = _parseOrderId(orderId);
    if (parsedOrderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid order ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await _riderService.rejectOrder(parsedOrderId.toString(), reason);
      await _loadDashboardData();
      _refreshOrdersTab?.call();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order #$parsedOrderId rejected'),
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

  void _handleAssignmentCancelled(dynamic data) {
    final orderId = _parseOrderId(data);
    if (mounted && orderId != null) {
      setState(() {
        _activeOrders.removeWhere((assignment) {
          final order = assignment['order'] as Map<String, dynamic>?;
          final id = order?['id']?.toString();
          return id == orderId.toString();
        });
      });
    }
    _loadDashboardData();
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
          final orderId = assignment['id']?.toString();
          _loadDashboardData();
          if (orderId != null) {
            final parsed = int.tryParse(orderId);
            if (parsed != null) {
              _pushNotifications.showOrderAssignment(orderId: parsed);
            }
          }
          _showAssignmentSnackBar(
            message: 'New order assigned!',
            orderId: orderId,
          );
        },
        onAssignmentUpdated: () {
          if (context.mounted) {
            _loadDashboardData();
          }
        },
      );
    } catch (e) {
      debugPrint('Error subscribing to order assignments: $e');
    }
  }

  DateTime? _lastLoadTime;
  
  Future<void> _loadDashboardData() async {
    // Debounce: Don't load if last load was less than 3 seconds ago
    final now = DateTime.now();
    if (_lastLoadTime != null && now.difference(_lastLoadTime!) < const Duration(seconds: 3)) {
      debugPrint('[Dashboard] Skipping load - too soon after last load');
      return;
    }
    _lastLoadTime = now;
    
    setState(() {
      _isLoading = true;
      _isLoadingEarnings = true;
      _earningsError = null;
    });
    try {
      final profile = await _riderService.getRiderProfile();
      final orders = await _riderService.getRiderOrders();

      if (mounted) {
        setState(() {
          _riderProfile = profile;
          _activeOrders = orders
              .where((assignment) {
                final status =
                    (assignment['status'] as String? ?? '').toLowerCase();
                return status != 'delivered' && status != 'cancelled';
              })
              .toList();
          _isLoading = false;
        });
      }

      await _loadEarnings(
        lifetimeTotal: (profile['earnings'] as num?)?.toDouble(),
      );
    } on RoleAccessException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        await handleRoleAccessDenied(e);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (e.toString().contains('429') || e.toString().contains('Too many requests')) {
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

  Future<void> _loadEarnings({double? lifetimeTotal}) async {
    if (mounted) {
      setState(() {
        _isLoadingEarnings = true;
        _earningsError = null;
      });
    }
    try {
      final earnings = await _riderService.getRiderEarnings(
        lifetimeTotal: lifetimeTotal ??
            (_riderProfile?['earnings'] as num?)?.toDouble(),
      );
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

  @override
  Widget build(BuildContext context) {
    R.init(context);

    if (_currentIndex == 1) {
      return RiderOrdersScreen(
        onBack: () => setState(() => _currentIndex = 0),
        onRegisterRefresh: (refresh) {
          _refreshOrdersTab = refresh;
        },
      );
    } else if (_currentIndex == 2) {
      return RiderProfileScreen(
        onBack: () => setState(() => _currentIndex = 0),
      );
    }

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
                            if (_activeOrders.isEmpty)
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
                            const SizedBox(height: 90),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _buildSwipeToggleBottom(isOnline),
                ],
              ),
      ),
      bottomNavigationBar: SafeArea(
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
          },
          selectedItemColor: const Color(0xFFC8102E),
          unselectedItemColor: const Color(0xFF6B6B6B),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long),
              label: 'Orders',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiderInfoCardSimple() {
    final riderName = _riderProfile?['name']?.toString() ?? 'Rider';
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
              _earningsPill('Deliveries', '$deliveries'),
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RiderOrderDetailScreen(
                        assignmentId: assignment['id'] as String,
                      ),
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
    final orderId = orderData['orderId']?.toString() ?? 
                    orderData['order_id']?.toString() ?? 
                    'N/A';
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
    final distance = orderData['distance']?.toString() ?? '2.5';

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
              const Text(
                'New Order Request',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 1.0, end: 0.0),
                duration: const Duration(seconds: 30),
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
                        '${(value * 30).ceil()}',
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
                    const Text(
                      'Meatvo Store',
                      style: TextStyle(
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
                    '$distance km',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Earnings',
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
                  child: const Text(
                    'Accept Trip',
                    style: TextStyle(
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
}
