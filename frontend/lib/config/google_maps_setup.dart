import 'package:flutter/foundation.dart';

import 'env_config.dart';

/// Google Maps Platform setup — Meatvo needs all four products on one API key.
abstract final class GoogleMapsSetup {
  static const requiredCloudApis = [
    'Maps SDK for Android',
    'Places API',
    'Geocoding API',
    'Directions API',
  ];

  /// Android package name (must match Google Cloud API key restriction).
  static const androidApplicationId = 'com.meatvo.app';

  // ── Customer-facing copy (shown in-app — no .env / API key / Gradle text) ──

  /// Order tracking screen when the live map cannot load.
  static const customerTrackingMapMessage =
      'Live map is temporarily unavailable.\n\n'
      'You can still track your order using the details below. '
      'Try refreshing or check your internet connection.';

  /// Address / location picker when the map cannot load.
  static const customerLocationMapMessage =
      'Map couldn\'t be loaded right now.\n\n'
      'Check your internet connection and try again, '
      'or search for your area manually.';

  static const customerMapUnavailableShort =
      'Map unavailable right now. Please try again.';

  /// True when a non-placeholder key is present in `.env`.
  static bool get hasConfiguredApiKey {
    final key = EnvConfig.googleMapsApiKey.trim();
    if (key.isEmpty || key.length < 20) return false;
    if (key.toLowerCase().contains('your-google-maps')) return false;
    if (key.toLowerCase().contains('your_api')) return false;
    return true;
  }

  /// How to print the signing certificate SHA-1 for Google Cloud API restrictions.
  static const androidSha1KeytoolHint =
      'keytool -list -v -keystore %USERPROFILE%\\.android\\debug.keystore '
      '-alias androiddebugkey -storepass android';

  /// Developer setup checklist — log only, never show to customers.
  static String get setupChecklist => '''
Google Maps setup for Meatvo (enable all on ONE key):
  1. Maps SDK for Android  → Pick on Map, delivery circle
  2. Places API            → Search Manually autocomplete
  3. Geocoding API         → Use Current Location → address text
  4. Directions API        → Order tracking road routes & ETA

Set GOOGLE_MAPS_API_KEY in frontend/.env, then sync to Flutter assets:
  dart run tool/sync_env.dart

Gradle also copies the key into AndroidManifest for native map tiles.

Google Cloud → Credentials → your key → Application restrictions:
  Package: $androidApplicationId
  SHA-1:   debug + release signing cert (run keytool on each keystore)

Debug SHA-1:
  $androidSha1KeytoolHint

Release APK: use your upload/release keystore with the same keytool command.

Then: flutter clean && flutter run
''';

  /// Developer diagnostic when map tiles time out — log only.
  static String devTilesLoadDiagnostic({String? applicationId}) {
    final pkg = applicationId ?? androidApplicationId;
    return 'Map tiles timeout. Check Google Cloud key restrictions for '
        'package=$pkg. Run: $androidSha1KeytoolHint. '
        'Then: dart run tool/sync_env.dart && flutter clean && flutter run';
  }

  /// Developer diagnostic when manifest key is missing — log only.
  static String devManifestKeyDiagnostic() =>
      'Dart has GOOGLE_MAPS_API_KEY but AndroidManifest key is empty. '
      'Run: dart run tool/sync_env.dart && flutter clean && flutter run';

  /// @deprecated Use [customerTrackingMapMessage] in UI; call [devTilesLoadDiagnostic] in logs.
  static String tilesLoadError({String? applicationId}) =>
      customerTrackingMapMessage;

  /// @deprecated Use [customerLocationMapMessage] in UI; call [devManifestKeyDiagnostic] in logs.
  static String manifestKeyMissingError() => customerLocationMapMessage;

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
      debugPrint('  API key: MISSING or placeholder — update .env + secrets.properties');
      debugPrint(setupChecklist);
    }
  }

  /// User-facing hint when a Google API returns an error status.
  static String hintForApiStatus(String? status, {required String apiName}) {
    switch (status) {
      case 'REQUEST_DENIED':
        return 'Location search is temporarily unavailable. Please try again.';
      case 'OVER_QUERY_LIMIT':
        return 'Too many requests. Please try again in a few minutes.';
      case 'INVALID_REQUEST':
        return 'We couldn\'t find that location. Try a different search.';
      default:
        return '';
    }
  }
}
