// Shared address parsing for rider/customer screens.

import '../models/address_model.dart';

final RegExp plusCodePattern = RegExp(
  r'\b[A-Z0-9]{4,}\+[A-Z0-9]{2,}\b',
  caseSensitive: false,
);

/// Remove Google Plus Codes and normalize whitespace/comma edges.
String stripPlusCode(String text) {
  var cleaned = text.replaceAll(plusCodePattern, '');
  cleaned = cleaned.replaceAll(RegExp(r'\s{2,}'), ' ');
  cleaned = cleaned.replaceAll(RegExp(r'^[,\s]+|[,\s]+$'), '');
  return cleaned.trim();
}

/// Clean a single address part (Plus Code strip + whitespace).
String cleanAddressPart(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  return stripPlusCode(trimmed);
}

/// Deduplicate address parts case-insensitively after cleaning each part.
List<String> dedupeAddressParts(Iterable<String> parts) {
  final seen = <String>{};
  final result = <String>[];
  for (final raw in parts) {
    final part = cleanAddressPart(raw);
    if (part.isEmpty) continue;
    final key = part.toLowerCase();
    if (seen.add(key)) result.add(part);
  }
  return result;
}

/// Join address parts with deduplication and Plus Code removal.
String formatAddressLine(Iterable<String> parts) {
  return dedupeAddressParts(parts).join(', ');
}

/// Backend requires addressLine1 length >= 5.
const int kAddressLine1MinLength = 5;

/// Build addressLine1 for API — appends street/locality when flat/house is too short.
String ensureAddressLine1MinLength({
  required String flatOrPrimary,
  String? street,
  String? locality,
  int minLength = kAddressLine1MinLength,
}) {
  final primary = cleanAddressPart(flatOrPrimary);
  if (primary.length >= minLength) return primary;

  final combined = formatAddressLine([
    primary,
    if (street != null && street.isNotEmpty) street,
    if (locality != null && locality.isNotEmpty) locality,
  ]);
  return combined.isNotEmpty ? combined : primary;
}

/// Omit addressLine2 when its content is already present in line1.
String? secondaryAddressLineIfDistinct(String line1, String? street) {
  if (street == null || street.isEmpty) return null;
  final streetClean = cleanAddressPart(street);
  if (streetClean.isEmpty) return null;
  final normalizedLine1 = line1.toLowerCase();
  final normalizedStreet = streetClean.toLowerCase();
  if (normalizedLine1 == normalizedStreet ||
      normalizedLine1.contains(normalizedStreet)) {
    return null;
  }
  return streetClean;
}

Map<String, dynamic> geocodedMapFromAddressModel(AddressModel address) {
  return {
    'address_line1': address.addressLine1,
    if (address.addressLine2 != null) 'address_line2': address.addressLine2,
    'city': address.city,
    'state': address.state,
    'pincode': address.pincode,
    if (address.landmark != null) 'landmark': address.landmark,
    'place_name': address.city,
  };
}

/// Parsed reverse-geocode fields for address forms (street != house/flat).
class GeocodedAddressFields {
  final String street;
  final String locality;
  final String state;
  final String pincode;
  final String? landmark;

  const GeocodedAddressFields({
    this.street = '',
    this.locality = '',
    this.state = '',
    this.pincode = '',
    this.landmark,
  });

  factory GeocodedAddressFields.fromMap(Map<String, dynamic> address) {
    final streetParts = dedupeAddressParts([
      address['address_line1']?.toString() ?? '',
      address['address_line2']?.toString() ?? '',
    ]);
    final locality = cleanAddressPart(
      address['city']?.toString() ??
          address['place_name']?.toString() ??
          '',
    );
    return GeocodedAddressFields(
      street: streetParts.join(', '),
      locality: locality,
      state: cleanAddressPart(address['state']?.toString() ?? ''),
      pincode: cleanAddressPart(address['pincode']?.toString() ?? ''),
      landmark: () {
        final value = cleanAddressPart(address['landmark']?.toString() ?? '');
        return value.isEmpty ? null : value;
      }(),
    );
  }

  /// Read-only area line for confirm sheet, e.g. "Jena · Jharkhand · 827010".
  String get areaDisplayLine {
    return formatAddressLine([
      if (locality.isNotEmpty) locality,
      if (state.isNotEmpty) state,
      if (pincode.isNotEmpty) pincode,
    ]).replaceAll(', ', ' · ');
  }
}

/// Combine place name and line1 without duplicating segments or Plus Codes.
String combineAddressLine1(String placeName, String addressLine1) {
  final place = cleanAddressPart(placeName);
  final line = cleanAddressPart(addressLine1);
  if (place.isEmpty) return line;
  if (line.isEmpty) return place;
  if (line.toLowerCase().contains(place.toLowerCase())) return line;
  if (place.toLowerCase().contains(line.toLowerCase())) return place;
  return formatAddressLine([place, line]);
}

/// Build a full address string from a map payload.
String buildAddressStringFromMap(Map<String, dynamic> address) {
  return formatAddressLine([
    if (address['address_line1'] != null) address['address_line1'].toString(),
    if (address['address_line2'] != null) address['address_line2'].toString(),
    if (address['landmark'] != null) address['landmark'].toString(),
    if (address['city'] != null) address['city'].toString(),
    if (address['state'] != null) address['state'].toString(),
    if (address['pincode'] != null) address['pincode'].toString(),
  ]);
}

String formatAddressForDisplay(dynamic addressData) {
  if (addressData == null) return 'Address not available';

  if (addressData is String) {
    final cleaned = stripPlusCode(addressData);
    if (cleaned.isEmpty || cleaned.length < 5) {
      return 'Address not available';
    }
    return cleaned;
  }

  if (addressData is Map) {
    final map = Map<String, dynamic>.from(addressData);

    // Try single formatted fields first
    for (final key in const [
      'formatted',
      'formatted_address',
      'text',
      'address',
      'raw',
      'street',
      'line1',
      'address_line1',
      'addressLine1',
    ]) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        final cleaned = stripPlusCode(value);
        if (cleaned.isNotEmpty && cleaned.length >= 5) {
          return cleaned;
        }
      }
    }

    // Build from components with deduplication
    final parts = <String>[];

    final line1 = map['address_line1']?.toString() ??
        map['addressLine1']?.toString() ??
        map['line1']?.toString();
    if (line1 != null && line1.trim().isNotEmpty) {
      parts.add(cleanAddressPart(line1));
    }

    final line2 = map['address_line2']?.toString() ??
        map['addressLine2']?.toString() ??
        map['line2']?.toString();
    if (line2 != null && line2.trim().isNotEmpty) {
      parts.add(cleanAddressPart(line2));
    }

    final landmark = map['landmark']?.toString();
    if (landmark != null && landmark.trim().isNotEmpty) {
      parts.add(cleanAddressPart(landmark));
    }

    final city = map['city']?.toString();
    final state = map['state']?.toString();
    if (city != null && city.trim().isNotEmpty) {
      if (state != null && state.trim().isNotEmpty) {
        parts.add('$city, $state');
      } else {
        parts.add(city);
      }
    }

    final pincode = map['pincode']?.toString() ?? map['pin']?.toString();
    if (pincode != null && pincode.trim().isNotEmpty) {
      parts.add(pincode);
    }

    if (parts.isNotEmpty) {
      return formatAddressLine(parts);
    }
  }

  final fallback = addressData.toString().trim();
  if (fallback.startsWith('{') && fallback.contains(':')) {
    return 'Address not available';
  }

  final cleaned = stripPlusCode(fallback);
  if (cleaned.isEmpty || cleaned.length < 5) {
    return 'Address not available';
  }

  return cleaned;
}

/// Extract lat/lng from order or address payloads.
({double? lat, double? lng}) resolveAddressCoords(
  Map<String, dynamic>? order,
) {
  if (order == null) return (lat: null, lng: null);

  double? parseCoord(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  final addressData = order['delivery_address'] ?? order['address'];
  if (addressData is Map) {
    final lat = parseCoord(addressData['lat'] ?? addressData['latitude']);
    final lng = parseCoord(addressData['lng'] ?? addressData['longitude']);
    if (lat != null && lng != null) {
      return (lat: lat, lng: lng);
    }
  }

  final orderLat =
      parseCoord(order['delivery_latitude'] ?? order['deliveryLatitude']);
  final orderLng =
      parseCoord(order['delivery_longitude'] ?? order['deliveryLongitude']);
  if (orderLat != null && orderLng != null) {
    return (lat: orderLat, lng: orderLng);
  }

  return (lat: null, lng: null);
}
