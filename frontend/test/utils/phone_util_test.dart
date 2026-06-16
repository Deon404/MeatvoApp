import 'package:flutter_test/flutter_test.dart';
import 'package:meatvo_official/utils/phone_util.dart';

void main() {
  group('toE164India', () {
    test('10-digit local gets +91 prefix', () {
      expect(toE164India('9876543210'), '+919876543210');
    });

    test('already E.164 unchanged', () {
      expect(toE164India('+919876543210'), '+919876543210');
    });

    test('91 prefix without plus gets plus', () {
      expect(toE164India('919876543210'), '+919876543210');
    });

    test('strips spaces and formatting', () {
      expect(toE164India('98765 43210'), '+919876543210');
      expect(toE164India('+91 98765 43210'), '+919876543210');
    });

    test('0-prefixed 11-digit local', () {
      expect(toE164India('09876543210'), '+919876543210');
    });
  });
}
