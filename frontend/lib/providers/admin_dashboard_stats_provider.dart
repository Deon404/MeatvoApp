import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminDashboardStats {
  const AdminDashboardStats({
    this.todayOrders,
    this.todayRevenue,
  });

  final int? todayOrders;
  final double? todayRevenue;
}

final adminDashboardStatsProvider =
    StateProvider<AdminDashboardStats?>((ref) => null);
