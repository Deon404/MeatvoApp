import 'package:flutter/foundation.dart';

import 'env_config.dart';

/// Google Maps Platform setup — Meatvo needs all three products on one API key.
abstract final class GoogleMapsSetup {
  static const requiredCloudApis = [
    'Maps SDK for Android',
    'Places API',
    'Geocoding API',
    'Directions API',
  ];

  /// True when a non-placeholder key is present in `.env`.
  static bool get hasConfiguredApiKey {
    final key = EnvConfig.googleMapsApiKey.trim();
    if (key.isEmpty || key.length < 20) return false;
    if (key.toLowerCase().contains('your-google-maps')) return false;
    if (key.toLowerCase().contains('your_api')) return false;
    return true;
  }

  /// Android package name (must match Google Cloud API key restriction).
  static const androidApplicationId = 'com.meatvo.app';

  /// Debug keystore SHA-1 (`keytool -list -v -keystore ~/.android/debug.keystore`).
  static const androidDebugSha1 =
      '00:C1:5A:95:9B:BE:B0:45:2E:38:C3:0C:45:B1:72:B1:EE:18:44:87';

  static String get setupChecklist => '''
Google Maps setup for Meatvo (enable all on ONE key):
  1. Maps SDK for Android  → Pick on Map, delivery circle
  2. Places API            → Search Manually autocomplete
  3. Geocoding API         → Use Current Location → address text
  4. Directions API        → Order tracking road routes & ETA

Set GOOGLE_MAPS_API_KEY in old_meatvo/.env (Gradle copies it into AndroidManifest on build).

Google Cloud → Credentials → your key → Application restrictions:
  Package: $androidApplicationId
  SHA-1:   $androidDebugSha1

Then: flutter clean && flutter run
''';

  static String tilesLoadError({String? applicationId}) {
    final pkg = applicationId ?? androidApplicationId;
    return 'Map tiles are taking too long to load.\n\n'
        'Please check:\n'
        '1. Internet connection\n'
        '2. GOOGLE_MAPS_API_KEY in old_meatvo/.env (then flutter clean && run)\n'
        '3. Maps SDK for Android is enabled in Google Cloud Console\n'
        '4. API key is restricted to this app:\n'
        '   Package: $pkg\n'
        '   SHA-1: $androidDebugSha1';
  }

  static String manifestKeyMissingError() =>
      'Google Maps API key is in .env but NOT in the Android app.\n\n'
      'The native map reads the key from AndroidManifest at build time.\n'
      'Add GOOGLE_MAPS_API_KEY to old_meatvo/.env and run:\n'
      '  flutter clean\n'
      '  flutter run\n\n'
      'Optional: copy the same key to android/gradle.properties.';

  static void logDebugStatus() {
    if (!kDebugMode) return;

    debugPrint('── Google Maps Platform ──');
    for (final api in requiredCloudApis) {
      debugPrint('  Required: $api');
    }

    if (hasConfiguredApiKey) {
      final key = EnvConfig.googleMapsApiKey;
      final previewLength = key.length < 8 ? key.length : 8;
      debugPrint('  API key: configured (${key.substring(0, previewLength)}...)');
    } else {
      debugPrint('  API key: MISSING or placeholder — update .env + gradle.properties');
      debugPrint(setupChecklist);
    }
  }

  /// User-facing hint when a Google API returns REQUEST_DENIED.
  static String hintForApiStatus(String? status, {required String apiName}) {
    switch (status) {
      case 'REQUEST_DENIED':
        return 'Enable $apiName in Google Cloud Console and add the key to .env';
      case 'OVER_QUERY_LIMIT':
        return 'Google Maps quota exceeded. Try again later.';
      case 'INVALID_REQUEST':
        return 'Invalid location request. Try a different search.';
      default:
        return '';
    }
  }
}
