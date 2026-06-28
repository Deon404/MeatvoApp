class OpsMetricValue {
  const OpsMetricValue({
    this.value,
    this.dataAvailable = false,
    this.sampleSize = 0,
    this.unit,
  });

  final double? value;
  final bool dataAvailable;
  final int sampleSize;
  final String? unit;

  factory OpsMetricValue.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const OpsMetricValue();
    return OpsMetricValue(
      value: json['value'] != null ? (json['value'] as num).toDouble() : null,
      dataAvailable: json['dataAvailable'] == true,
      sampleSize: (json['sampleSize'] as num?)?.toInt() ?? 0,
      unit: json['unit'] as String?,
    );
  }

  String format({String suffix = '', int decimals = 1}) {
    if (!dataAvailable || value == null) return '—';
    if (unit == 'percent') return '${value!.toStringAsFixed(decimals)}%';
    if (unit == 'minutes') return '${value!.toStringAsFixed(decimals)} min';
    if (unit == 'INR') return '₹${value!.toStringAsFixed(0)}';
    return '${value!.toStringAsFixed(decimals)}$suffix';
  }
}

class SoloVsBatchRatio {
  const SoloVsBatchRatio({
    this.solo = 0,
    this.batch = 0,
    this.ratio,
    this.dataAvailable = false,
    this.sampleSize = 0,
  });

  final int solo;
  final int batch;
  final double? ratio;
  final bool dataAvailable;
  final int sampleSize;

  factory SoloVsBatchRatio.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SoloVsBatchRatio();
    return SoloVsBatchRatio(
      solo: (json['solo'] as num?)?.toInt() ?? 0,
      batch: (json['batch'] as num?)?.toInt() ?? 0,
      ratio: json['ratio'] != null ? (json['ratio'] as num).toDouble() : null,
      dataAvailable: json['dataAvailable'] == true,
      sampleSize: (json['sampleSize'] as num?)?.toInt() ?? 0,
    );
  }
}

class CancelledByReason {
  const CancelledByReason({required this.reason, required this.count});

  final String reason;
  final int count;

  factory CancelledByReason.fromJson(Map<String, dynamic> json) {
    return CancelledByReason(
      reason: json['reason']?.toString() ?? 'Unknown',
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class PeakModeHour {
  const PeakModeHour({required this.hour, required this.alertCount});

  final int hour;
  final int alertCount;

  factory PeakModeHour.fromJson(Map<String, dynamic> json) {
    return PeakModeHour(
      hour: (json['hour'] as num?)?.toInt() ?? 0,
      alertCount: (json['alertCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class OpsTrendPoint {
  const OpsTrendPoint({
    required this.bucket,
    this.orders = 0,
    this.delivered = 0,
    this.cancelled = 0,
    this.revenue = 0,
    this.avgRiderTripMinutes,
    this.avgDispatchDelayMinutes,
    this.batchPercentage,
    this.dataAvailable = false,
  });

  final String bucket;
  final int orders;
  final int delivered;
  final int cancelled;
  final double revenue;
  final double? avgRiderTripMinutes;
  final double? avgDispatchDelayMinutes;
  final double? batchPercentage;
  final bool dataAvailable;

  factory OpsTrendPoint.fromJson(Map<String, dynamic> json) {
    return OpsTrendPoint(
      bucket: json['bucket']?.toString() ?? '',
      orders: (json['orders'] as num?)?.toInt() ?? 0,
      delivered: (json['delivered'] as num?)?.toInt() ?? 0,
      cancelled: (json['cancelled'] as num?)?.toInt() ?? 0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      avgRiderTripMinutes: (json['avgRiderTripMinutes'] as num?)?.toDouble(),
      avgDispatchDelayMinutes:
          (json['avgDispatchDelayMinutes'] as num?)?.toDouble(),
      batchPercentage: (json['batchPercentage'] as num?)?.toDouble(),
      dataAvailable: json['dataAvailable'] == true,
    );
  }
}

class DataCompleteness {
  const DataCompleteness({
    this.overallScore = 0,
    this.metricsAvailable = 0,
    this.metricsTotal = 0,
    this.message = '',
    this.metrics = const [],
  });

  final int overallScore;
  final int metricsAvailable;
  final int metricsTotal;
  final String message;
  final List<DataCompletenessMetric> metrics;

  bool get isPartial =>
      metricsTotal > 0 && metricsAvailable < metricsTotal;

  factory DataCompleteness.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const DataCompleteness();
    final rawMetrics = json['metrics'];
    return DataCompleteness(
      overallScore: (json['overallScore'] as num?)?.toInt() ?? 0,
      metricsAvailable: (json['metricsAvailable'] as num?)?.toInt() ?? 0,
      metricsTotal: (json['metricsTotal'] as num?)?.toInt() ?? 0,
      message: json['message']?.toString() ?? '',
      metrics: rawMetrics is List
          ? rawMetrics
              .map((e) => DataCompletenessMetric.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList()
          : const [],
    );
  }
}

class DataCompletenessMetric {
  const DataCompletenessMetric({
    required this.key,
    this.dataAvailable = false,
    this.sampleSize = 0,
    this.reason,
  });

  final String key;
  final bool dataAvailable;
  final int sampleSize;
  final String? reason;

  factory DataCompletenessMetric.fromJson(Map<String, dynamic> json) {
    return DataCompletenessMetric(
      key: json['key']?.toString() ?? '',
      dataAvailable: json['dataAvailable'] == true,
      sampleSize: (json['sampleSize'] as num?)?.toInt() ?? 0,
      reason: json['reason'] as String?,
    );
  }
}

class AdminOpsMetrics {
  const AdminOpsMetrics({
    this.period = '7d',
    this.granularity = 'day',
    this.metrics = const {},
    this.trends = const [],
    this.dataCompleteness = const DataCompleteness(),
    this.rollupUsed = false,
  });

  final String period;
  final String granularity;
  final Map<String, dynamic> metrics;
  final List<OpsTrendPoint> trends;
  final DataCompleteness dataCompleteness;
  final bool rollupUsed;

  OpsMetricValue metric(String key) =>
      OpsMetricValue.fromJson(metrics[key] as Map<String, dynamic>?);

  SoloVsBatchRatio get soloVsBatchRatio =>
      SoloVsBatchRatio.fromJson(metrics['soloVsBatchRatio'] as Map<String, dynamic>?);

  List<CancelledByReason> get cancelledByReason {
    final raw = metrics['ordersCancelledByReason'];
    if (raw is! List) return const [];
    return raw
        .map((e) => CancelledByReason.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  List<PeakModeHour> get peakModeHours {
    final raw = metrics['peakModeHours'];
    if (raw is! List) return const [];
    return raw
        .map((e) => PeakModeHour.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  factory AdminOpsMetrics.fromJson(Map<String, dynamic> json) {
    final rawTrends = json['trends'];
    return AdminOpsMetrics(
      period: json['period']?.toString() ?? '7d',
      granularity: json['granularity']?.toString() ?? 'day',
      metrics: json['metrics'] is Map
          ? Map<String, dynamic>.from(json['metrics'] as Map)
          : const {},
      trends: rawTrends is List
          ? rawTrends
              .map((e) => OpsTrendPoint.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList()
          : const [],
      dataCompleteness: DataCompleteness.fromJson(
        json['dataCompleteness'] as Map<String, dynamic>?,
      ),
      rollupUsed: json['rollupUsed'] == true,
    );
  }
}
