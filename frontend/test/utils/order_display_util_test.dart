import 'package:flutter_test/flutter_test.dart';
import 'package:meatvo_official/utils/order_display_util.dart';

void main() {
  group('formatOrderDisplayId', () {
    test('returns N/A for empty id', () {
      expect(formatOrderDisplayId(''), 'N/A');
    });

    test('uppercases short numeric ids without throwing', () {
      expect(formatOrderDisplayId('3'), '3');
      expect(formatOrderDisplayId('2'), '2');
    });

    test('returns last 8 chars for long ids', () {
      expect(
        formatOrderDisplayId('order-1234567890'),
        '34567890',
      );
    });
  });
}
