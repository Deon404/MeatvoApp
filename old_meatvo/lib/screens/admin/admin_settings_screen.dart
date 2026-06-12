import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../core/constants/app_constants.dart';
import '../../utils/responsive_helper.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _adminService = AdminService();
  final _deliveryChargeController = TextEditingController();
  final _minOrderController = TextEditingController();
  final _radiusController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _storeOpen = true;
  TimeOfDay? _openTime;
  TimeOfDay? _closeTime;

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

  TimeOfDay? _parseTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '';
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final s = await _adminService.getStoreSettings();
      if (!mounted) return;
      setState(() {
        _deliveryChargeController.text =
            (s['delivery_charge'] ?? 30).toString();
        _minOrderController.text = (s['min_order_amount'] ?? 150).toString();
        _radiusController.text = (s['delivery_radius_km'] ?? 5).toString();
        _storeOpen = s['store_open'] != false;
        _openTime = _parseTime(s['store_open_time']?.toString());
        _closeTime = _parseTime(s['store_close_time']?.toString());
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

  Future<void> _pickTime({required bool isOpen}) async {
    final initial = isOpen ? (_openTime ?? const TimeOfDay(hour: 9, minute: 0)) : (_closeTime ?? const TimeOfDay(hour: 21, minute: 0));
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      if (isOpen) {
        _openTime = picked;
      } else {
        _closeTime = picked;
      }
    });
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
        storeOpen: _storeOpen,
        storeOpenTime: _formatTime(_openTime),
        storeCloseTime: _formatTime(_closeTime),
        deliveryRadiusKm: radius,
      );
      _toast('Settings saved');
      await _load();
    } catch (e) {
      _toast(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
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
                  TextField(
                    controller: _deliveryChargeController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Delivery charge (₹)',
                      prefixText: '₹ ',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _minOrderController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Minimum order amount (₹)',
                      prefixText: '₹ ',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _radiusController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Delivery radius (km)',
                      suffixText: 'km',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Store open'),
                    subtitle: Text(_storeOpen ? 'Customers can order' : 'Store closed'),
                    value: _storeOpen,
                    onChanged: (v) => setState(() => _storeOpen = v),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Opening time'),
                    subtitle: Text(_formatTime(_openTime).isEmpty ? 'Not set' : _formatTime(_openTime)),
                    trailing: const Icon(Icons.schedule),
                    onTap: () => _pickTime(isOpen: true),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Closing time'),
                    subtitle: Text(_formatTime(_closeTime).isEmpty ? 'Not set' : _formatTime(_closeTime)),
                    trailing: const Icon(Icons.schedule),
                    onTap: () => _pickTime(isOpen: false),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
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
                        : const Text('Save settings'),
                  ),
                ],
              ),
            ),
    );
  }
}
