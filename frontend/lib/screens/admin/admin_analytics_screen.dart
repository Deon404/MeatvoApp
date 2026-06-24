import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../services/admin_service.dart';
import '../../widgets/admin/admin_navigation_drawer.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  final _admin = AdminService();
  Map<String, dynamic>? _data;
  String _period = 'today';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _data = await _admin.getAnalytics(period: _period);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.primary),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kpis = (_data?['kpi'] as Map?)?.cast<String, dynamic>() ?? {};
    final revenue = (_data?['kpi'] as Map?)?.cast<String, dynamic>() ?? {};

    return Scaffold(
      drawer: AdminNavigationDrawer(
        currentSection: AdminNavSection.analytics,
        onLogout: () => AdminNavigationDrawer.confirmLogout(context),
      ),
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        actions: [
          PopupMenuButton<String>(
            initialValue: _period,
            onSelected: (v) {
              setState(() => _period = v);
              _load();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'today', child: Text('Today')),
              PopupMenuItem(value: 'week', child: Text('Week')),
              PopupMenuItem(value: 'month', child: Text('Month')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _MetricCard(
                    title: 'Orders',
                    value: '${kpis['totalOrders'] ?? 0}',
                  ),
                  _MetricCard(
                    title: 'Revenue',
                    value: '₹${(kpis['totalRevenue'] ?? 0).toString()}',
                  ),
                  _MetricCard(
                    title: 'Delivered',
                    value: '${kpis['deliveredOrders'] ?? 0}',
                  ),
                  _MetricCard(
                    title: 'Avg order value',
                    value: '₹${(kpis['avgOrderValue'] ?? 0).toString()}',
                  ),
                ],
              ),
            ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(color: AppColors.textSecondary)),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
