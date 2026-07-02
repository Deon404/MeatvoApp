import 'package:flutter_test/flutter_test.dart';

import '../../lib/utils/media_url_resolver.dart';

void main() {
  test('cacheKey strips rotating signature from managed upload URLs', () {
    const signedUrl =
        'https://meatvo.com/uploads/images/chicken.jpg?exp=1234567890&sig=abc123';
    final cacheKey = MediaUrlResolver.cacheKey(signedUrl);

    expect(cacheKey, isNotNull);
    expect(cacheKey, isNot(contains('?')));
    expect(cacheKey, endsWith('/uploads/images/chicken.jpg'));
  });

  test('cacheKey keeps external CDN URLs untouched', () {
    const cdnUrl =
        'https://images.examplecdn.com/item.webp?auto=format&fit=crop&w=800';

    expect(MediaUrlResolver.cacheKey(cdnUrl), cdnUrl);
  });
}
