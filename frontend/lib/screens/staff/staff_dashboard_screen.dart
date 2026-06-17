import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/auth_service.dart';
import '../../services/socket_service.dart';
import '../../utils/role_access.dart';
import '../../widgets/admin/new_order_alert_banner.dart';
import '../auth/phone_screen.dart';
import 'staff_orders_screen.dart';
import 'staff_theme.dart';
import 'widgets/staff_bottom_nav.dart';

class StaffDashboardScreen extends ConsumerStatefulWidget {
  const StaffDashboardScreen({super.key});

  @override
  ConsumerState<StaffDashboardScreen> createState() =>
      _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends ConsumerState<StaffDashboardScreen> {
  final SocketService _socketService = SocketService();
  AdminNewOrderAlertController? _alertController;
  StaffOrdersScreenController? _kitchenController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeDashboard());
  }

  @override
  void dispose() {
    _socketService.offNewOrder();
    _socketService.offAdminOrderUpdate();
    _alertController?.dispose();
    super.dispose();
  }

  Future<void> _initializeDashboard() async {
    final allowed = await ensureStaffAccess(context);
    if (!allowed || !mounted) return;

    await _socketService.connect();
    _setupKitchenAlerts();
    _setupSocketListeners();
  }

  void _setupKitchenAlerts() {
    if (!mounted) return;
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    _alertController = AdminNewOrderAlertController(
      overlayState: overlay,
      onTap: (_) {
        setState(() => _currentIndex = 0);
        _kitchenController?.goToNewTab();
        _kitchenController?.reloadOrders(showLoading: false);
      },
    );
  }

  void _setupSocketListeners() {
    _socketService.onNewOrder((data) {
      if (!mounted) return;

      final alert = NewOrderAlertData.fromSocket(data);
      if (alert.orderId > 0) {
        _alertController?.enqueue(alert);
      }

      _kitchenController?.reloadOrders(showLoading: false);
    });

    _socketService.onAdminOrderUpdate((_) {
      if (!mounted) return;
      _kitchenController?.reloadOrders(showLoading: false);
    });
  }

  void _registerKitchenController(StaffOrdersScreenController controller) {
    _kitchenController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StaffColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          StaffOrdersScreen(
            onRegisterCallbacks: _registerKitchenController,
          ),
          const StaffProfileScreen(),
        ],
      ),
      bottomNavigationBar: StaffBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

class StaffProfileScreen extends StatefulWidget {
  const StaffProfileScreen({super.key});

  @override
  State<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends State<StaffProfileScreen> {
  final AuthService _authService = AuthService();
  String? _name;
  String? _phone;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.getMe();
      if (!mounted) return;
      setState(() {
        _name = user?.name;
        _phone = user?.phoneNumber;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    SocketService().disconnect();
    await _authService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const PhoneScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StaffColors.background,
      appBar: staffAppBar(title: 'Butcher Profile'),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: StaffColors.accent),
            )
          : Padding(
              padding: const EdgeInsets.all(StaffSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(StaffSpacing.lg),
                    decoration: BoxDecoration(
                      color: StaffColors.surface,
                      borderRadius: BorderRadius.circular(StaffRadius.card),
                      border: Border.all(color: StaffColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_name ?? 'Butcher', style: StaffTextStyles.h2),
                        if (_phone != null && _phone!.isNotEmpty) ...[
                          const SizedBox(height: StaffSpacing.xs),
                          Text(_phone!, style: StaffTextStyles.caption),
                        ],
                        const SizedBox(height: StaffSpacing.sm),
                        Text(
                          'Role: Butcher',
                          style: StaffTextStyles.caption.copyWith(
                            color: StaffColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _signOut,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: StaffColors.accent,
                        side: const BorderSide(color: StaffColors.accent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(StaffRadius.button),
                        ),
                      ),
                      child: const Text('Sign Out', style: StaffTextStyles.button),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
