/// Formats store hours from 24h (HH:MM) to readable 12h (e.g. 8 AM, 10:30 PM).
abstract final class StoreTimeUtil {
  static String format12h(String? time) {
    if (time == null || time.trim().isEmpty) return '';
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(time.trim());
    if (match == null) return time.trim();

    final hours = int.tryParse(match.group(1) ?? '') ?? 0;
    final minutes = int.tryParse(match.group(2) ?? '') ?? 0;
    if (hours < 0 || hours > 23 || minutes < 0 || minutes > 59) {
      return time.trim();
    }

    final period = hours >= 12 ? 'PM' : 'AM';
    final h12 = hours % 12 == 0 ? 12 : hours % 12;
    if (minutes == 0) return '$h12 $period';
    return '$h12:${minutes.toString().padLeft(2, '0')} $period';
  }

  static String formatRange(String? open, String? close) {
    final openLabel = format12h(open);
    final closeLabel = format12h(close);
    if (openLabel.isEmpty || closeLabel.isEmpty) return '';
    return '$openLabel – $closeLabel';
  }
}
