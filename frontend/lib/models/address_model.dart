import '../utils/address_display_util.dart';

/// Address model for user delivery addresses
enum AddressLabel {
  home,
  work,
  other;

  String get displayName {
    switch (this) {
      case AddressLabel.home:
        return 'Home';
      case AddressLabel.work:
        return 'Work';
      case AddressLabel.other:
        return 'Other';
    }
  }

  static AddressLabel fromString(String value) {
    switch (value.toLowerCase()) {
      case 'home':
        return AddressLabel.home;
      case 'work':
        return AddressLabel.work;
      case 'other':
        return AddressLabel.other;
      default:
        return AddressLabel.home;
    }
  }
}

class AddressModel {
  final String id;
  final String userId;
  final AddressLabel label;
  final String addressLine1;
  final String? addressLine2;
  final String? landmark;
  final String city;
  final String state;
  final String pincode;
  final double? latitude;
  final double? longitude;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AddressModel({
    required this.id,
    required this.userId,
    required this.label,
    required this.addressLine1,
    this.addressLine2,
    this.landmark,
    required this.city,
    required this.state,
    required this.pincode,
    this.latitude,
    this.longitude,
    this.isDefault = false,
    this.createdAt,
    this.updatedAt,
  });

  static String _cleanPart(String value) => cleanAddressPart(value);

  static List<String> _dedupeParts(Iterable<String> parts) =>
      dedupeAddressParts(parts);

  /// Get full address as a formatted string
  String get fullAddress {
    final parts = <String>[
      addressLine1,
      if (addressLine2 != null && addressLine2!.isNotEmpty) addressLine2!,
      if (landmark != null && landmark!.isNotEmpty) landmark!,
      '$city, $state',
      pincode,
    ];
    return _dedupeParts(parts).join(', ');
  }

  /// Clean 2-line address for checkout/cart display.
  String get displayAddress => formatCheckoutAddress(
        addressLine1: addressLine1,
        addressLine2: addressLine2,
        landmark: landmark,
        city: city,
        state: state,
        pincode: pincode,
      );

  /// Get short address (first line + city)
  String get shortAddress {
    final line = _cleanPart(addressLine1);
    if (line.isEmpty) return city;
    return '$line, $city';
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static String? _parseString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return value.toString().toLowerCase() == 'true';
  }

  /// Create AddressModel from JSON
  factory AddressModel.fromJson(Map<String, dynamic> json) {
    final city = _parseString(json['city']);
    final state = _parseString(json['state']);
    final labelRaw = _parseString(json['label']) ??
        _parseString(json['address_type'])?.toLowerCase() ??
        'home';
    return AddressModel(
      id: json['id']?.toString() ?? '',
      userId: (json['user_id'] ?? json['userId'])?.toString() ?? '',
      label: AddressLabel.fromString(labelRaw),
      addressLine1: _parseString(json['address_line1']) ??
          _parseString(json['addressLine1']) ??
          '',
      addressLine2: _parseString(json['address_line2']) ??
          _parseString(json['addressLine2']),
      landmark: _parseString(json['landmark']),
      city: city != null && city.isNotEmpty ? city : 'Dhanbad',
      state: state != null && state.isNotEmpty ? state : 'Jharkhand',
      pincode: _parseString(json['pincode']) ?? '',
      latitude: _parseDouble(json['latitude'] ?? json['lat']),
      longitude: _parseDouble(json['longitude'] ?? json['lng']),
      isDefault: _parseBool(json['is_default'] ?? json['isDefault']),
      createdAt: _parseDateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: _parseDateTime(json['updated_at'] ?? json['updatedAt']),
    );
  }

  /// Convert AddressModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'label': label.name,
      'address_line1': addressLine1,
      'address_line2': addressLine2,
      'landmark': landmark,
      'city': city,
      'state': state,
      'pincode': pincode,
      'latitude': latitude,
      'longitude': longitude,
      'is_default': isDefault,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  AddressModel copyWith({
    String? id,
    String? userId,
    AddressLabel? label,
    String? addressLine1,
    String? addressLine2,
    String? landmark,
    String? city,
    String? state,
    String? pincode,
    double? latitude,
    double? longitude,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AddressModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      label: label ?? this.label,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      landmark: landmark ?? this.landmark,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

