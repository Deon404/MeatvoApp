import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../services/store_status_service.dart';
import '../../core/constants/app_constants.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/admin/admin_navigation_drawer.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _adminService = AdminService();
  final _storeStatusService = StoreStatusService();
  final _deliveryChargeController = TextEditingController();
  final _minOrderController = TextEditingController();
  final _radiusController = TextEditingController();
  TimeOfDay _openTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _closeTime = const TimeOfDay(hour: 21, minute: 0);

  bool _isLoading = true;
  bool _isSaving = false;
  bool _manualStoreOpen = true;
  bool _effectiveStoreOpen = true;
  bool _isTogglingStore = false;

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
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _adminService.getStoreSettings(),
        _storeStatusService.fetchStatus(),
      ]);
      final s = results[0] as Map<String, dynamic>;
      final status = results[1] as StoreStatus;
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
        _manualStoreOpen = s['store_open'] == true;
        _effectiveStoreOpen = status.isOpen;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _toast(e.toString(), isError: true);
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

  Future<void> _toggleStoreOpen(bool value) async {
    if (_isTogglingStore || value == _manualStoreOpen) return;
    setState(() => _isTogglingStore = true);
    try {
      final status = await _storeStatusService.toggleStoreOpen();
      if (!mounted) return;
      setState(() {
        _manualStoreOpen = status.manualOpen;
        _effectiveStoreOpen = status.isOpen;
      });
      _toast(
        status.manualOpen
            ? 'Store switch is ON — orders allowed during open hours'
            : 'Store switch is OFF — orders paused until you reopen',
      );
    } catch (e) {
      _toast(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isTogglingStore = false);
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
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _effectiveStoreOpen
                          ? AppColors.success.withValues(alpha: 0.08)
                          : AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _effectiveStoreOpen
                            ? AppColors.success.withValues(alpha: 0.25)
                            : AppColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _effectiveStoreOpen
                              ? Icons.storefront_outlined
                              : Icons.store_mall_directory_outlined,
                          color: _effectiveStoreOpen
                              ? AppColors.success
                              : AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _effectiveStoreOpen
                                    ? 'Accepting orders now'
                                    : 'Orders blocked right now',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _effectiveStoreOpen
                                    ? 'Customers can place COD and online orders during store hours.'
                                    : (_manualStoreOpen
                                        ? 'Outside store hours — checkout resumes when open.'
                                        : 'Manual switch is OFF — checkout blocked until you reopen.'),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: _manualStoreOpen,
                          onChanged: _isTogglingStore ? null : _toggleStoreOpen,
                          activeThumbColor: AppColors.success,
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
