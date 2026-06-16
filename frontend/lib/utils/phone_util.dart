/// Normalizes phone input to E.164 for India (+91) as expected by backend Zod
/// (`auth.validation.js`: `^\+[1-9]\d{1,14}$`).
String toE164India(String phone) {
  final trimmed = phone.trim();
  if (trimmed.startsWith('+')) {
    final rest = trimmed.substring(1).replaceAll(RegExp(r'\D'), '');
    return '+$rest';
  }

  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 10) return '+91$digits';
  if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
  if (digits.length == 11 && digits.startsWith('0')) {
    return '+91${digits.substring(1)}';
  }
  return '+$digits';
}
