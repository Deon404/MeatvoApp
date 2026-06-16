/// User model representing app users (customers, riders, admins)
class UserModel {
  final String id;
  final String? phoneNumber;
  final String? email;
  final String? name;
  final String role; // 'customer', 'rider', 'admin'
  final String? profileImageUrl;
  final double walletBalance;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.id,
    this.phoneNumber,
    this.email,
    this.name,
    required this.role,
    this.profileImageUrl,
    this.walletBalance = 0.0,
    this.createdAt,
    this.updatedAt,
  });

  /// Hardened parser — never throws. The previous `json['id'] as String`
  /// would crash if the backend returned an int id, and `json['role'] as
  /// String?` would crash if role was a number.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    String? asStringOrNull(Object? v) {
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    DateTime? parseDate(Object? v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    double parseDouble(Object? v, double fallback) {
      if (v == null) return fallback;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.trim()) ?? fallback;
      return fallback;
    }

    // Backend DB enum is `delivery`; app UI uses `rider`.
    final rawRole = (json['role'] ?? 'customer').toString().toUpperCase();
    final normalizedRole = switch (rawRole) {
      'ADMIN' => 'admin',
      'DELIVERY' || 'DELIVERY_PARTNER' => 'rider',
      'CUSTOMER' => 'customer',
      _ => rawRole.toLowerCase(),
    };

    return UserModel(
      id: (json['id'] ?? '').toString(),
      phoneNumber:
          asStringOrNull(json['phone']) ?? asStringOrNull(json['phoneNumber']),
      email: asStringOrNull(json['email']),
      name: asStringOrNull(json['name']),
      role: normalizedRole,
      profileImageUrl: asStringOrNull(json['profile_image']),
      walletBalance: parseDouble(json['wallet_balance'], 0.0),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  /// Convert UserModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phoneNumber, // Changed from 'phone_number' to 'phone'
      'email': email,
      'name': name,
      'role': role,
      'profile_image': profileImageUrl, // Changed from 'profile_image_url' to 'profile_image'
      'wallet_balance': walletBalance,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  UserModel copyWith({
    String? id,
    String? phoneNumber,
    String? email,
    String? name,
    String? role,
    String? profileImageUrl,
    double? walletBalance,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      walletBalance: walletBalance ?? this.walletBalance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

