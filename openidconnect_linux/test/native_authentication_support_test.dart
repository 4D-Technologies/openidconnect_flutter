import 'package:flutter_test/flutter_test.dart';
import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';
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

  test('times out loopback auth and maps it to user closed', () async {
    await expectLater(
      startNativeAuthenticationFlow(
        authorizationUrl: 'https://issuer.example.com/authorize',
        redirectUrl: 'http://localhost:0/callback.html',
        launchUrl: (_) async {},
        authenticationTimeout: const Duration(milliseconds: 1),
      ),
      throwsA(
        isA<AuthenticationException>().having(
          (exception) => exception.toString(),
          'error message',
          contains(ERROR_USER_CLOSED),
        ),
      ),
    );
  });
}
