import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native Android Maps SDK config (API key is injected via AndroidManifest).
class MapsNativeConfig {
  const MapsNativeConfig({
    required this.applicationId,
    required this.mapsApiKeyConfigured,
    required this.mapsApiKeyLength,
  });

  final String applicationId;
  final bool mapsApiKeyConfigured;
  final int mapsApiKeyLength;

  bool get isReady => mapsApiKeyConfigured && mapsApiKeyLength >= 20;
}

/// Reads package name + manifest Maps API key status from Android.
class MapsPlatformConfig {
  static const _channel = MethodChannel('com.meatvo.meatvo/maps_config');

  static Future<MapsNativeConfig?> getNativeConfig() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    try {
      final result = await _channel.invokeMethod<Object?>('getMapsConfig');
      if (result is! Map) return null;
      final map = Map<Object?, Object?>.from(result);
      return MapsNativeConfig(
        applicationId: map['applicationId']?.toString() ?? '',
        mapsApiKeyConfigured: map['mapsApiKeyConfigured'] == true,
        mapsApiKeyLength: (map['mapsApiKeyLength'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      debugPrint('MapsPlatformConfig: $e');
      return null;
    }
  }
}
