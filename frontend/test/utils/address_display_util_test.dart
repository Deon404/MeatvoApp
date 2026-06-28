import 'package:flutter_test/flutter_test.dart';

import '../../lib/utils/address_display_util.dart';

void main() {
  group('formatHyperlocalAddress', () {
    test('removes Bokaro and Jharkhand but keeps pincode', () {
      final result = formatHyperlocalAddress(
        addressLine1:
            'H7, Kamta Villa A/10 Banjara Co-operative Chira Chas Bokaro Pin Code - 827013',
        addressLine2: 'Chira Chas, 2 Bokaro Steel City',
        city: 'Bokaro Steel City',
        state: 'Jharkhand',
        pincode: '827015',
      );

      expect(result, contains('H7'));
      expect(result, contains('Chira Chas'));
      expect(result, contains('827015'));
      expect(result, isNot(contains('Jharkhand')));
      expect(result, isNot(contains('Bokaro Steel City')));
    });

    test('keeps colony, area names and pincode', () {
      final result = formatHyperlocalAddress(
        addressLine1: 't5, Saw Tola Lipta, Siwandih, 1 Bokaro Steel City',
        city: 'Bokaro Steel City',
        state: 'Jharkhand',
        pincode: '827010',
      );

      expect(result, 't5, Saw Tola Lipta, Siwandih, 827010');
    });

    test('includes useful locality from city when not redundant', () {
      final result = formatHyperlocalAddress(
        addressLine1: 'Flat 12',
        city: 'Sector 4',
        state: 'Jharkhand',
        pincode: '827004',
      );

      expect(result, 'Flat 12, Sector 4, 827004');
    });
  });

  group('formatAddressForDisplay', () {
    test('cleans pre-formatted order address strings and keeps pin', () {
      final result = formatAddressForDisplay(
        't5, Saw Tola Lipta, Siwandih, 1 Bokaro Steel City, Jharkhand, 827010',
      );

      expect(result, 't5, Saw Tola Lipta, Siwandih, 827010');
    });

    test('cleans rider delivery_address map with formatted field', () {
      final result = formatAddressForDisplay({
        'formatted':
            'H7, Kamta Villa, Chira Chas, Bokaro Steel City, Jharkhand, 827015',
        'city': 'Bokaro Steel City',
        'state': 'Jharkhand',
        'pincode': '827015',
      });

      expect(result, contains('Chira Chas'));
      expect(result, contains('827015'));
      expect(result, isNot(contains('Jharkhand')));
    });
  });
}
