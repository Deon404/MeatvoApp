import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../config/env_config.dart';
import '../config/google_maps_setup.dart';
import '../config/store_config.dart';

/// Road-following route from Google Directions API.
class DrivingRouteResult {
  final List<({double lat, double lng})> points;
  final double distanceKm;
  final int durationMinutes;
  final String distanceFormatted;
  final String durationFormatted;

  const DrivingRouteResult({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
    required this.distanceFormatted,
    required this.durationFormatted,
  });
}

/// Maps Service for location and geocoding operations
class MapsService {
  String? lastPlacesError;

  void _clearPlacesError() => lastPlacesError = null;

  void _setPlacesError(String? status, {required String apiName}) {
    final hint = GoogleMapsSetup.hintForApiStatus(status, apiName: apiName);
    lastPlacesError = hint.isNotEmpty
        ? hint
        : (status != null && status.isNotEmpty ? 'Location search unavailable ($status)' : null);
  }
  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Check location permissions
  Future<LocationPermission> checkLocationPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Request location permissions
  Future<LocationPermission> requestLocationPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Check if location permission is granted
  Future<bool> hasLocationPermission() async {
    final permission = await checkLocationPermission();
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Check if location permission is denied forever
  Future<bool> isPermissionDeniedForever() async {
    final permission = await checkLocationPermission();
    return permission == LocationPermission.deniedForever;
  }

  /// Open app settings for location permission
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Open app settings
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Resolves permission + fetches GPS. On Android, calling [getCurrentPosition]
  /// while location is off triggers the native "Turn on" / Location Accuracy dialog.
  Future<Position> resolveCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeLimit = const Duration(seconds: 15),
    bool requestPermissionIfDenied = true,
  }) async {
    LocationPermission permission = await checkLocationPermission();

    if (permission == LocationPermission.denied && requestPermissionIfDenied) {
      permission = await requestLocationPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationException(
        'Location access is off',
        'Enable location access in app settings to use current location.',
        LocationErrorType.permissionDeniedForever,
      );
    }

    if (permission == LocationPermission.denied) {
      throw LocationException(
        'Location permission needed',
        'Allow location access to detect your delivery address.',
        LocationErrorType.permissionDenied,
      );
    }

    return _fetchPositionWithNativeResolution(
      accuracy: accuracy,
      timeLimit: timeLimit,
    );
  }

  Future<Position> _fetchPositionWithNativeResolution({
    required LocationAccuracy accuracy,
    required Duration timeLimit,
  }) async {
    const maxRetries = 2;
    var retryCount = 0;

    while (retryCount <= maxRetries) {
      try {
        // Do not pre-check isLocationServiceEnabled — on Android this call
        // triggers the native "Turn on" / Location Accuracy system dialog.
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: accuracy,
          forceAndroidLocationManager: false,
          timeLimit: timeLimit,
        );
      } on LocationServiceDisabledException {
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          throw LocationException(
            'Location is turned off',
            'Turn on location to deliver fresh products to your doorstep, or search manually.',
            LocationErrorType.serviceDisabled,
            nativeResolutionAttempted: true,
          );
        }
        throw LocationException(
          'Location is turned off',
          'Enable location services to use current location, or search manually.',
          LocationErrorType.serviceDisabled,
          nativeResolutionAttempted: true,
        );
      } on PermissionDeniedException {
        throw LocationException(
          'Location permission needed',
          'Allow location access to detect your delivery address.',
          LocationErrorType.permissionDenied,
        );
      } on TimeoutException {
        retryCount++;
        if (retryCount > maxRetries) {
          throw LocationException(
            'Location timeout',
            'Unable to detect your location. Please try again or search manually.',
            LocationErrorType.timeout,
          );
        }
        await Future.delayed(Duration(seconds: retryCount));
      } catch (e) {
        if (e is LocationException) rethrow;
        retryCount++;
        if (retryCount > maxRetries) {
          final stillDisabled = !(await isLocationServiceEnabled());
          if (stillDisabled) {
            throw LocationException(
              'Location is turned off',
              'Turn on location to deliver fresh products to your doorstep, or search manually.',
              LocationErrorType.serviceDisabled,
              nativeResolutionAttempted: true,
            );
          }
          throw LocationException(
            'Location error',
            'Unable to detect your location. Please try again or search manually.',
            LocationErrorType.unknown,
          );
        }
      }
    }

    throw LocationException(
      'Location error',
      'Unable to detect your location. Please try again or search manually.',
      LocationErrorType.unknown,
    );
  }

  /// Get current location with better error handling and UX
  /// Returns Position if successful, null if failed
  /// Throws LocationException with user-friendly messages
  Future<Position?> getCurrentLocation({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeLimit = const Duration(seconds: 15),
    bool forceRequest = false,
  }) async {
    try {
      LocationPermission permission = await checkLocationPermission();

      if (permission == LocationPermission.denied) {
        if (forceRequest) {
          permission = await requestLocationPermission();
          if (permission == LocationPermission.denied) {
            throw LocationException(
              'Location permission denied',
              'We need location access to show your current location on the map. Please grant permission when prompted.',
              LocationErrorType.permissionDenied,
            );
          }
        } else {
          throw LocationException(
            'Location permission required',
            'Please grant location permission to use this feature.',
            LocationErrorType.permissionDenied,
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw LocationException(
          'Location permission permanently denied',
          'Location access is required for this feature. Please enable it in app settings.',
          LocationErrorType.permissionDeniedForever,
        );
      }

      return await _fetchPositionWithNativeResolution(
        accuracy: accuracy,
        timeLimit: timeLimit,
      );
    } on LocationException {
      rethrow;
    } catch (e) {
      debugPrint('Error getting current location: $e');
      throw LocationException(
        'Location error',
        'An unexpected error occurred while getting your location. Please try again.',
        LocationErrorType.unknown,
      );
    }
  }

  /// Get address from coordinates (Reverse Geocoding)
  Future<Map<String, dynamic>?> getAddressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        return {
          'place_name': place.name ?? place.locality ?? place.subLocality ?? '',
          'address_line1': _buildAddressLine1(place),
          'address_line2': _buildAddressLine2(place),
          'landmark': place.subLocality,
          'city': place.locality ?? place.subAdministrativeArea ?? '',
          'state': place.administrativeArea ?? '',
          'pincode': place.postalCode ?? '',
          'latitude': latitude,
          'longitude': longitude,
        };
      }
    } catch (e) {
      debugPrint('Device geocoding failed, trying Google Geocoding API: $e');
    }

    return _reverseGeocodeViaGoogle(latitude: latitude, longitude: longitude);
  }

  Future<Map<String, dynamic>?> _reverseGeocodeViaGoogle({
    required double latitude,
    required double longitude,
  }) async {
    final apiKey = EnvConfig.googleMapsApiKey;
    if (apiKey.isEmpty) return null;

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=$latitude,$longitude'
        '&key=$apiKey',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      final status = data['status'] as String?;
      if (status != 'OK') {
        debugPrint(
          'Geocoding API: $status — ${GoogleMapsSetup.hintForApiStatus(status, apiName: 'Geocoding API')}',
        );
        return null;
      }

      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      final result = results.first as Map<String, dynamic>;
      final components = (result['address_components'] as List<dynamic>?) ?? [];
      String? locality;
      String? state;
      String? pincode;
      String? subLocality;

      for (final raw in components) {
        final c = Map<String, dynamic>.from(raw as Map);
        final types = (c['types'] as List<dynamic>?)?.cast<String>() ?? [];
        final longName = c['long_name'] as String? ?? '';
        if (types.contains('locality')) locality = longName;
        if (types.contains('administrative_area_level_1')) state = longName;
        if (types.contains('postal_code')) pincode = longName;
        if (types.contains('sublocality') || types.contains('sublocality_level_1')) {
          subLocality = longName;
        }
      }

      return {
        'place_name': subLocality ?? locality ?? '',
        'address_line1': result['formatted_address'] as String? ?? '',
        'address_line2': '',
        'landmark': subLocality,
        'city': locality ?? 'Bokaro',
        'state': state ?? 'Jharkhand',
        'pincode': pincode ?? '',
        'latitude': latitude,
        'longitude': longitude,
      };
    } catch (e) {
      debugPrint('Google Geocoding API error: $e');
      return null;
    }
  }

  /// Get coordinates from address (Geocoding)
  Future<Map<String, double>?> getCoordinatesFromAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);

      if (locations.isEmpty) {
        return null;
      }

      Location location = locations.first;

      return {
        'latitude': location.latitude,
        'longitude': location.longitude,
      };
    } catch (e) {
      debugPrint('Error getting coordinates from address: $e');
      return null;
    }
  }

  /// Build address line 1 from placemark
  String _buildAddressLine1(Placemark place) {
    final parts = <String>[];
    
    if (place.street != null && place.street!.isNotEmpty) {
      parts.add(place.street!);
    }
    if (place.subThoroughfare != null && place.subThoroughfare!.isNotEmpty) {
      parts.insert(0, place.subThoroughfare!);
    }
    if (place.thoroughfare != null && place.thoroughfare!.isNotEmpty) {
      if (!parts.contains(place.thoroughfare!)) {
        parts.add(place.thoroughfare!);
      }
    }

    return parts.isNotEmpty ? parts.join(', ') : 'Address';
  }

  /// Build address line 2 from placemark
  String? _buildAddressLine2(Placemark place) {
    final parts = <String>[];
    
    if (place.subLocality != null && place.subLocality!.isNotEmpty) {
      parts.add(place.subLocality!);
    }
    if (place.locality != null && place.locality!.isNotEmpty) {
      if (!parts.contains(place.locality!)) {
        parts.add(place.locality!);
      }
    }

    return parts.isNotEmpty ? parts.join(', ') : null;
  }

  /// Calculate distance between two coordinates (in kilometers)
  double calculateDistance({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    ) / 1000; // Convert meters to kilometers
  }

  /// Calculate estimated time of arrival (ETA) in minutes
  /// Uses average speed based on travel mode
  /// 
  /// [travelMode] - 'driving', 'walking', 'bicycling' (default: 'driving')
  /// Returns ETA in minutes
  int calculateETA({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
    String travelMode = 'driving',
  }) {
    // Calculate distance in kilometers
    final distanceKm = calculateDistance(
      startLatitude: startLatitude,
      startLongitude: startLongitude,
      endLatitude: endLatitude,
      endLongitude: endLongitude,
    );

    // Average speeds in km/h based on travel mode
    double averageSpeed;
    switch (travelMode.toLowerCase()) {
      case 'walking':
        averageSpeed = 5.0; // 5 km/h walking speed
        break;
      case 'bicycling':
        averageSpeed = 15.0; // 15 km/h cycling speed
        break;
      case 'driving':
      default:
        averageSpeed = 40.0; // 40 km/h average city driving speed (accounts for traffic)
        break;
    }

    // Calculate time in hours, then convert to minutes
    final timeInHours = distanceKm / averageSpeed;
    final timeInMinutes = (timeInHours * 60).round();

    // Minimum 1 minute, add buffer for traffic/red lights
    return timeInMinutes < 1 ? 1 : timeInMinutes + 2; // Add 2 min buffer
  }

  /// Get formatted ETA string (e.g., "15 min", "1 hour 30 min")
  String getFormattedETA({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
    String travelMode = 'driving',
  }) {
    final etaMinutes = calculateETA(
      startLatitude: startLatitude,
      startLongitude: startLongitude,
      endLatitude: endLatitude,
      endLongitude: endLongitude,
      travelMode: travelMode,
    );

    if (etaMinutes < 60) {
      return '$etaMinutes min';
    } else {
      final hours = etaMinutes ~/ 60;
      final minutes = etaMinutes % 60;
      if (minutes == 0) {
        return '$hours ${hours == 1 ? 'hour' : 'hours'}';
      } else {
        return '$hours ${hours == 1 ? 'hour' : 'hours'} $minutes min';
      }
    }
  }

  /// Calculate route distance and ETA together
  /// Returns a map with distance (km) and eta (minutes)
  Map<String, dynamic> calculateRouteInfo({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
    String travelMode = 'driving',
  }) {
    final distanceKm = calculateDistance(
      startLatitude: startLatitude,
      startLongitude: startLongitude,
      endLatitude: endLatitude,
      endLongitude: endLongitude,
    );

    final etaMinutes = calculateETA(
      startLatitude: startLatitude,
      startLongitude: startLongitude,
      endLatitude: endLatitude,
      endLongitude: endLongitude,
      travelMode: travelMode,
    );

    return {
      'distance': distanceKm,
      'distanceFormatted': distanceKm < 1 
          ? '${(distanceKm * 1000).round()} m'
          : '${distanceKm.toStringAsFixed(1)} km',
      'eta': etaMinutes,
      'etaFormatted': getFormattedETA(
        startLatitude: startLatitude,
        startLongitude: startLongitude,
        endLatitude: endLatitude,
        endLongitude: endLongitude,
        travelMode: travelMode,
      ),
      'travelMode': travelMode,
    };
  }

  /// Shortest driving route via Google Directions API (real roads, live ETA).
  Future<DrivingRouteResult?> getDrivingRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    final apiKey = EnvConfig.googleMapsApiKey;
    if (apiKey.isEmpty) return null;

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=$originLat,$originLng'
        '&destination=$destLat,$destLng'
        '&mode=driving'
        '&alternatives=false'
        '&key=$apiKey',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      final status = data['status'] as String?;
      if (status != 'OK') {
        debugPrint(
          'Directions API: $status — '
          '${GoogleMapsSetup.hintForApiStatus(status, apiName: 'Directions API')}',
        );
        return null;
      }

      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;

      final route = routes.first as Map<String, dynamic>;
      final legs = route['legs'] as List<dynamic>?;
      if (legs == null || legs.isEmpty) return null;

      final leg = legs.first as Map<String, dynamic>;
      final distanceMeters =
          (leg['distance']?['value'] as num?)?.toDouble() ?? 0;
      final durationSeconds =
          (leg['duration']?['value'] as num?)?.toInt() ?? 0;

      final overview = route['overview_polyline']?['points'] as String?;
      if (overview == null || overview.isEmpty) return null;

      final decoded = _decodePolyline(overview);
      if (decoded.isEmpty) return null;

      final distanceKm = distanceMeters / 1000;
      final durationMinutes = (durationSeconds / 60).ceil().clamp(1, 999);

      return DrivingRouteResult(
        points: decoded,
        distanceKm: distanceKm,
        durationMinutes: durationMinutes,
        distanceFormatted: distanceKm < 1
            ? '${distanceMeters.round()} m'
            : '${distanceKm.toStringAsFixed(1)} km',
        durationFormatted: _formatDurationMinutes(durationMinutes),
      );
    } catch (e) {
      debugPrint('Directions API error: $e');
      return null;
    }
  }

  String _formatDurationMinutes(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rem = minutes % 60;
    if (rem == 0) return '$hours hr';
    return '$hours hr $rem min';
  }

  List<({double lat, double lng})> _decodePolyline(String encoded) {
    final points = <({double lat, double lng})>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    while (index < encoded.length) {
      var shift = 0;
      var result = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add((lat: lat / 1e5, lng: lng / 1e5));
    }

    return points;
  }

  /// Get nearby Points of Interest (POI) using Google Places API
  /// Returns list of POIs (buildings, landmarks, etc.) near the location
  Future<List<Map<String, dynamic>>> getNearbyPOIs({
    required double latitude,
    required double longitude,
    int radius = 500, // meters
    String type = 'establishment', // establishment, point_of_interest, etc.
  }) async {
    try {
      final apiKey = EnvConfig.googleMapsApiKey;
      if (apiKey.isEmpty) {
        debugPrint('⚠️ Google Maps API Key not found for Places API');
        return [];
      }

      // Google Places API Nearby Search endpoint
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
        '?location=$latitude,$longitude'
        '&radius=$radius'
        '&type=$type'
        '&key=$apiKey',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Places API request timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['results'] != null) {
          final List<dynamic> results = data['results'];
          return results.map((place) {
            final location = place['geometry']?['location'];
            return {
              'place_id': place['place_id'] as String? ?? '',
              'name': place['name'] as String? ?? '',
              'vicinity': place['vicinity'] as String? ?? '',
              'types': (place['types'] as List<dynamic>?)?.cast<String>() ?? [],
              'latitude': location?['lat'] as double? ?? latitude,
              'longitude': location?['lng'] as double? ?? longitude,
              'rating': (place['rating'] as num?)?.toDouble(),
              'icon': place['icon'] as String?,
            };
          }).toList();
        } else {
          debugPrint('⚠️ Places API error: ${data['status']}');
          return [];
        }
      } else {
        debugPrint('⚠️ Places API HTTP error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Error getting nearby POIs: $e');
      return [];
    }
  }

  /// Google Places Autocomplete — returns list of { place_id, description, secondary_text }.
  Future<List<Map<String, dynamic>>> searchPlacesAutocomplete(String query) async {
    final apiKey = EnvConfig.googleMapsApiKey;
    _clearPlacesError();

    if (apiKey.isEmpty || query.trim().length < 3) {
      if (apiKey.isEmpty) {
        lastPlacesError = 'Add GOOGLE_MAPS_API_KEY to .env and enable Places API';
      }
      return [];
    }

    try {
      final encoded = Uri.encodeComponent(query.trim());
      final biasLat = StoreConfig.storeLatitude;
      final biasLng = StoreConfig.storeLongitude;
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=$encoded'
        '&components=country:in'
        '&location=$biasLat,$biasLng'
        '&radius=15000'
        '&key=$apiKey',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        lastPlacesError = 'Location search failed. Check internet connection.';
        return [];
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final status = data['status'] as String?;
      if (status != 'OK' && status != 'ZERO_RESULTS') {
        _setPlacesError(status, apiName: 'Places API');
        return [];
      }

      final predictions = data['predictions'] as List<dynamic>? ?? [];
      return predictions.map((p) {
        final map = Map<String, dynamic>.from(p as Map);
        final structured = map['structured_formatting'] as Map?;
        return {
          'place_id': map['place_id'] as String? ?? '',
          'description': map['description'] as String? ?? '',
          'secondary_text': structured?['secondary_text'] as String? ?? '',
        };
      }).toList();
    } catch (e) {
      debugPrint('Places autocomplete error: $e');
      lastPlacesError = 'Location search unavailable. Try Pick on Map instead.';
      return [];
    }
  }

  /// Get place details by place_id (for better address resolution)
  Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    try {
      final apiKey = EnvConfig.googleMapsApiKey;
      if (apiKey.isEmpty) {
        return null;
      }

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId'
        '&fields=name,formatted_address,address_components,geometry,place_id,types'
        '&key=$apiKey',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['result'] != null) {
          final result = data['result'];
          final location = result['geometry']?['location'];
          
          return {
            'place_id': result['place_id'] as String? ?? '',
            'name': result['name'] as String? ?? '',
            'formatted_address': result['formatted_address'] as String? ?? '',
            'address_components': result['address_components'] as List<dynamic>? ?? [],
            'latitude': location?['lat'] as double? ?? 0.0,
            'longitude': location?['lng'] as double? ?? 0.0,
            'types': (result['types'] as List<dynamic>?)?.cast<String>() ?? [],
          };
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting place details: $e');
      return null;
    }
  }

  /// Enhanced address resolution with POI detection
  /// Returns address with POI name if available (Zomato style)
  Future<Map<String, dynamic>?> getAddressWithPOI({
    required double latitude,
    required double longitude,
  }) async {
    try {
      // First, try to get nearby POIs
      final nearbyPOIs = await getNearbyPOIs(
        latitude: latitude,
        longitude: longitude,
        radius: 100, // Small radius to find exact POI
      );

      // Get regular address
      final address = await getAddressFromCoordinates(
        latitude: latitude,
        longitude: longitude,
      );

      if (address == null) return null;

      // Check if any POI is very close (within 50m)
      Map<String, dynamic>? closestPOI;
      double minDistance = double.infinity;

      for (var poi in nearbyPOIs) {
        final poiLat = poi['latitude'] as double;
        final poiLng = poi['longitude'] as double;
        final distance = calculateDistance(
          startLatitude: latitude,
          startLongitude: longitude,
          endLatitude: poiLat,
          endLongitude: poiLng,
        ) * 1000; // Convert to meters

        if (distance < 50 && distance < minDistance) {
          minDistance = distance;
          closestPOI = poi;
        }
      }

      // If POI found, use it as primary identifier
      if (closestPOI != null) {
        final poiName = closestPOI['name'] as String? ?? '';
        return {
          ...address,
          'poi_name': poiName,
          'poi_place_id': closestPOI['place_id'] as String?,
          'display_name': poiName, // Primary display name (Zomato style)
          'full_address': _buildAddressString(address), // Full address for secondary display
        };
      }

      // No POI found, use regular address
      return {
        ...address,
        'display_name': address['place_name'] ?? address['address_line1'] ?? 'Address',
        'full_address': _buildAddressString(address),
      };
    } catch (e) {
      debugPrint('Error getting address with POI: $e');
      // Fallback to regular address
      return await getAddressFromCoordinates(
        latitude: latitude,
        longitude: longitude,
      );
    }
  }

  /// Opens Google Maps driving directions to a single destination.
  Future<void> launchNavigation(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Opens Google Maps with multi-stop driving directions.
  Future<void> launchMultiStopNavigation(List<LatLng> waypoints) async {
    if (waypoints.isEmpty) return;

    final origin = waypoints.first;
    final destination = waypoints.last;
    final middle = waypoints.sublist(1, waypoints.length - 1);

    final waypointsStr = middle
        .map((p) => '${p.latitude},${p.longitude}')
        .join('|');

    String url = 'https://www.google.com/maps/dir/?api=1'
        '&origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&travelmode=driving';

    if (waypointsStr.isNotEmpty) {
      url += '&waypoints=$waypointsStr';
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Google Static Maps URL showing all [points] (e.g. admin route thumbnail).
  String getStaticMapUrl(List<LatLng> points) {
    if (points.isEmpty) return '';

    final apiKey = EnvConfig.googleMapsApiKey;
    if (apiKey.isEmpty) return '';

    final visible = points
        .map((p) => '${p.latitude},${p.longitude}')
        .join('|');

    final markerParams = <String>[];
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      if (i == 0) {
        markerParams.add(
          'markers=color:green|label:S|${p.latitude},${p.longitude}',
        );
      } else {
        markerParams.add(
          'markers=color:red|label:$i|${p.latitude},${p.longitude}',
        );
      }
    }

    final params = [
      'size=400x200',
      'scale=2',
      'maptype=roadmap',
      'visible=$visible',
      ...markerParams,
      'key=$apiKey',
    ].join('&');

    return 'https://maps.googleapis.com/maps/api/staticmap?$params';
  }

  /// Build full address string from address map
  String _buildAddressString(Map<String, dynamic> address) {
    final parts = <String>[];
    
    if (address['address_line1'] != null) {
      parts.add(address['address_line1'] as String);
    }
    if (address['address_line2'] != null) {
      parts.add(address['address_line2'] as String);
    }
    if (address['city'] != null) {
      parts.add(address['city'] as String);
    }
    if (address['state'] != null) {
      parts.add(address['state'] as String);
    }
    if (address['pincode'] != null) {
      parts.add(address['pincode'] as String);
    }

    return parts.join(', ');
  }
}

/// Location Exception with user-friendly messages
class LocationException implements Exception {
  final String title;
  final String message;
  final LocationErrorType errorType;
  final bool nativeResolutionAttempted;

  LocationException(
    this.title,
    this.message,
    this.errorType, {
    this.nativeResolutionAttempted = false,
  });

  @override
  String toString() => message;
}

/// Location Error Types
enum LocationErrorType {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  unknown,
}

