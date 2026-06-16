/// Delivery slot from backend GET /delivery/slots
class DeliverySlotModel {
  final int id;
  final String name;
  final String time;
  final DateTime date;
  final int capacity;
  final int booked;
  final int remaining;
  final bool isFull;
  final bool isToday;
  final bool? jsonAvailable;
  final String? estimatedEta;

  const DeliverySlotModel({
    required this.id,
    required this.name,
    required this.time,
    required this.date,
    required this.capacity,
    required this.booked,
    required this.remaining,
    required this.isFull,
    this.isToday = false,
    this.jsonAvailable,
    this.estimatedEta,
  });

  /// Whether the slot can be selected (backend may send `available` or `isFull`).
  bool get available {
    if (isPast) return false;
    if (jsonAvailable != null) return jsonAvailable!;
    return !isFull;
  }

  /// True when the slot window has already ended (today's past slots).
  bool get isPast {
    final end = _slotEndDateTime;
    if (end == null) return false;
    return end.isBefore(DateTime.now());
  }

  String get dateLabel => formatDateLabel(date);

  static String formatDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) return 'Today';
    if (dateOnly == tomorrow) return 'Tomorrow';

    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
  }

  DateTime? get _slotEndDateTime {
    final parts = time.split(' - ');
    if (parts.length < 2) return null;
    return _parseTimeOnDate(parts[1].trim(), date);
  }

  static DateTime parseSlotDate(dynamic dateRaw) {
    if (dateRaw is DateTime) {
      return DateTime(dateRaw.year, dateRaw.month, dateRaw.day);
    }
    final str = dateRaw?.toString() ?? '';
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(str);
    if (match != null) {
      return DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      );
    }
    final parsed = DateTime.tryParse(str) ?? DateTime.tryParse('${str}T00:00:00');
    if (parsed != null) {
      return DateTime(parsed.year, parsed.month, parsed.day);
    }
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime? _parseTimeOnDate(String timeText, DateTime onDate) {
    final match =
        RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)', caseSensitive: false)
            .firstMatch(timeText);
    if (match == null) return null;

    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final period = match.group(3)!.toUpperCase();
    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;

    return DateTime(onDate.year, onDate.month, onDate.day, hour, minute);
  }

  factory DeliverySlotModel.fromJson(Map<String, dynamic> json) {
    final dateRaw = json['date'] ?? json['slot_date'];
    final parsedDate = parseSlotDate(dateRaw);

    final remainingRaw = json['remaining'];
    final capacity = _toInt(json['capacity']);
    final booked = _toInt(json['booked']);
    final remaining = remainingRaw != null
        ? _toInt(remainingRaw)
        : (capacity - booked).clamp(0, capacity);

    final isFull = json['isFull'] == true ||
        json['is_full'] == true ||
        remaining <= 0;
    final availableRaw = json['available'];

    return DeliverySlotModel(
      id: _toInt(json['id']),
      name: (json['name'] ?? '').toString(),
      time: (json['time'] ?? '').toString(),
      date: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
      capacity: capacity,
      booked: booked,
      remaining: remaining,
      isFull: isFull,
      isToday: json['isToday'] == true || json['is_today'] == true,
      jsonAvailable: availableRaw is bool ? availableRaw : null,
      estimatedEta: (json['estimated_eta'] ?? json['estimatedEta'])
          ?.toString(),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String formatDateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Map<String, dynamic> toOrderPayload() => {
        if (id > 0) 'id': id,
        'name': name,
        'date': formatDateKey(date),
        'time': time,
      };

  String get displayLabel =>
      time.isNotEmpty ? '$name ($time)' : name;

  /// Group key for sorting slots by calendar day.
  String get dateKey => formatDateKey(date);

  /// Fallback when slots API fails or returns empty.
  static DeliverySlotModel expressFallback() {
    final now = DateTime.now();
    return DeliverySlotModel(
      id: 0,
      name: 'Express Delivery',
      time: '1-2 hours',
      date: DateTime(now.year, now.month, now.day),
      capacity: 1,
      booked: 0,
      remaining: 1,
      isFull: false,
      isToday: true,
      jsonAvailable: true,
    );
  }
}
