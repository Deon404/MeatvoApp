import 'package:flutter_test/flutter_test.dart';

/// Test helpers and utilities
class TestHelpers {
  /// Create a test user ID
  static String get testUserId => 'test-user-id-123';

  /// Create a test phone number
  static String get testPhoneNumber => '9876543210';

  /// Test OTP — never hardcode production codes; override in CI:
  /// `flutter test --dart-define=TEST_OTP=xxxx`
  static String get testOTP =>
      const String.fromEnvironment('TEST_OTP', defaultValue: '0000');

  /// Create a test product ID
  static String get testProductId => 'test-product-id-123';

  /// Create a test variant ID
  static String get testVariantId => 'test-variant-id-123';

  /// Create a test order ID
  static String get testOrderId => 'test-order-id-123';

  /// Wait for async operations to complete
  static Future<void> waitForAsync() async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  /// Assert that an exception is thrown
  static void expectException(Function fn, String expectedMessage) {
    expect(
      () => fn(),
      throwsA(predicate((e) => e.toString().contains(expectedMessage))),
    );
  }
}

