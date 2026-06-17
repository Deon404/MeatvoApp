import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../services/admin_service.dart';
import '../../widgets/admin/admin_navigation_drawer.dart';

class AdminCouponsScreen extends StatefulWidget {
  const AdminCouponsScreen({super.key});

  @override
  State<AdminCouponsScreen> createState() => _AdminCouponsScreenState();
}

class _AdminCouponsScreenState extends State<AdminCouponsScreen> {
  final _admin = AdminService();
  List<Map<String, dynamic>> _coupons = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _coupons = await _admin.getCoupons();
    } catch (e) {
      _toast(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.primary : AppColors.success,
      ),
    );
  }

  Future<void> _showCreateDialog() async {
    final codeCtrl = TextEditingController();
    final valueCtrl = TextEditingController(text: '10');
    var type = 'PERCENT';

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create coupon'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(labelText: 'Code'),
              textCapitalization: TextCapitalization.characters,
            ),
            DropdownButtonFormField<String>(
              value: type,
              items: const [
                DropdownMenuItem(value: 'PERCENT', child: Text('Percent')),
                DropdownMenuItem(value: 'FLAT', child: Text('Flat ₹')),
              ],
              onChanged: (v) => type = v ?? 'PERCENT',
              decoration: const InputDecoration(labelText: 'Type'),
            ),
            TextField(
              controller: valueCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Value'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (created != true) return;
    try {
      await _admin.createCoupon(
        code: codeCtrl.text.trim(),
        discountType: type,
        discountValue: double.tryParse(valueCtrl.text.trim()) ?? 0,
      );
      _toast('Coupon created');
      await _load();
    } catch (e) {
      _toast(e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AdminNavigationDrawer(
        currentSection: AdminNavSection.coupons,
        onLogout: () => AdminNavigationDrawer.confirmLogout(context),
      ),
      appBar: AppBar(
        title: const Text('Coupons'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: _showCreateDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _coupons.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('No coupons yet')),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _coupons.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final c = _coupons[i];
                        final active = c['active'] != false;
                        return ListTile(
                          tileColor: AppColors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          title: Text(c['code']?.toString() ?? ''),
                          subtitle: Text(
                            '${c['discount_type']} ${c['discount_value']} • used ${c['used_count'] ?? 0}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: active,
                                onChanged: (v) async {
                                  await _admin.updateCoupon(
                                    (c['id'] as num).toInt(),
                                    active: v,
                                  );
                                  await _load();
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  await _admin.deleteCoupon((c['id'] as num).toInt());
                                  await _load();
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
