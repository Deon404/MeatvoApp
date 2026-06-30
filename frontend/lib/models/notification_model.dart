/// Notification model for user notifications
class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type; // 'order', 'promotion', 'system', etc.
  final Map<String, dynamic>? data; // Additional data (JSONB)
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.data,
    this.isRead = false,
    required this.createdAt,
  });

  /// Hardened parser — never throws. The previous version used raw
  /// `as String` casts on `id`, `title`, `body`, `type` AND an unguarded
  /// `DateTime.parse` on `created_at`, any of which could crash the
  /// notifications screen if the backend returned a stray null or a
  /// numeric timestamp.
  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    bool parseBool(Object? v, bool fallback) {
      if (v == null) return fallback;
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final s = v.trim().toLowerCase();
        if (s == 'true' || s == '1' || s == 'yes') return true;
        if (s == 'false' || s == '0' || s == 'no') return false;
      }
      return fallback;
    }

    DateTime parseDate(Object? v) {
      if (v == null) return DateTime.now();
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return DateTime.now();
      }
    }

    final rawData = json['data'];
    final Map<String, dynamic>? parsedData =
        rawData is Map ? Map<String, dynamic>.from(rawData) : null;

    return NotificationModel(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? json['userId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      type: (json['type'] ?? 'system').toString(),
      data: parsedData,
      isRead: parseBool(json['is_read'] ?? json['read'], false),
      createdAt: parseDate(json['created_at'] ?? json['createdAt']),
    );
  }

  /// Create NotificationModel from map
  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel.fromJson(map);
  }

  /// Convert NotificationModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'body': body,
      'type': type,
      'data': data,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  NotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    String? type,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

