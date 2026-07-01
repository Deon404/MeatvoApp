import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/backend_resolver.dart';
import '../../services/admin_service.dart';
import '../../services/store_status_service.dart';
import '../../core/constants/app_constants.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/admin/admin_navigation_drawer.dart';
import '../../widgets/admin/capacity_suggestion_card.dart';
import '../../widgets/common/error_state.dart';

class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  AdminService get _adminService => ref.read(adminServiceProvider);
  final _storeStatusService = StoreStatusService();
  final _deliveryChargeController = TextEditingController();
  final _minOrderController = TextEditingController();
  final _radiusController = TextEditingController();
  TimeOfDay _openTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _closeTime = const TimeOfDay(hour: 21, minute: 0);

  bool _isLoading = true;
  String? _loadError;
  bool _isSaving = false;
  StoreAcceptanceMode _acceptanceMode = StoreAcceptanceMode.accepting;
  StoreAcceptanceMode _effectiveAcceptanceMode = StoreAcceptanceMode.accepting;
  bool _isUpdatingAcceptanceMode = false;
  CapacitySuggestion? _capacitySuggestion;
  bool _isApplyingSuggestion = false;
  bool _isDismissingSuggestion = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _deliveryChargeController.dispose();
    _minOrderController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  TimeOfDay _parseTime(String? raw, TimeOfDay fallback) {
    if (raw == null || raw.trim().isEmpty) return fallback;
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw.trim());
    if (match == null) return fallback;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return fallback;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return fallback;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _pickStoreTime({required bool isOpenTime}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isOpenTime ? _openTime : _closeTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isOpenTime) {
        _openTime = picked;
      } else {
        _closeTime = picked;
      }
    });
  }

  Widget _timePickerField({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.access_time_outlined),
        ),
        child: Text(
          _formatTime(time),
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        _adminService.getStoreSettings(),
        _storeStatusService.fetchStatus(),
        _adminService.getCapacitySuggestion(),
      ]);
      final s = results[0] as Map<String, dynamic>;
      final status = results[1] as StoreStatus;
      final capacityResponse = results[2] as CapacitySuggestionResponse?;
      if (!mounted) return;
      setState(() {
        _deliveryChargeController.text =
            (s['delivery_charge'] ?? 30).toString();
        _minOrderController.text = (s['min_order_amount'] ?? 150).toString();
        _radiusController.text = (s['delivery_radius_km'] ?? 5).toString();
        _openTime = _parseTime(
          s['store_open_time']?.toString(),
          const TimeOfDay(hour: 9, minute: 0),
        );
        _closeTime = _parseTime(
          s['store_close_time']?.toString(),
          const TimeOfDay(hour: 21, minute: 0),
        );
        _acceptanceMode = StoreAcceptanceModeX.fromApi(
          s['store_acceptance_mode']?.toString(),
          isOpen: status.isOpen,
        );
        _effectiveAcceptanceMode = status.acceptanceMode;
        _capacitySuggestion = capacityResponse?.active == true
            ? capacityResponse?.suggestion
            : null;
        _isLoading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = BackendResolver.toUserMessage(
          e,
          fallback: 'Could not load store settings.',
        );
      });
    }
  }

  void _toast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.primary : AppColors.success,
      ),
    );
  }

  Future<void> _save() async {
    final delivery = double.tryParse(_deliveryChargeController.text.trim());
    final minOrder = double.tryParse(_minOrderController.text.trim());
    final radius = double.tryParse(_radiusController.text.trim());
    if (delivery == null || minOrder == null || radius == null) {
      _toast('Enter valid numbers', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _adminService.updateStoreSettings(
        deliveryCharge: delivery,
        minOrderAmount: minOrder,
        deliveryRadiusKm: radius,
        storeOpenTime: _formatTime(_openTime),
        storeCloseTime: _formatTime(_closeTime),
      );
      _toast('Settings saved');
      await _load();
    } catch (e) {
      _toast(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _setAcceptanceMode(StoreAcceptanceMode mode) async {
    if (_isUpdatingAcceptanceMode || mode == _acceptanceMode) return;
    setState(() => _isUpdatingAcceptanceMode = true);
    try {
      final status = await _storeStatusService.setAcceptanceMode(mode);
      if (!mounted) return;
      setState(() {
        _acceptanceMode = status.acceptanceMode;
        _effectiveAcceptanceMode = status.acceptanceMode;
      });
      _toast('Store is now ${status.acceptanceMode.customerLabel}');
    } catch (e) {
      _toast(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isUpdatingAcceptanceMode = false);
    }
  }

  Future<void> _applyCapacitySuggestion() async {
    final suggestion = _capacitySuggestion;
    if (suggestion == null || _isApplyingSuggestion) return;
    setState(() => _isApplyingSuggestion = true);
    try {
      await _setAcceptanceMode(suggestion.suggestedAcceptanceMode);
      if (!mounted) return;
      setState(() => _capacitySuggestion = null);
      await _load();
    } finally {
      if (mounted) setState(() => _isApplyingSuggestion = false);
    }
  }

  Future<void> _dismissCapacitySuggestion() async {
    if (_isDismissingSuggestion) return;
    setState(() => _isDismissingSuggestion = true);
    try {
      await _adminService.dismissCapacitySuggestion(minutes: 30);
      if (!mounted) return;
      setState(() => _capacitySuggestion = null);
      _toast('Recommendation dismissed for 30 minutes');
    } catch (e) {
      _toast(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isDismissingSuggestion = false);
    }
  }

  String _acceptanceModeDescription(StoreAcceptanceMode mode) {
    switch (mode) {
      case StoreAcceptanceMode.accepting:
        return 'Customers can place COD and online orders during store hours.';
      case StoreAcceptanceMode.limitedCapacity:
        return 'Orders still accepted, but customers see longer delivery expectations.';
      case StoreAcceptanceMode.notAccepting:
        return 'Checkout is blocked until you switch back to accepting orders.';
    }
  }

  Color _acceptanceModeColor(StoreAcceptanceMode mode) {
    switch (mode) {
      case StoreAcceptanceMode.accepting:
        return AppColors.success;
      case StoreAcceptanceMode.limitedCapacity:
        return AppColors.warning;
      case StoreAcceptanceMode.notAccepting:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      drawer: AdminNavigationDrawer(
        currentSection: AdminNavSection.settings,
        onLogout: () => AdminNavigationDrawer.confirmLogout(context),
      ),
      appBar: AppBar(
        title: const Text('Store Settings'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? ErrorStateWidget(
                  title: 'Settings unavailable',
                  message: _loadError,
                  onRetry: _load,
                )
              : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + keyboardInset(context),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_capacitySuggestion != null) ...[
                    CapacitySuggestionCard(
                      suggestion: _capacitySuggestion!,
                      onApply: _applyCapacitySuggestion,
                      onDismiss: _dismissCapacitySuggestion,
                      isApplying: _isApplyingSuggestion,
                      isDismissing: _isDismissingSuggestion,
                    ),
                    const SizedBox(height: 16),
                  ],
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _acceptanceModeColor(_effectiveAcceptanceMode)
                          .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _acceptanceModeColor(_effectiveAcceptanceMode)
                            .withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.storefront_outlined,
                              color: _acceptanceModeColor(_effectiveAcceptanceMode),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _effectiveAcceptanceMode.customerLabel,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _acceptanceModeDescription(_effectiveAcceptanceMode),
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SegmentedButton<StoreAcceptanceMode>(
                          segments: const [
                            ButtonSegment(
                              value: StoreAcceptanceMode.accepting,
                              label: Text('Accepting'),
                            ),
                            ButtonSegment(
                              value: StoreAcceptanceMode.limitedCapacity,
                              label: Text('Limited'),
                            ),
                            ButtonSegment(
                              value: StoreAcceptanceMode.notAccepting,
                              label: Text('Paused'),
                            ),
                          ],
                          selected: {_acceptanceMode},
                          onSelectionChanged: _isUpdatingAcceptanceMode
                              ? null
                              : (selection) {
                                  if (selection.isEmpty) return;
                                  _setAcceptanceMode(selection.first);
                                },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _deliveryChargeController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Delivery charge (₹)',
                      prefixText: '₹ ',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _minOrderController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Minimum order amount (₹)',
                      prefixText: '₹ ',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _radiusController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Delivery radius (km)',
                      suffixText: 'km',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _timePickerField(
                    label: 'Store open time',
                    time: _openTime,
                    onTap: () => _pickStoreTime(isOpenTime: true),
                  ),
                  const SizedBox(height: 16),
                  _timePickerField(
                    label: 'Store close time',
                    time: _closeTime,
                    onTap: () => _pickStoreTime(isOpenTime: false),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save settings',
                            style: TextStyle(color: AppColors.white),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
