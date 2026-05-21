import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openidconnect_android/src/native_authentication_support.dart';
import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';

void main() {
  group('redirectDetailsForUrl', () {
    test('rejects localhost redirects on Android', () {
      expect(
        () => redirectDetailsForUrl('http://localhost:15503/callback.html'),
        throwsA(
          isA<UnsupportedError>().having(
            (error) => error.message,
            'message',
            contains('custom-scheme and HTTPS redirect URLs'),
          ),
        ),
      );
    });

    test('maps https redirects', () {
      final redirect = redirectDetailsForUrl(
        'https://app.example.com/auth/callback',
      );

      expect(redirect.kind, AndroidAuthenticationRedirectKind.https);
      expect(redirect.host, 'app.example.com');
      expect(redirect.path, '/auth/callback');
    });

    test('maps custom scheme redirects', () {
      final redirect = redirectDetailsForUrl(
        'openidconnect.example://callback',
      );

      expect(redirect.kind, AndroidAuthenticationRedirectKind.custom);
      expect(redirect.scheme, 'openidconnect.example');
      expect(redirect.host, 'callback');
      expect(redirect.path, '/*');
    });

    test('rejects non-localhost http redirects', () {
      expect(
        () => redirectDetailsForUrl('http://example.com/callback'),
        throwsA(
          isA<UnsupportedError>().having(
            (error) => error.message,
            'message',
            contains('custom-scheme and HTTPS redirect URLs'),
          ),
        ),
      );
    });
  });

  group('startNativeAuthenticationFlow', () {
    test('returns the final redirect url', () async {
      final result = await startNativeAuthenticationFlow(
        authorizationUrl: 'https://issuer.example.com/authorize',
        redirectUrl: 'openidconnect.example://callback',
        invokeNativeAuthentication:
            ({
              required authorizationUrl,
              required redirectUrl,
              preferEphemeralSession = false,
            }) async => 'openidconnect.example://callback?code=1234',
      );

      expect(result, 'openidconnect.example://callback?code=1234');
    });

    test('maps user cancellation to AuthenticationException', () async {
      await expectLater(
        () => startNativeAuthenticationFlow(
          authorizationUrl: 'https://issuer.example.com/authorize',
          redirectUrl: 'openidconnect.example://callback',
          invokeNativeAuthentication:
              ({
                required authorizationUrl,
                required redirectUrl,
                preferEphemeralSession = false,
              }) => Future<String?>.error(
                PlatformException(code: 'user_cancelled'),
              ),
        ),
        throwsA(isA<AuthenticationException>()),
      );
    });
  });
}
