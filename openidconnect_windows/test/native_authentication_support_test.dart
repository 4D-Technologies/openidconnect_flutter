import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';
import 'package:openidconnect_windows/src/native_authentication_support.dart';

Future<int> _reserveLoopbackPort() async {
  final server = await ServerSocket.bind('127.0.0.1', 0);
  final port = server.port;
  await server.close();
  return port;
}

void main() {
  group('redirectDetailsForUrl', () {
    test('maps localhost redirects for Windows WebView2 auth', () {
      final redirect = redirectDetailsForUrl(
        'http://localhost:15503/callback.html',
      );

      expect(redirect.kind, DesktopAuthenticationRedirectKind.localhost);
      expect(redirect.port, 15503);
      expect(redirect.path, '/callback.html');
    });

    test('maps https redirects for Windows WebView2 auth', () {
      final redirect = redirectDetailsForUrl(
        'https://app.example.com/auth/callback',
      );

      expect(redirect.kind, DesktopAuthenticationRedirectKind.https);
      expect(redirect.host, 'app.example.com');
      expect(redirect.path, '/auth/callback');
    });

    test('maps custom scheme redirects for Windows WebView2 auth', () {
      final redirect = redirectDetailsForUrl(
        'openidconnect.example://callback',
      );

      expect(redirect.kind, DesktopAuthenticationRedirectKind.custom);
      expect(redirect.scheme, 'openidconnect.example');
    });

    test('rejects non-localhost http redirects', () {
      expect(
        () => redirectDetailsForUrl('http://example.com/callback'),
        throwsA(isA<StateError>()),
      );
    });

    test('requires an explicit port on localhost redirects', () {
      expect(
        () => redirectDetailsForUrl('http://localhost/callback'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('callbackMatchesRedirect', () {
    test('accepts the callback query string on the configured redirect', () {
      expect(
        callbackMatchesRedirect(
          callbackUrl: 'openidconnect.example://callback?code=1234&state=abcd',
          redirectUrl: 'openidconnect.example://callback',
        ),
        isTrue,
      );
    });

    test('rejects a different callback path', () {
      expect(
        callbackMatchesRedirect(
          callbackUrl: 'https://app.example.com/other?code=1234',
          redirectUrl: 'https://app.example.com/auth/callback',
        ),
        isFalse,
      );
    });
  });

  group('startNativeAuthenticationFlow', () {
    test('uses the WebView2 secure session by default', () async {
      final result = await startNativeAuthenticationFlow(
        authorizationUrl: 'https://issuer.example.com/authorize',
        redirectUrl: 'openidconnect.example://callback',
        invokeSecureAuthentication: ({
          required authorizationUrl,
          required redirectUrl,
          popupWidth = 640,
          popupHeight = 600,
        }) async => 'openidconnect.example://callback?code=1234',
      );

      expect(result, 'openidconnect.example://callback?code=1234');
    });

    test('rejects an unexpected WebView2 callback URL', () async {
      await expectLater(
        startNativeAuthenticationFlow(
          authorizationUrl: 'https://issuer.example.com/authorize',
          redirectUrl: 'https://app.example.com/auth/callback',
          invokeSecureAuthentication: ({
            required authorizationUrl,
            required redirectUrl,
            popupWidth = 640,
            popupHeight = 600,
          }) async => 'https://evil.example.com/steal?code=1234',
        ),
        throwsA(isA<AuthenticationException>()),
      );
    });
  });

  test('times out loopback auth and maps it to user closed', () async {
    final port = await _reserveLoopbackPort();

    await expectLater(
      startLoopbackAuthenticationFlow(
        authorizationUrl: 'https://issuer.example.com/authorize',
        redirectUrl: 'http://localhost:$port/callback.html',
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
