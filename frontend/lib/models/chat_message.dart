/// Chat message model for customer-delivery partner communication
class ChatMessage {
  final String text;
  final bool isFromCustomer;
  final DateTime time;

  ChatMessage({
    required this.text,
    required this.isFromCustomer,
    required this.time,
  });

  /// Create ChatMessage from JSON (socket event)
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['message'] as String? ?? json['text'] as String? ?? '',
      isFromCustomer: (json['sender'] as String? ?? 'customer') == 'customer',
      time: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'sender': isFromCustomer ? 'customer' : 'partner',
      'timestamp': time.toIso8601String(),
    };
  }
}
