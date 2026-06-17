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

/// UI spec §9.15 / §9.16 — "Arriving in 12 min" for active order cards.
String formatArrivingInLabel(int? etaMinutes) {
  if (etaMinutes == null || etaMinutes <= 0) return '';
  if (etaMinutes < 60) return 'Arriving in $etaMinutes min';
  final hours = etaMinutes ~/ 60;
  final mins = etaMinutes % 60;
  if (mins == 0) return 'Arriving in $hours hr';
  return 'Arriving in ${hours}h ${mins}m';
}

/// True when the order is still active but the estimated delivery time has passed.
bool isEtaPassed(DateTime? estimatedDeliveryTime, [DateTime? reference]) {
  if (estimatedDeliveryTime == null) return false;
  return (reference ?? DateTime.now()).isAfter(estimatedDeliveryTime);
}

/// Picks a future arrival time for UI — prefers live ETA minutes over stale server timestamps.
DateTime? resolveDisplayEstimatedAt({
  int? etaMinutes,
  DateTime? liveEstimatedAt,
  DateTime? fallbackEstimatedAt,
  DateTime? reference,
}) {
  final now = reference ?? DateTime.now();
  if (etaMinutes != null && etaMinutes > 0) {
    return now.add(Duration(minutes: etaMinutes));
  }
  for (final candidate in [liveEstimatedAt, fallbackEstimatedAt]) {
    if (candidate != null && candidate.isAfter(now)) {
      return candidate;
    }
  }
  return null;
}

/// Distance-based ETA for order detail banner and active order cards.
String formatOrderDistanceEta(
  BuildContext context, {
  DateTime? estimatedDeliveryTime,
  int? etaMinutes,
}) {
  if (estimatedDeliveryTime == null) return '~45-60 mins';
  final now = DateTime.now();
  final diff = estimatedDeliveryTime.difference(now).inMinutes;
  if (diff <= 0) return 'Arriving soon';
  if (diff < 60) return '~$diff mins';
  return 'by ${TimeOfDay.fromDateTime(estimatedDeliveryTime).format(context)}';
}
