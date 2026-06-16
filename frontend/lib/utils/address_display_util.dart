/// Shared address parsing for rider/customer screens.
String formatAddressForDisplay(dynamic addressData) {
  if (addressData == null) return 'Address not available';

  // Regex to detect and remove Google Plus Codes (like M55C+MQJ)
  final plusCodePattern = RegExp(
    r'\b[A-Z0-9]{4,}\+[A-Z0-9]{2,}\b',
    caseSensitive: false,
  );

  String _cleanAddress(String text) {
    // Remove Plus Codes
    var cleaned = text.replaceAll(plusCodePattern, '');
    // Remove extra spaces
    cleaned = cleaned.replaceAll(RegExp(r'\s{2,}'), ' ');
    // Remove leading/trailing commas
    cleaned = cleaned.replaceAll(RegExp(r'^[,\s]+|[,\s]+$'), '');
    return cleaned.trim();
  }

  if (addressData is String) {
    final cleaned = _cleanAddress(addressData);
    // If after cleaning Plus Code, address is empty or too short, return not available
    if (cleaned.isEmpty || cleaned.length < 5) {
      return 'Address not available';
    }
    return cleaned;
  }

  if (addressData is Map) {
    final map = Map<String, dynamic>.from(addressData);
    
    // Try to extract formatted address from various keys
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
        final cleaned = _cleanAddress(value);
        if (cleaned.isNotEmpty && cleaned.length >= 5) {
          return cleaned;
        }
      }
    }
    
    // Try to build address from components
    final parts = <String>[];
    
    // Add address lines
    final line1 = map['address_line1']?.toString() ?? 
                  map['addressLine1']?.toString() ?? 
                  map['line1']?.toString();
    if (line1 != null && line1.trim().isNotEmpty) {
      parts.add(_cleanAddress(line1));
    }
    
    final line2 = map['address_line2']?.toString() ?? 
                  map['addressLine2']?.toString() ?? 
                  map['line2']?.toString();
    if (line2 != null && line2.trim().isNotEmpty) {
      parts.add(_cleanAddress(line2));
    }
    
    // Add landmark
    final landmark = map['landmark']?.toString();
    if (landmark != null && landmark.trim().isNotEmpty) {
      parts.add(_cleanAddress(landmark));
    }
    
    // Add city, state
    final city = map['city']?.toString();
    final state = map['state']?.toString();
    if (city != null && city.trim().isNotEmpty) {
      if (state != null && state.trim().isNotEmpty) {
        parts.add('$city, $state');
      } else {
        parts.add(city);
      }
    }
    
    // Add pincode
    final pincode = map['pincode']?.toString() ?? map['pin']?.toString();
    if (pincode != null && pincode.trim().isNotEmpty) {
      parts.add(pincode);
    }
    
    if (parts.isNotEmpty) {
      return parts.join(', ');
    }
  }

  final fallback = addressData.toString().trim();
  if (fallback.startsWith('{') && fallback.contains(':')) {
    return 'Address not available';
  }
  
  final cleaned = _cleanAddress(fallback);
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

  final addressData = order['delivery_address'] ?? order['address'];
  if (addressData is Map) {
    final lat = addressData['lat'] ?? addressData['latitude'];
    final lng = addressData['lng'] ?? addressData['longitude'];
    if (lat != null && lng != null) {
      return (
        lat: (lat as num).toDouble(),
        lng: (lng as num).toDouble(),
      );
    }
  }

  final orderLat = order['delivery_latitude'] ?? order['deliveryLatitude'];
  final orderLng = order['delivery_longitude'] ?? order['deliveryLongitude'];
  if (orderLat != null && orderLng != null) {
    return (
      lat: (orderLat as num).toDouble(),
      lng: (orderLng as num).toDouble(),
    );
  }

  return (lat: null, lng: null);
}
