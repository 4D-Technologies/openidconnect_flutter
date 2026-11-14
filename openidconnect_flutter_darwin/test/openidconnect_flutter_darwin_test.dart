import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openidconnect_flutter_darwin/openidconnect_flutter_darwin.dart';
import 'package:openidconnect_flutter_darwin/src/native_authentication_support.dart';
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

  group('runMacOSLoopbackAuthenticationFlow', () {
    test('requires an explicit port', () async {
      for (final url in [
        'http://localhost/callback',
        'http://localhost:0/cb',
      ]) {
        await expectLater(
          runMacOSLoopbackAuthenticationFlow(
            redirectUri: Uri.parse(url),
            authorizationUrl: 'https://issuer.example.com/authorize',
            launchUrl: (_) async {},
          ),
          throwsA(isA<StateError>()),
        );
      }
    });

    test('times out as user closed and releases the port', () async {
      final probe = await ServerSocket.bind('127.0.0.1', 0);
      final port = probe.port;
      await probe.close();

      await expectLater(
        runMacOSLoopbackAuthenticationFlow(
          redirectUri: Uri.parse('http://localhost:$port/callback'),
          authorizationUrl: 'https://issuer.example.com/authorize',
          launchUrl: (_) async {},
          authenticationTimeout: const Duration(milliseconds: 50),
        ),
        throwsA(
          isA<AuthenticationException>().having(
            (e) => e.toString(),
            'text',
            contains(ERROR_USER_CLOSED),
          ),
        ),
      );

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      await server.close();
    });

    test('returns the redirect delivered to the loopback port', () async {
      final probe = await ServerSocket.bind('127.0.0.1', 0);
      final port = probe.port;
      await probe.close();

      final result = await runMacOSLoopbackAuthenticationFlow(
        redirectUri: Uri.parse('http://localhost:$port/callback'),
        authorizationUrl: 'https://issuer.example.com/authorize',
        launchUrl: (_) async {
          final client = HttpClient();
          final request = await client.getUrl(
            Uri.parse('http://127.0.0.1:$port/callback?code=abc'),
          );
          final response = await request.close();
          await response.drain<void>();
          client.close();
        },
        authenticationTimeout: const Duration(seconds: 10),
      );

      expect(result, 'http://127.0.0.1:$port/callback?code=abc');
    });
  });

  group('startNativeAuthenticationFlow', () {
    test(
      'uses ASWebAuthenticationSession for custom schemes on iOS and macOS',
      () async {
        var usedAppleSession = false;
        var usedMacOSLoopback = false;

        final result = await startNativeAuthenticationFlow(
          authorizationUrl: 'https://issuer.example.com/authorize',
          redirectUrl: 'openidconnect.example://callback',
          invokeNativeAuthentication:
              ({
                required authorizationUrl,
                required redirectUrl,
                preferEphemeralSession = false,
              }) async {
                usedAppleSession = true;
                return 'openidconnect.example://callback?code=1234';
              },
          runMacOSLoopbackAuthentication:
              ({required redirectUri, required authorizationUrl}) async {
                usedMacOSLoopback = true;
                return 'http://localhost/unused';
              },
        );

        expect(result, 'openidconnect.example://callback?code=1234');
        expect(usedAppleSession, isTrue);
        expect(usedMacOSLoopback, isFalse);
      },
    );

    test(
      'uses ASWebAuthenticationSession for HTTPS callbacks on iOS and macOS',
      () async {
        var usedAppleSession = false;

        final result = await startNativeAuthenticationFlow(
          authorizationUrl: 'https://issuer.example.com/authorize',
          redirectUrl: 'https://app.example.com/auth/callback',
          invokeNativeAuthentication:
              ({
                required authorizationUrl,
                required redirectUrl,
                preferEphemeralSession = false,
              }) async {
                usedAppleSession = true;
                return 'https://app.example.com/auth/callback?code=1234';
              },
          runMacOSLoopbackAuthentication:
              ({required redirectUri, required authorizationUrl}) async {
                fail('macOS loopback must not handle HTTPS callbacks');
              },
        );

        expect(result, 'https://app.example.com/auth/callback?code=1234');
        expect(usedAppleSession, isTrue);
      },
    );

    test('uses loopback only for macOS http://localhost callbacks', () async {
      var usedAppleSession = false;
      var usedMacOSLoopback = false;

      final result = await startNativeAuthenticationFlow(
        authorizationUrl: 'https://issuer.example.com/authorize',
        redirectUrl: 'http://localhost:15503/callback.html',
        invokeNativeAuthentication:
            ({
              required authorizationUrl,
              required redirectUrl,
              preferEphemeralSession = false,
            }) async {
              usedAppleSession = true;
              return 'openidconnect.example://session';
            },
        runMacOSLoopbackAuthentication:
            ({required redirectUri, required authorizationUrl}) async {
              usedMacOSLoopback = true;
              return 'http://localhost:15503/callback.html?code=loopback';
            },
      );

      if (Platform.isMacOS) {
        expect(result, 'http://localhost:15503/callback.html?code=loopback');
        expect(usedMacOSLoopback, isTrue);
        expect(usedAppleSession, isFalse);
      } else {
        expect(result, 'openidconnect.example://session');
        expect(usedAppleSession, isTrue);
        expect(usedMacOSLoopback, isFalse);
      }
    });
  });
}
