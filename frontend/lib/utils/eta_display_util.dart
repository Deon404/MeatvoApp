import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const Color etaGreen = Color(0xFF2E7D32);
const Color etaGreenBg = Color(0xFFE8F5E9);
const Color etaOrange = Color(0xFFE65100);
const Color etaOrangeBg = Color(0xFFFFF3E0);

/// Formats slot ETA from API for display below slot chips.
/// e.g. "by 12:30 PM" → "Delivery by ~12:30 PM"
String formatSlotEtaDisplay(String? estimatedEta) {
  if (estimatedEta == null || estimatedEta.trim().isEmpty) return '';
  final eta = estimatedEta.trim();
  if (eta.toLowerCase().startsWith('delivery')) return eta;
  if (eta.toLowerCase().startsWith('by ')) {
    return 'Delivery ~${eta.substring(3)}';
  }
  if (eta.toLowerCase().startsWith('in ')) {
    return 'Delivery $eta';
  }
  return 'Delivery by ~$eta';
}

/// Formats order ETA time as "by 12:30 PM".
String formatDeliveryByTime(DateTime eta) {
  return 'by ${DateFormat('h:mm a').format(eta)}';
}

/// Minutes remaining until ETA, clamped at zero.
int minutesUntilEta(DateTime eta, [DateTime? reference]) {
  final now = reference ?? DateTime.now();
  return (eta.difference(now).inMinutes).clamp(0, 9999);
}

/// "~25 mins away" label for active orders.
String formatMinutesAway(int? etaMinutes, DateTime? estimatedDeliveryTime) {
  final minutes = etaMinutes ??
      (estimatedDeliveryTime != null
          ? minutesUntilEta(estimatedDeliveryTime)
          : null);
  if (minutes == null) return '';
  if (minutes < 60) return '~$minutes mins away';
  final hours = minutes ~/ 60;
  final mins = minutes % 60;
  if (mins == 0) return '~$hours hr away';
  return '~$hours hr $mins mins away';
}

/// True when the order is still active but the estimated delivery time has passed.
bool isEtaPassed(DateTime? estimatedDeliveryTime, [DateTime? reference]) {
  if (estimatedDeliveryTime == null) return false;
  return (reference ?? DateTime.now()).isAfter(estimatedDeliveryTime);
}
