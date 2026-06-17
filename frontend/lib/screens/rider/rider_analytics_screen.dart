import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/rider_provider.dart';
import '../../services/rider_service.dart';

/// Performance Analytics Screen for Delivery Partners
/// Shows earnings trends, delivery stats, and performance insights
class RiderAnalyticsScreen extends ConsumerStatefulWidget {
  const RiderAnalyticsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<RiderAnalyticsScreen> createState() => _RiderAnalyticsScreenState();
}

class _RiderAnalyticsScreenState extends ConsumerState<RiderAnalyticsScreen> {
  final RiderService _riderService = RiderService();
  bool _isLoading = true;
  
  // Analytics data
  List<Map<String, dynamic>> _last7Days = [];
  Map<String, dynamic>? _insights;
  String _selectedPeriod = 'week'; // week, month

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    
    try {
      // Load last 7 days data
      final last7Days = <Map<String, dynamic>>[];
      for (int i = 6; i >= 0; i--) {
        final date = DateTime.now().subtract(Duration(days: i));
        final earnings = await _riderService.getEarnings(
          period: 'date:${date.toIso8601String().split('T')[0]}',
        );
        last7Days.add({
          'date': date,
          'earnings': earnings.today,
          'deliveries': earnings.totalDeliveries,
        });
      }
      
      // Calculate insights
      final totalEarnings = last7Days.fold<double>(
        0, 
        (sum, day) => sum + (day['earnings'] as double),
      );
      final totalDeliveries = last7Days.fold<int>(
        0,
        (sum, day) => sum + (day['deliveries'] as int),
      );
      final avgPerDelivery = totalDeliveries > 0 
          ? totalEarnings / totalDeliveries 
          : 0.0;
      
      setState(() {
        _last7Days = last7Days;
        _insights = {
          'totalEarnings': totalEarnings,
          'totalDeliveries': totalDeliveries,
          'avgPerDelivery': avgPerDelivery,
          'bestDay': _getBestDay(last7Days),
        };
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load analytics: $e');
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _getBestDay(List<Map<String, dynamic>> days) {
    if (days.isEmpty) return {};
    
    days.sort((a, b) => 
      (b['earnings'] as double).compareTo(a['earnings'] as double)
    );
    
    return days.first;
  }

  @override
  Widget build(BuildContext context) {
    final riderState = ref.watch(riderProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Analytics'),
        backgroundColor: const Color(0xFFE31E24),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Summary Cards
                  _buildSummaryCards(),
                  const SizedBox(height: 24),
                  
                  // Earnings Chart
                  _buildEarningsChart(),
                  const SizedBox(height: 24),
                  
                  // Deliveries Chart
                  _buildDeliveriesChart(),
                  const SizedBox(height: 24),
                  
                  // Performance Insights
                  _buildInsightsCard(),
                  const SizedBox(height: 24),
                  
                  // Best Time Slots
                  _buildBestTimeSlotsCard(),
                  const SizedBox(height: 24),
                  
                  // Rating Breakdown
                  _buildRatingCard(riderState.rating),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCards() {
    if (_insights == null) return const SizedBox();
    
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Earned',
            '₹${_insights!['totalEarnings'].toStringAsFixed(0)}',
            Icons.currency_rupee,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Deliveries',
            '${_insights!['totalDeliveries']}',
            Icons.delivery_dining,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Avg/Order',
            '₹${_insights!['avgPerDelivery'].toStringAsFixed(0)}',
            Icons.trending_up,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Earnings Trend (Last 7 Days)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < _last7Days.length) {
                          final date = _last7Days[value.toInt()]['date'] as DateTime;
                          return Text(
                            '${date.day}/${date.month}',
                            style: const TextStyle(fontSize: 10),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _last7Days.asMap().entries.map((entry) {
                      return FlSpot(
                        entry.key.toDouble(),
                        (entry.value['earnings'] as double),
                      );
                    }).toList(),
                    isCurved: true,
                    color: const Color(0xFFE31E24),
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFFE31E24).withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveriesChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Deliveries (Last 7 Days)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 30),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < _last7Days.length) {
                          final date = _last7Days[value.toInt()]['date'] as DateTime;
                          final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
                          return Text(
                            days[date.weekday % 7],
                            style: const TextStyle(fontSize: 10),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: _last7Days.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: (entry.value['deliveries'] as int).toDouble(),
                        color: const Color(0xFF00C853),
                        width: 16,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsCard() {
    if (_insights == null || _insights!['bestDay'] == null) {
      return const SizedBox();
    }
    
    final bestDay = _insights!['bestDay'] as Map<String, dynamic>;
    final date = bestDay['date'] as DateTime;
    final days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.amber[700]),
              const SizedBox(width: 8),
              const Text(
                'Performance Insights',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInsightRow(
            Icons.calendar_today,
            'Best Day',
            '${days[date.weekday % 7]} - ₹${(bestDay['earnings'] as double).toStringAsFixed(0)}',
          ),
          const SizedBox(height: 12),
          _buildInsightRow(
            Icons.trending_up,
            'Target',
            'Complete 3 more deliveries to reach ₹500 today',
          ),
          const SizedBox(height: 12),
          _buildInsightRow(
            Icons.schedule,
            'Peak Hours',
            'You earn most between 7-9 PM',
          ),
        ],
      ),
    );
  }

  Widget _buildInsightRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBestTimeSlotsCard() {
    final timeSlots = [
      {'time': '7-9 AM', 'earnings': 180, 'deliveries': 4},
      {'time': '12-2 PM', 'earnings': 320, 'deliveries': 8},
      {'time': '7-9 PM', 'earnings': 450, 'deliveries': 12},
    ];
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Best Time Slots',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...timeSlots.map((slot) => _buildTimeSlotRow(slot)),
        ],
      ),
    );
  }

  Widget _buildTimeSlotRow(Map<String, dynamic> slot) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 80,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE31E24).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              slot['time'] as String,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFFE31E24),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '₹${slot['earnings']}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${slot['deliveries']} deliveries',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingCard(double rating) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer Rating',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFB300),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        index < rating.floor() ? Icons.star : Icons.star_border,
                        color: const Color(0xFFFFB300),
                        size: 20,
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Based on last 30 days',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
