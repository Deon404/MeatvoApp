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

/// Meatvo serves Bokaro only — city/state omitted from UI; pincode is shown.
final RegExp _bokaroPincodePattern = RegExp(r'\b827\d{3}\b');
final RegExp _pincodePhrasePattern = RegExp(r'pin\s*code', caseSensitive: false);

String? _extractPincodeFromPart(String part) {
  final match = _bokaroPincodePattern.firstMatch(part);
  if (match != null) return match.group(0);
  final trimmed = part.trim();
  if (RegExp(r'^\d{6}$').hasMatch(trimmed)) return trimmed;
  return null;
}

String? _normalizeDisplayPincode(String? value) {
  if (value == null) return null;
  return _extractPincodeFromPart(value.trim());
}

String? _resolveDisplayPincode({
  String? pincode,
  Iterable<String?> sources = const [],
}) {
  final fromField = _normalizeDisplayPincode(pincode);
  if (fromField != null) return fromField;

  for (final source in sources) {
    if (source == null || source.trim().isEmpty) continue;
    final fromSource = _extractPincodeFromPart(source);
    if (fromSource != null) return fromSource;
    for (final segment in source.split(',')) {
      final fromSegment = _extractPincodeFromPart(cleanAddressPart(segment));
      if (fromSegment != null) return fromSegment;
    }
  }
  return null;
}

String _appendPincode(String locality, String? pin) {
  if (pin == null || pin.isEmpty) return locality;
  if (locality.isEmpty || locality == 'Delivery address') return pin;
  if (locality.toLowerCase().contains(pin)) return locality;
  return '$locality, $pin';
}

const Set<String> _redundantLocalityNames = {
  'bokaro',
  'bokaro steel city',
  'bsc',
  'steel city',
  'jharkhand',
  'jhr',
  'india',
  'dhanbad',
};

bool isRedundantLocalitySegment(String part) {
  var segment = cleanAddressPart(part);
  if (segment.isEmpty) return true;

  segment = segment
      .replaceAll(_pincodePhrasePattern, '')
      .replaceAll(_bokaroPincodePattern, '')
      .replaceAll(RegExp(r'^[,\s\-–]+|[,\s\-–]+$'), '')
      .trim();
  if (segment.isEmpty) return true;

  final lower = segment.toLowerCase();
  if (RegExp(r'^\d{6}$').hasMatch(lower)) return true;
  if (RegExp(r'^\d{1,2}$').hasMatch(lower)) return true;
  if (_redundantLocalityNames.contains(lower)) return true;

  final compact = lower
      .replaceAll(_bokaroPincodePattern, '')
      .replaceAll(_pincodePhrasePattern, '')
      .replaceAll(RegExp(r'[-–]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (compact.isEmpty || _redundantLocalityNames.contains(compact)) {
    return true;
  }

  if (lower.contains('bokaro')) {
    final withoutBokaro = lower
        .replaceAll(RegExp(r'\bbokaro\b'), '')
        .replaceAll(RegExp(r'\bsteel\b'), '')
        .replaceAll(RegExp(r'\bcity\b'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (withoutBokaro.isEmpty || RegExp(r'^\d{1,2}$').hasMatch(withoutBokaro)) {
      return true;
    }
  }

  return false;
}

String stripInlineLocalityNoise(String part) {
  var result = part;
  result = result.replaceAll(_bokaroPincodePattern, '');
  result = result.replaceAll(
    RegExp(r'pin\s*code\s*[-:]?\s*', caseSensitive: false),
    '',
  );
  for (final name in _redundantLocalityNames) {
    result = result.replaceAll(
      RegExp('\\b${RegExp.escape(name)}\\b', caseSensitive: false),
      '',
    );
  }
  result = result.replaceAll(RegExp(r'\s{2,}'), ' ');
  return cleanAddressPart(result);
}

bool isUsefulLocalityName(String? value) {
  if (value == null || value.trim().isEmpty) return false;
  return !isRedundantLocalitySegment(value);
}

/// Short locality address for customer/rider/admin UI (pincode appended).
String formatHyperlocalAddress({
  required String addressLine1,
  String? addressLine2,
  String? landmark,
  String? city,
  String? state,
  String? pincode,
}) {
  final resolvedPin = _resolveDisplayPincode(
    pincode: pincode,
    sources: [addressLine1, addressLine2, landmark],
  );
  final segments = <String>[];

  void addRaw(String? raw) {
    if (raw == null || raw.trim().isEmpty) return;
    for (final segment in raw.split(',')) {
      final part = cleanAddressPart(segment);
      if (part.isEmpty || isRedundantLocalitySegment(part)) continue;
      final cleaned = stripInlineLocalityNoise(part);
      if (cleaned.isEmpty || isRedundantLocalitySegment(cleaned)) continue;
      segments.add(cleaned);
    }
  }

  addRaw(addressLine1);
  addRaw(addressLine2);
  addRaw(landmark);
  if (isUsefulLocalityName(city)) addRaw(city);

  final locality = dedupeAddressParts(segments).join(', ');
  if (locality.isNotEmpty) {
    return _appendPincode(locality, resolvedPin);
  }

  final fallback = stripInlineLocalityNoise(cleanAddressPart(addressLine1));
  if (fallback.isNotEmpty) {
    return _appendPincode(fallback, resolvedPin);
  }
  return resolvedPin ?? 'Delivery address';
}

/// Strip city/state from a free-form address string; keep pincode at the end.
String formatRawAddressString(String value, {String? pincode}) {
  final cleaned = stripPlusCode(value);
  if (cleaned.isEmpty) return '';

  var resolvedPin = _resolveDisplayPincode(
    pincode: pincode,
    sources: [cleaned],
  );
  final segments = <String>[];

  for (final segment in cleaned.split(',')) {
    final part = cleanAddressPart(segment);
    resolvedPin ??= _extractPincodeFromPart(part);
    if (part.isEmpty || isRedundantLocalitySegment(part)) continue;
    final stripped = stripInlineLocalityNoise(part);
    resolvedPin ??= _extractPincodeFromPart(stripped);
    if (stripped.isEmpty || isRedundantLocalitySegment(stripped)) continue;
    segments.add(stripped);
  }

  final locality = dedupeAddressParts(segments).join(', ');
  if (locality.isNotEmpty) {
    return _appendPincode(locality, resolvedPin);
  }

  final fallback = stripInlineLocalityNoise(cleanAddressPart(cleaned));
  if (fallback.isNotEmpty) {
    return _appendPincode(fallback, resolvedPin);
  }
  return resolvedPin ?? cleaned;
}

/// Two-line checkout address — strips repeated city/state/pincode from street parts.
String formatCheckoutAddress({
  required String addressLine1,
  String? addressLine2,
  String? landmark,
  required String city,
  required String state,
  required String pincode,
}) {
  return formatHyperlocalAddress(
    addressLine1: addressLine1,
    addressLine2: addressLine2,
    landmark: landmark,
    city: city,
    state: state,
    pincode: pincode,
  );
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

  /// Read-only area line for confirm sheet — locality + pincode.
  String get areaDisplayLine {
    final pin = _normalizeDisplayPincode(pincode) ?? '';
    if (isUsefulLocalityName(locality)) {
      final loc = cleanAddressPart(locality);
      if (pin.isNotEmpty) return '$loc · $pin';
      return loc;
    }
    return pin;
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
  return formatHyperlocalAddress(
    addressLine1: address['address_line1']?.toString() ?? '',
    addressLine2: address['address_line2']?.toString(),
    landmark: address['landmark']?.toString(),
    city: address['city']?.toString(),
    state: address['state']?.toString(),
    pincode: address['pincode']?.toString(),
  );
}

String formatAddressForDisplay(dynamic addressData) {
  if (addressData == null) return 'Address not available';

  if (addressData is String) {
    final trimmed = addressData.trim();
    if (trimmed.startsWith('{') && trimmed.contains(':')) {
      final textMatch = RegExp(
        r'(?:text|formatted):\s*([^}]+?)(?:,\s*(?:formatted|text|raw|lat|lng):|$)',
      ).firstMatch(trimmed);
      if (textMatch != null) {
        final extracted = formatRawAddressString(textMatch.group(1)!.trim());
        if (extracted.isNotEmpty) return extracted;
      }
    }

    final formatted = formatRawAddressString(addressData);
    if (formatted.isEmpty) return 'Address not available';
    return formatted;
  }

  if (addressData is Map) {
    final map = Map<String, dynamic>.from(addressData);
    final mapPin = map['pincode']?.toString() ?? map['pin']?.toString();

    final hasAddressLines = [
      map['address_line1'],
      map['addressLine1'],
      map['line1'],
      map['address_line2'],
      map['addressLine2'],
      map['line2'],
      map['landmark'],
    ].any((value) => value != null && value.toString().trim().isNotEmpty);

    if (hasAddressLines) {
      final formatted = formatHyperlocalAddress(
        addressLine1: map['address_line1']?.toString() ??
            map['addressLine1']?.toString() ??
            map['line1']?.toString() ??
            '',
        addressLine2: map['address_line2']?.toString() ??
            map['addressLine2']?.toString() ??
            map['line2']?.toString(),
        landmark: map['landmark']?.toString(),
        city: map['city']?.toString(),
        state: map['state']?.toString(),
        pincode: mapPin,
      );
      if (formatted.isNotEmpty && formatted != 'Delivery address') {
        return formatted;
      }
    }

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
        final formatted = formatRawAddressString(value, pincode: mapPin);
        if (formatted.isNotEmpty) return formatted;
      }
    }
  }

  final fallback = addressData.toString().trim();
  if (fallback.startsWith('{') && fallback.contains(':')) {
    return 'Address not available';
  }

  final formatted = formatRawAddressString(fallback);
  if (formatted.isEmpty) return 'Address not available';
  return formatted;
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
