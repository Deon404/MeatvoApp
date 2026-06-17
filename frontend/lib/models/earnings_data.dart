class EarningsData {
  final double today;
  final double thisWeek;
  final double thisMonth;
  final double total;
  final int totalDeliveries;
  final double rating;
  final int completedDeliveries;
  final int totalRatings;
  final int cancelledDeliveries;

  const EarningsData({
    required this.today,
    required this.thisWeek,
    required this.thisMonth,
    required this.total,
    required this.totalDeliveries,
    required this.rating,
    this.completedDeliveries = 0,
    this.totalRatings = 0,
    this.cancelledDeliveries = 0,
  });

  factory EarningsData.fromApi({
    required Map<String, dynamic> todayData,
    required Map<String, dynamic> weekData,
    required Map<String, dynamic> monthData,
    double? lifetimeTotal,
  }) {
    final monthDeliveries = (monthData['deliveries'] as num?)?.toInt() ?? 0;
    final rating = (monthData['rating'] as num?)?.toDouble() ??
        (todayData['rating'] as num?)?.toDouble() ??
        0;
    return EarningsData(
      today: _parseAmount(todayData['total']),
      thisWeek: _parseAmount(weekData['total']),
      thisMonth: _parseAmount(monthData['total']),
      total: lifetimeTotal ?? _parseAmount(monthData['total']),
      totalDeliveries: monthDeliveries,
      rating: rating,
      completedDeliveries: monthDeliveries,
      totalRatings: monthDeliveries,
      cancelledDeliveries: 0,
    );
  }

  static double _parseAmount(dynamic value) => (value as num?)?.toDouble() ?? 0.0;
}
