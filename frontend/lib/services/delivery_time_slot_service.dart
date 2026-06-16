import 'package:intl/intl.dart';
import '../config/store_config.dart';

/// Delivery Time Slot Service
/// Handles delivery time slot logic based on date, time, and business hours
class DeliveryTimeSlotService {
  // Minimum preparation time in minutes (order processing + packaging)
  static const int minPreparationTimeMinutes = 30;
  
  // Time slot duration in hours
  static const int slotDurationHours = 3;
  
  // Available time slots (start times)
  static const List<String> availableSlotStartTimes = [
    '09:00', // 9:00 AM
    '12:00', // 12:00 PM
    '15:00', // 3:00 PM
    '18:00', // 6:00 PM
  ];

  /// Get available delivery dates (today + next 7 days)
  static List<DateTime> getAvailableDates() {
    final now = DateTime.now();
    final dates = <DateTime>[];
    
    for (int i = 0; i < 7; i++) {
      final date = DateTime(now.year, now.month, now.day + i);
      dates.add(date);
    }
    
    return dates;
  }

  /// Get formatted date string for display
  static String getFormattedDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);
    
    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == tomorrow) {
      return 'Tomorrow';
    } else {
      return DateFormat('EEEE, MMM d').format(date);
    }
  }

  /// Get available time slots for a given date
  /// Returns list of available slots with their status
  static List<TimeSlotInfo> getAvailableTimeSlots(DateTime selectedDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDateOnly = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final isToday = selectedDateOnly == today;
    
    final slots = <TimeSlotInfo>[];
    
    for (final startTimeStr in availableSlotStartTimes) {
      final slotStart = _parseTimeString(startTimeStr);
      final slotStartDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        slotStart.hour,
        slotStart.minute,
      );
      
      final slotEndDateTime = slotStartDateTime.add(Duration(hours: slotDurationHours));
      
      // Check if slot is in the past (for today only)
      bool isPast = false;
      if (isToday) {
        final minAvailableTime = now.add(Duration(minutes: minPreparationTimeMinutes));
        isPast = slotStartDateTime.isBefore(minAvailableTime);
      }
      
      // Check if slot is within business hours
      final isWithinBusinessHours = _isWithinBusinessHours(slotStartDateTime, slotEndDateTime);
      
      // Slot is available if not past and within business hours
      final isAvailable = !isPast && isWithinBusinessHours;
      
      slots.add(TimeSlotInfo(
        startTime: slotStartDateTime,
        endTime: slotEndDateTime,
        displayText: _formatTimeSlot(slotStartDateTime, slotEndDateTime),
        isAvailable: isAvailable,
        isPast: isPast,
      ));
    }
    
    return slots;
  }

  /// Parse time string (HH:mm format) to DateTime
  static DateTime _parseTimeString(String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return DateTime(2000, 1, 1, hour, minute);
  }

  /// Format time slot for display
  static String _formatTimeSlot(DateTime start, DateTime end) {
    final startFormatted = DateFormat('h:mm a').format(start);
    final endFormatted = DateFormat('h:mm a').format(end);
    return '$startFormatted - $endFormatted';
  }

  /// Check if time slot is within business hours
  static bool _isWithinBusinessHours(DateTime start, DateTime end) {
    final openingTime = _parseTimeString(StoreConfig.openingTime);
    final closingTime = _parseTimeString(StoreConfig.closingTime);
    
    final slotStartHour = start.hour;
    final slotStartMinute = start.minute;
    final slotEndHour = end.hour;
    final slotEndMinute = end.minute;
    
    final openingHour = openingTime.hour;
    final openingMinute = openingTime.minute;
    final closingHour = closingTime.hour;
    final closingMinute = closingTime.minute;
    
    // Check if slot start is after opening time
    final startAfterOpening = slotStartHour > openingHour ||
        (slotStartHour == openingHour && slotStartMinute >= openingMinute);
    
    // Check if slot end is before closing time
    final endBeforeClosing = slotEndHour < closingHour ||
        (slotEndHour == closingHour && slotEndMinute <= closingMinute);
    
    return startAfterOpening && endBeforeClosing;
  }

  /// Convert time slot to ISO timestamp string
  static String timeSlotToIsoString(DateTime selectedDate, String timeSlotDisplay) {
    // Parse time slot display string (e.g., "9:00 AM - 12:00 PM")
    final timeParts = timeSlotDisplay.split(' - ');
    if (timeParts.isEmpty) {
      // Fallback: use current time + 2 hours
      return DateTime.now().add(const Duration(hours: 2)).toIso8601String();
    }
    
    final startTime = timeParts[0].trim(); // "9:00 AM"
    final timeMatch = RegExp(r'(\d+):(\d+)\s*(AM|PM)').firstMatch(startTime);
    
    if (timeMatch != null) {
      int hour = int.parse(timeMatch.group(1)!);
      final minute = int.parse(timeMatch.group(2)!);
      final period = timeMatch.group(3);
      
      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      
      final deliveryDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        hour,
        minute,
      );
      
      return deliveryDateTime.toIso8601String();
    }
    
    // Fallback: use current time + 2 hours
    return DateTime.now().add(const Duration(hours: 2)).toIso8601String();
  }

  /// Get next available delivery time (minimum prep time from now)
  static DateTime getNextAvailableDeliveryTime() {
    final now = DateTime.now();
    return now.add(Duration(minutes: minPreparationTimeMinutes));
  }

  /// Check if a specific date and time slot is available
  static bool isTimeSlotAvailable(DateTime date, String timeSlotDisplay) {
    final slots = getAvailableTimeSlots(date);
    return slots.any((slot) => 
      slot.displayText == timeSlotDisplay && slot.isAvailable
    );
  }
}

/// Time Slot Information Model
class TimeSlotInfo {
  final DateTime startTime;
  final DateTime endTime;
  final String displayText;
  final bool isAvailable;
  final bool isPast;

  TimeSlotInfo({
    required this.startTime,
    required this.endTime,
    required this.displayText,
    required this.isAvailable,
    required this.isPast,
  });
}

