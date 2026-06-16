import 'package:meatvo_official/config/google_maps_setup.dart';
import 'package:meatvo_official/config/store_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GoogleMapsSetup', () {
    test('lists all three required Google Cloud APIs', () {
      expect(GoogleMapsSetup.requiredCloudApis, hasLength(3));
      expect(GoogleMapsSetup.requiredCloudApis, contains('Maps SDK for Android'));
      expect(GoogleMapsSetup.requiredCloudApis, contains('Places API'));
      expect(GoogleMapsSetup.requiredCloudApis, contains('Geocoding API'));
    });

    test('hintForApiStatus returns enable message for REQUEST_DENIED', () {
      final hint = GoogleMapsSetup.hintForApiStatus(
        'REQUEST_DENIED',
        apiName: 'Places API',
      );
      expect(hint, contains('Places API'));
      expect(hint, contains('Google Cloud'));
    });
  });

  group('StoreConfig Chira Chas delivery zone', () {
    test('store center is within its own delivery radius', () {
      expect(
        StoreConfig.isWithinDeliveryRadius(
          StoreConfig.storeLatitude,
          StoreConfig.storeLongitude,
        ),
        isTrue,
      );
      expect(
        StoreConfig.getDistanceFromStore(
          StoreConfig.storeLatitude,
          StoreConfig.storeLongitude,
        ),
        lessThan(0.01),
      );
    });
  });
}
