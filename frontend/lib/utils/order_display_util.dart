/// Short, user-facing order identifier (up to 8 chars).
/// Safe for short numeric backend IDs like "2" or "3".
String formatOrderDisplayId(String id) {
  final trimmed = id.trim();
  if (trimmed.isEmpty) return 'N/A';
  if (trimmed.length <= 8) return trimmed.toUpperCase();
  final start = trimmed.length - 8;
  return trimmed.substring(start).toUpperCase();
}

/// Primary label for rider order cards (customer name or order id).
String riderOrderTitle(Map<String, dynamic> order) {
  final user = order['user'];
  final fromUser = user is Map ? user['name']?.toString().trim() : null;
  final name = (order['customerName'] ??
          order['customer_name'] ??
          fromUser)
      ?.toString()
      .trim();
  if (name != null && name.isNotEmpty) return name;
  final id = order['id']?.toString() ?? '';
  return id.isEmpty ? 'Order' : 'Order #${formatOrderDisplayId(id)}';
}
