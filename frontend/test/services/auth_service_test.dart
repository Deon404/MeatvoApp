import 'package:flutter_test/flutter_test.dart';
import 'package:meatvo_official/utils/phone_util.dart';

/// Auth-related unit tests (Node.js backend + E.164).
/// OTP network calls are covered by integration / manual tests.
void main() {
  group('Auth phone (E.164)', () {
    test('matches backend validator for typical inputs', () {
      expect(toE164India('9876543210'), '+919876543210');
      expect(toE164India('+919876543210'), '+919876543210');
      expect(RegExp(r'^\+[1-9]\d{1,14}$').hasMatch(toE164India('9876543210')), isTrue);
    });
  });
}
