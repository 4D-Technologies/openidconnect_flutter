import 'package:flutter_test/flutter_test.dart';
import 'package:openidconnect_linux/src/native_authentication_support.dart';

void main() {
  group('redirectDetailsForUrl', () {
    test('maps localhost redirects for Linux loopback auth', () {
      final redirect = redirectDetailsForUrl(
        'http://localhost:15503/callback.html',
      );

      expect(redirect.port, 15503);
      expect(redirect.path, '/callback.html');
    });

    test('rejects https redirects on Linux', () {
      expect(
        () => redirectDetailsForUrl('https://app.example.com/auth/callback'),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('rejects custom scheme redirects on Linux', () {
      expect(
        () => redirectDetailsForUrl('openidconnect.example://callback'),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('rejects non-localhost http redirects', () {
      expect(
        () => redirectDetailsForUrl('http://example.com/callback'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
