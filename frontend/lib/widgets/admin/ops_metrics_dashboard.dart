import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../models/admin_ops_metrics.dart';
import 'admin_kpi_card.dart';

class OpsMetricsDashboard extends StatelessWidget {
  const OpsMetricsDashboard({
    super.key,
    required this.opsMetrics,
    this.commerceKpi,
  });

  final AdminOpsMetrics opsMetrics;
  final Map<String, dynamic>? commerceKpi;

  @override
  Widget build(BuildContext context) {
    final completeness = opsMetrics.dataCompleteness;
    final metrics = opsMetrics.metrics;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (completeness.isPartial) _PartialDataBanner(completeness: completeness),
        if (commerceKpi != null) ...[
          Text('Commerce', style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.sm),
          _CommerceKpiRow(kpi: commerceKpi!),
          const SizedBox(height: AppSpacing.lg),
        ],
        Text('Operations', style: AppTextStyles.h3),
        const SizedBox(height: AppSpacing.sm),
        _OpsKpiGrid(opsMetrics: opsMetrics),
        const SizedBox(height: AppSpacing.lg),
        if (opsMetrics.trends.isNotEmpty) ...[
          Text('7-day trends', style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.sm),
          _TrendsChart(trends: opsMetrics.trends),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (opsMetrics.cancelledByReason.isNotEmpty) ...[
          Text('Cancellations by reason', style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.sm),
          _CancelledReasonsList(reasons: opsMetrics.cancelledByReason),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (opsMetrics.peakModeHours.isNotEmpty) ...[
          Text('Peak mode hours', style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.sm),
          _PeakHoursList(hours: opsMetrics.peakModeHours),
        ],
        if (metrics.isEmpty && opsMetrics.trends.isEmpty)
          const _EmptyOpsState(),
      ],
    );
  }
}

class _PartialDataBanner extends StatelessWidget {
  const _PartialDataBanner({required this.completeness});

  final DataCompleteness completeness;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Partial data (${completeness.overallScore}% complete)',
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  completeness.message,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommerceKpiRow extends StatelessWidget {
  const _CommerceKpiRow({required this.kpi});

  final Map<String, dynamic> kpi;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AdminKpiCard(
            title: 'Orders',
            value: '${kpi['totalOrders'] ?? 0}',
            icon: Icons.receipt_long_outlined,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: AdminKpiCard(
            title: 'Revenue',
            value: '₹${kpi['totalRevenue'] ?? 0}',
            icon: Icons.currency_rupee,
            color: AppColors.success,
          ),
        ),
      ],
    );
  }
}

class _OpsKpiGrid extends StatelessWidget {
  const _OpsKpiGrid({required this.opsMetrics});

  final AdminOpsMetrics opsMetrics;

  @override
  Widget build(BuildContext context) {
    final batch = opsMetrics.metric('batchPercentage');
    final dispatch = opsMetrics.metric('averageDispatchDelay');
    final packed = opsMetrics.metric('averagePackedTime');
    final trip = opsMetrics.metric('averageRiderTripTime');
    final refund = opsMetrics.metric('refundPercentage');
    final stock = opsMetrics.metric('stockFailurePercentage');
    final soloBatch = opsMetrics.soloVsBatchRatio;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AdminKpiCard(
                title: 'Batch %',
                value: batch.format(),
                subtitle: 'n=${batch.sampleSize}',
                icon: Icons.layers_outlined,
                dataAvailable: batch.dataAvailable,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AdminKpiCard(
                title: 'Dispatch delay',
                value: dispatch.format(),
                subtitle: 'Avg minutes',
                icon: Icons.schedule_outlined,
                dataAvailable: dispatch.dataAvailable,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: AdminKpiCard(
                title: 'Pack time',
                value: packed.format(),
                icon: Icons.inventory_2_outlined,
                dataAvailable: packed.dataAvailable,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AdminKpiCard(
                title: 'Rider trip',
                value: trip.format(),
                icon: Icons.delivery_dining_outlined,
                dataAvailable: trip.dataAvailable,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: AdminKpiCard(
                title: 'Refund %',
                value: refund.format(),
                icon: Icons.replay_outlined,
                color: AppColors.warning,
                dataAvailable: refund.dataAvailable,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AdminKpiCard(
                title: 'Stock failure %',
                value: stock.format(),
                icon: Icons.error_outline,
                color: AppColors.primary,
                dataAvailable: stock.dataAvailable,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AdminKpiCard(
          title: 'Solo vs batch',
          value: soloBatch.dataAvailable
              ? '${soloBatch.solo} solo / ${soloBatch.batch} batch'
              : '—',
          subtitle: soloBatch.ratio != null
              ? 'Ratio ${soloBatch.ratio!.toStringAsFixed(2)}:1'
              : 'No dispatch data',
          icon: Icons.compare_arrows_outlined,
          dataAvailable: soloBatch.dataAvailable,
        ),
      ],
    );
  }
}

class _TrendsChart extends StatelessWidget {
  const _TrendsChart({required this.trends});

  final List<OpsTrendPoint> trends;

  @override
  Widget build(BuildContext context) {
    final visible = trends.where((t) => t.dataAvailable).toList();
    if (visible.isEmpty) {
      return const _EmptyOpsState(message: 'No trend data for this period.');
    }

    final maxOrders = visible
        .map((t) => t.orders)
        .fold<int>(0, (a, b) => a > b ? a : b)
        .clamp(1, 999999);

    return Container(
      height: 200,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxOrders.toDouble() * 1.2,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= visible.length) return const SizedBox.shrink();
                  final label = visible[idx].bucket;
                  final short = label.length >= 10 ? label.substring(5, 10) : label;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      short,
                      style: AppTextStyles.caption.copyWith(fontSize: 9),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < visible.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: visible[i].orders.toDouble(),
                    color: AppColors.primary,
                    width: 12,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _CancelledReasonsList extends StatelessWidget {
  const _CancelledReasonsList({required this.reasons});

  final List<CancelledByReason> reasons;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          for (var i = 0; i < reasons.length; i++)
            ListTile(
              dense: true,
              title: Text(reasons[i].reason, style: AppTextStyles.body),
              trailing: Text(
                '${reasons[i].count}',
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
              ),
              shape: i < reasons.length - 1
                  ? const Border(bottom: BorderSide(color: AppColors.divider))
                  : null,
            ),
        ],
      ),
    );
  }
}

class _PeakHoursList extends StatelessWidget {
  const _PeakHoursList({required this.hours});

  final List<PeakModeHour> hours;

  @override
  Widget build(BuildContext context) {
    final sorted = [...hours]..sort((a, b) => b.alertCount.compareTo(a.alertCount));
    final top = sorted.take(5).toList();

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final h in top)
          Chip(
            label: Text('${h.hour}:00 — ${h.alertCount} alerts'),
            backgroundColor: AppColors.surface,
            side: const BorderSide(color: AppColors.divider),
          ),
      ],
    );
  }
}

class _EmptyOpsState extends StatelessWidget {
  const _EmptyOpsState({this.message = 'No operational data for this period.'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          Icon(Icons.analytics_outlined, size: 40, color: AppColors.textSecondary.withValues(alpha: 0.6)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
