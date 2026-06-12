import 'package:intl/intl.dart';

import '../config/store_config.dart';

/// Express delivery — rider assigns without fixed Morning/Evening slots.
class ExpressDeliveryService {
  static const int minMinutes = 60;
  static const int maxMinutes = 120;

  static const String displayLabel = 'Delivery in 1-2 hours';

  static String get orderLabel {
    final today = DateTime.now();
    final datePart = _isToday(today) ? 'Today' : DateFormat('MMM d').format(today);
    return 'Express · 1-2 hours · $datePart';
  }

  static Map<String, dynamic> toOrderMeta() {
    final now = DateTime.now();
    return {
      'name': 'Express',
      'date': _formatDateKey(now),
      'time': '1-2 hours',
    };
  }

  /// Whether the store accepts orders right now (business hours).
  static bool isStoreOpen([DateTime? at]) {
    final moment = at ?? DateTime.now();
    final open = _parseHm(StoreConfig.openingTime);
    final close = _parseHm(StoreConfig.closingTime);
    final minutes = moment.hour * 60 + moment.minute;
    final openMin = open.$1 * 60 + open.$2;
    final closeMin = close.$1 * 60 + close.$2;
    return minutes >= openMin && minutes < closeMin;
  }

  /// User-facing message when checkout should be blocked outside hours.
  static String? storeClosedMessage([DateTime? at]) {
    if (isStoreOpen(at)) return null;
    final open = _parseHm(StoreConfig.openingTime);
    final hour = open.$1;
    final minute = open.$2;
    final period = hour >= 12 ? 'PM' : 'AM';
    var displayHour = hour % 12;
    if (displayHour == 0) displayHour = 12;
    final minuteStr = minute > 0 ? ':${minute.toString().padLeft(2, '0')}' : '';
    return 'Store closed — opens at $displayHour$minuteStr $period';
  }

  static String _formatDateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  static (int, int) _parseHm(String time) {
    final parts = time.split(':');
    return (int.parse(parts[0]), int.parse(parts[1]));
  }
}
