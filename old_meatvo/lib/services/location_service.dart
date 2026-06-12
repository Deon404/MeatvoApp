import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'maps_service.dart';

/// Location Service - Handles app startup location access (Swiggy/Instamart style)
/// Automatically requests location permission on app startup and stores location
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final MapsService _mapsService = MapsService();
  static const String _lastLocationLatKey = 'last_location_latitude';
  static const String _lastLocationLngKey = 'last_location_longitude';
  static const String _lastLocationAddressKey = 'last_location_address';
  static const String _lastLocationTimestampKey = 'last_location_timestamp';
  static const String _locationPermissionRequestedKey = 'location_permission_requested';

  /// Initialize location service on app startup
  /// This is called automatically when app starts (like Swiggy/Instamart)
  Future<void> initializeOnStartup() async {
    try {
      debugPrint('📍 LocationService: Initializing on app startup...');

      // Check if location services are enabled
      final isEnabled = await _mapsService.isLocationServiceEnabled();
      if (!isEnabled) {
        debugPrint('⚠️ LocationService: Location services are disabled');
        return;
      }

      // Check current permission status
      final hasPermission = await _mapsService.hasLocationPermission();
      
      if (!hasPermission) {
        // Check if we've already requested permission before
        final prefs = await SharedPreferences.getInstance();
        final alreadyRequested = prefs.getBool(_locationPermissionRequestedKey) ?? false;
        
        if (!alreadyRequested) {
          // First time - request permission silently (will show system dialog)
          debugPrint('📍 LocationService: Requesting location permission...');
          final permission = await _mapsService.requestLocationPermission();
          
          // Mark that we've requested permission
          await prefs.setBool(_locationPermissionRequestedKey, true);
          
          if (permission == LocationPermission.denied || 
              permission == LocationPermission.deniedForever) {
            debugPrint('⚠️ LocationService: Permission denied by user');
            return;
          }
        } else {
          // Already requested before, don't ask again
          debugPrint('⚠️ LocationService: Permission was previously denied');
          return;
        }
      }

      // Permission granted - get current location
      await _updateCurrentLocation();
    } catch (e) {
      debugPrint('❌ LocationService: Error initializing: $e');
    }
  }

  /// Update current location and store it
  Future<void> _updateCurrentLocation() async {
    try {
      debugPrint('📍 LocationService: Getting current location...');
      
      final position = await _mapsService.getCurrentLocation(
        forceRequest: false,
        timeLimit: const Duration(seconds: 10),
      );

      if (position != null) {
        // Get address for location
        final address = await _mapsService.getAddressFromCoordinates(
          latitude: position.latitude,
          longitude: position.longitude,
        );

        // Store location and address
        await _storeLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          address: address,
        );

        debugPrint('✅ LocationService: Location updated successfully');
      }
    } catch (e) {
      debugPrint('⚠️ LocationService: Could not get current location: $e');
    }
  }

  /// Store location in SharedPreferences
  Future<void> _storeLocation({
    required double latitude,
    required double longitude,
    Map<String, dynamic>? address,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_lastLocationLatKey, latitude);
      await prefs.setDouble(_lastLocationLngKey, longitude);
      await prefs.setString(_lastLocationTimestampKey, DateTime.now().toIso8601String());
      
      if (address != null) {
        // Store address as JSON string
        final addressJson = jsonEncode(address);
        await prefs.setString(_lastLocationAddressKey, addressJson);
      }
    } catch (e) {
      debugPrint('❌ LocationService: Error storing location: $e');
    }
  }

  /// Get last stored location
  Future<Map<String, dynamic>?> getLastLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(_lastLocationLatKey);
      final lng = prefs.getDouble(_lastLocationLngKey);
      final timestampStr = prefs.getString(_lastLocationTimestampKey);
      final addressStr = prefs.getString(_lastLocationAddressKey);

      if (lat != null && lng != null) {
        Map<String, dynamic>? addressMap;
        if (addressStr != null && addressStr.isNotEmpty) {
          try {
            addressMap = jsonDecode(addressStr) as Map<String, dynamic>;
          } catch (e) {
            debugPrint('Error parsing stored address: $e');
          }
        }
        
        return {
          'latitude': lat,
          'longitude': lng,
          'timestamp': timestampStr,
          'address': addressMap,
        };
      }
      return null;
    } catch (e) {
      debugPrint('❌ LocationService: Error getting last location: $e');
      return null;
    }
  }

  /// Check if location is recent (within last 1 hour)
  Future<bool> hasRecentLocation() async {
    try {
      final location = await getLastLocation();
      if (location == null || location['timestamp'] == null) {
        return false;
      }

      final timestampStr = location['timestamp'] as String;
      final timestamp = DateTime.parse(timestampStr);
      final now = DateTime.now();
      final difference = now.difference(timestamp);

      // Consider location recent if less than 1 hour old
      return difference.inHours < 1;
    } catch (e) {
      return false;
    }
  }

  /// Manually refresh location (called when user taps "Use Current Location")
  Future<Map<String, dynamic>?> refreshLocation() async {
    try {
      final hasPermission = await _mapsService.hasLocationPermission();
      if (!hasPermission) {
        // Request permission if not granted
        final permission = await _mapsService.requestLocationPermission();
        if (permission == LocationPermission.denied || 
            permission == LocationPermission.deniedForever) {
          return null;
        }
      }

      await _updateCurrentLocation();
      return await getLastLocation();
    } catch (e) {
      debugPrint('❌ LocationService: Error refreshing location: $e');
      return null;
    }
  }

  /// Clear stored location
  Future<void> clearStoredLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastLocationLatKey);
      await prefs.remove(_lastLocationLngKey);
      await prefs.remove(_lastLocationAddressKey);
      await prefs.remove(_lastLocationTimestampKey);
    } catch (e) {
      debugPrint('❌ LocationService: Error clearing location: $e');
    }
  }
}

