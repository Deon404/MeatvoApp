import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../models/admin_ops_metrics.dart';
import '../../services/admin_service.dart';
import '../../widgets/admin/admin_navigation_drawer.dart';
import '../../widgets/admin/ops_metrics_dashboard.dart';
import '../../widgets/common/error_state.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  final _admin = AdminService();
  AdminOpsMetrics? _opsMetrics;
  Map<String, dynamic>? _commerceKpi;
  String _period = '7d';
  bool _loading = true;
  String? _error;

  static const _periodOptions = <String, String>{
    'today': 'Today',
    '7d': '7D',
    '30d': '30D',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _analyticsPeriodParam() {
    switch (_period) {
      case 'today':
        return 'today';
      case '30d':
        return 'month';
      default:
        return 'week';
    }
  }

  String _granularity() => _period == 'today' ? 'hour' : 'day';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _admin.getOpsMetrics(period: _period, granularity: _granularity()),
        _admin.getAnalytics(period: _analyticsPeriodParam()),
      ]);

      if (!mounted) return;
      setState(() {
        _opsMetrics = results[0] as AdminOpsMetrics;
        final analytics = results[1] as Map<String, dynamic>;
        _commerceKpi = (analytics['kpi'] as Map?)?.cast<String, dynamic>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: AdminNavigationDrawer(
        currentSection: AdminNavSection.analytics,
        onLogout: () => AdminNavigationDrawer.confirmLogout(context),
      ),
      appBar: AppBar(
        title: const Text('Operations Analytics'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        actions: [
          PopupMenuButton<String>(
            initialValue: _period,
            onSelected: (value) {
              setState(() => _period = value);
              _load();
            },
            itemBuilder: (_) => _periodOptions.entries
                .map(
                  (e) => PopupMenuItem<String>(
                    value: e.key,
                    child: Text(e.value),
                  ),
                )
                .toList(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  Text(
                    _periodOptions[_period] ?? _period,
                    style: AppTextStyles.body,
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _opsMetrics == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_error != null && _opsMetrics == null) {
      return ErrorStateWidget(
        title: 'Could not load analytics',
        message: _error!,
        onRetry: _load,
      );
    }

    if (_opsMetrics == null) {
      return ErrorStateWidget(
        title: 'No data',
        message: 'Operational metrics are not available yet.',
        onRetry: _load,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.primary,
                backgroundColor: AppColors.divider,
              ),
            ),
          OpsMetricsDashboard(
            opsMetrics: _opsMetrics!,
            commerceKpi: _commerceKpi,
          ),
        ],
      ),
    );
  }
}
