import 'package:flutter_test/flutter_test.dart';
import 'package:native_authentication/native_authentication.dart';
import 'package:openidconnect/src/native_authentication_support.dart';
import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';

void main() {
  group('callbackTypeForRedirectUrl', () {
    test('maps localhost redirects to CallbackTypeLocalhost', () {
      final callbackType = callbackTypeForRedirectUrl(
        'http://localhost:15503/callback.html',
      );

      expect(callbackType, isA<CallbackTypeLocalhost>());
      expect((callbackType as CallbackTypeLocalhost).port, 15503);
      expect(callbackType.path, '/callback.html');
    });

    test('maps https redirects to CallbackTypeHttps', () {
      final callbackType = callbackTypeForRedirectUrl(
        'https://app.example.com/auth/callback',
      );

      expect(callbackType, isA<CallbackTypeHttps>());
      expect((callbackType as CallbackTypeHttps).host, 'app.example.com');
      expect(callbackType.path, '/auth/callback');
    });

    test('maps custom scheme redirects to CallbackTypeCustom', () {
      final callbackType = callbackTypeForRedirectUrl(
        'openidconnect.example://callback',
      );

      expect(callbackType, isA<CallbackTypeCustom>());
      expect(
        (callbackType as CallbackTypeCustom).scheme,
        'openidconnect.example',
      );
      expect(callbackType.host, 'callback');
      expect(callbackType.path, '/*');
    });

    test('rejects non-localhost http redirects', () {
      expect(
        () => callbackTypeForRedirectUrl('http://example.com/callback'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('startNativeAuthenticationFlow', () {
    test('returns the final redirect url', () async {
      final result = await startNativeAuthenticationFlow(
        nativeAuthentication: _FakeNativeAuthentication(
          resultRedirectUri: Uri.parse(
            'openidconnect.example://callback?code=1234',
          ),
        ),
        authorizationUrl: 'https://issuer.example.com/authorize',
        redirectUrl: 'openidconnect.example://callback',
      );

      expect(result, 'openidconnect.example://callback?code=1234');
    });

    test('maps user cancellation to AuthenticationException', () async {
      await expectLater(
        () => startNativeAuthenticationFlow(
          nativeAuthentication: _FakeNativeAuthentication(
            redirectUriError: NativeAuthCanceledException(1),
          ),
          authorizationUrl: 'https://issuer.example.com/authorize',
          redirectUrl: 'openidconnect.example://callback',
        ),
        throwsA(isA<AuthenticationException>()),
      );
    });
  });
}

final class _FakeNativeAuthentication implements NativeAuthentication {
  _FakeNativeAuthentication({this.resultRedirectUri, this.redirectUriError});

  final Uri? resultRedirectUri;
  final Object? redirectUriError;

  @override
  CallbackSession startCallback({
    required Uri uri,
    required CallbackType type,
    bool preferEphemeralSession = false,
  }) {
    return _FakeCallbackSession(
      id: 1,
      resultRedirectUri: resultRedirectUri,
      redirectUriError: redirectUriError,
    );
  }
}

final class _FakeCallbackSession implements CallbackSession {
  _FakeCallbackSession({
    required this.id,
    this.resultRedirectUri,
    this.redirectUriError,
  });

  @override
  final int id;

  final Uri? resultRedirectUri;
  final Object? redirectUriError;

  @override
  Future<Uri> get redirectUri {
    if (redirectUriError != null) {
      return Future<Uri>.error(redirectUriError!);
    }

    return Future<Uri>.value(resultRedirectUri!);
  }

  @override
  void cancel() {}
}
