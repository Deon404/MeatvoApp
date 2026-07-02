import 'package:flutter_test/flutter_test.dart';

import '../../lib/utils/address_input_validator.dart';

void main() {
  group('AddressInputValidator', () {
    test('accepts real house numbers', () {
      expect(AddressInputValidator.validateHouseNumber('36'), isNull);
      expect(AddressInputValidator.validateHouseNumber('Flat 302'), isNull);
      expect(AddressInputValidator.validateHouseNumber('H.No. 12A'), isNull);
      expect(AddressInputValidator.validateHouseNumber('H7'), isNull);
      expect(AddressInputValidator.validateHouseNumber('Rose Villa'), isNull);
    });

    test('rejects gibberish house numbers', () {
      expect(
        AddressInputValidator.validateHouseNumber('hdbsbeb'),
        isNotNull,
      );
      expect(
        AddressInputValidator.validateHouseNumber('wueh'),
        isNotNull,
      );
    });

    test('returns customer-friendly validation messages', () {
      expect(
        AddressInputValidator.validateFloor('@@'),
        "Use only letters, numbers, spaces, and common symbols like - / # . , ( ) ' &",
      );
      expect(
        AddressInputValidator.validateTowerBlock('A' * 41),
        'Tower or block details are too long. Please keep them under 40 characters.',
      );
      expect(
        AddressInputValidator.validateLandmark('ab'),
        'Please enter a clearer nearby landmark.',
      );
    });

    test('rejects gibberish optional fields when filled', () {
      expect(AddressInputValidator.validateFloor('wueh'), isNotNull);
      expect(AddressInputValidator.validateTowerBlock('hdbsbeb'), isNotNull);
      expect(
        AddressInputValidator.validateLandmark('hshdudiwiv'),
        isNotNull,
      );
    });

    test('accepts valid optional fields', () {
      expect(AddressInputValidator.validateFloor('2'), isNull);
      expect(AddressInputValidator.validateFloor('G'), isNull);
      expect(AddressInputValidator.validateTowerBlock('Tower A'), isNull);
      expect(
        AddressInputValidator.validateLandmark('Near City Park'),
        isNull,
      );
    });
  });
}
