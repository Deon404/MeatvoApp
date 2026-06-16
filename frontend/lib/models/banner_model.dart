/// Banner model for promotional banners on home screen
class BannerModel {
  final String id;
  final String title;
  final String? subtitle;
  final String imageUrl;
  final String? link;
  final String? linkType; // 'category', 'product', 'url'
  final String? linkId; // ID of category/product if linkType is category/product
  final int displayOrder;
  final bool isActive;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  BannerModel({
    required this.id,
    required this.title,
    this.subtitle,
    required this.imageUrl,
    this.link,
    this.linkType,
    this.linkId,
    this.displayOrder = 0,
    this.isActive = true,
    this.startDate,
    this.endDate,
    this.createdAt,
    this.updatedAt,
  });

  /// Check if banner is currently valid (within date range and active).
  ///
  /// Captures `startDate` / `endDate` into locals so Dart's smart-cast
  /// promotes them and we avoid `!` operators. Final instance fields
  /// cannot be smart-cast (they're technically getters), so the previous
  /// `startDate!` / `endDate!` could in theory throw if a subclass
  /// overrode the getter to return null mid-frame.
  bool get isValid {
    if (!isActive) return false;
    final now = DateTime.now();
    final start = startDate;
    if (start != null && now.isBefore(start)) return false;
    final end = endDate;
    if (end != null && now.isAfter(end)) return false;
    return true;
  }

  /// Hardened parser — never throws on null / wrong type / missing keys.
  /// A bad banner row from the admin dashboard is rendered as a generic
  /// fallback (handled by `HeroBannerCarousel`) instead of crashing the
  /// home screen.
  factory BannerModel.fromJson(Map<String, dynamic> json) {
    String? asStringOrNull(Object? v) {
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    int parseInt(Object? v, int fallback) {
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v.trim()) ?? fallback;
      return fallback;
    }

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

    DateTime? parseDate(Object? v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    return BannerModel(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: asStringOrNull(json['subtitle']),
      // Empty imageUrl is allowed — the renderer falls back to a placeholder
      // banner. Anything is better than crashing the entire home screen.
      imageUrl: (json['image_url'] ?? '').toString().trim(),
      link: asStringOrNull(json['link']),
      linkType: asStringOrNull(json['link_type']),
      linkId: asStringOrNull(json['link_id']),
      displayOrder: parseInt(json['display_order'], 0),
      isActive: parseBool(json['is_active'], true),
      startDate: parseDate(json['start_date']),
      endDate: parseDate(json['end_date']),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  /// Convert BannerModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'image_url': imageUrl,
      'link': link,
      'link_type': linkType,
      'link_id': linkId,
      'display_order': displayOrder,
      'is_active': isActive,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  BannerModel copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? imageUrl,
    String? link,
    String? linkType,
    String? linkId,
    int? displayOrder,
    bool? isActive,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BannerModel(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      imageUrl: imageUrl ?? this.imageUrl,
      link: link ?? this.link,
      linkType: linkType ?? this.linkType,
      linkId: linkId ?? this.linkId,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

