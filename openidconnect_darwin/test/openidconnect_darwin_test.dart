import 'package:flutter_test/flutter_test.dart';
import 'package:openidconnect_darwin/openidconnect_darwin.dart';
import 'package:openidconnect_darwin/src/native_authentication_support.dart';
import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';

void main() {
  test('registers Darwin implementation', () {
    OpenIdConnectDarwin.registerWith();

    expect(OpenIdConnectPlatform.instance, isA<OpenIdConnectDarwin>());
  });

  group('redirectDetailsForUrl', () {
    test('maps localhost redirects for macOS loopback auth', () {
      final redirect = redirectDetailsForUrl(
        'http://localhost:15503/callback.html',
      );

      expect(redirect.kind, DarwinAuthenticationRedirectKind.localhost);
      expect(redirect.port, 15503);
      expect(redirect.path, '/callback.html');
    });

    test('maps https redirects to HTTPS callback handling', () {
      final redirect = redirectDetailsForUrl(
        'https://app.example.com/auth/callback',
      );

      expect(redirect.kind, DarwinAuthenticationRedirectKind.https);
      expect(redirect.host, 'app.example.com');
      expect(redirect.path, '/auth/callback');
    });

    test('maps custom scheme redirects to custom callback handling', () {
      final redirect = redirectDetailsForUrl(
        'openidconnect.example://callback',
      );

      expect(redirect.kind, DarwinAuthenticationRedirectKind.custom);
      expect(redirect.scheme, 'openidconnect.example');
      expect(redirect.host, 'callback');
      expect(redirect.path, '/*');
    });

    test('rejects non-localhost http redirects', () {
      expect(
        () => redirectDetailsForUrl('http://example.com/callback'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
