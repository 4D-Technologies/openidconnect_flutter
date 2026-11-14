// Live end-to-end proof of the Windows WebView2 secure interactive login
// against the public Duende IdentityServer demo.
//
// Run (see README): the sign-in window is automated by
// windows_webview2_driver.mjs over the WebView2 DevTools port.
//
//   $env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS = '--remote-debugging-port=9222'
//   $env:OIDC_E2E_DRIVER = '1'
//   Start-Process node -WindowStyle Hidden -ArgumentList 'integration_test/windows_webview2_driver.mjs','9222','login,cancel,login,login,cancel,cancel,cancel,cancel,cancel'
//   flutter test integration_test/windows_webview2_login_test.dart -d windows
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openidconnect/openidconnect.dart';
import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';

const _discoveryUrl =
    'https://demo.duendesoftware.com/.well-known/openid-configuration';
const _redirectUrl = 'http://localhost:15503/callback.html';

Future<OpenIdConnectClient> _client() => OpenIdConnectClient.create(
  discoveryDocumentUrl: _discoveryUrl,
  clientId: 'interactive.public',
  redirectUrl: _redirectUrl,
  encryptionKey: 'example123456789',
  scopes: const ['openid', 'profile', 'email', 'offline_access'],
  autoRefresh: false,
);

/// Always forces re-authentication: WebView2 keeps its profile between logins,
/// so without `prompt=login` a retained provider session could complete a
/// "cancel" or "concurrent" step before the driver acts.
Future<OpenIdIdentity> _login(
  OpenIdConnectClient client,
  BuildContext context,
) => client.loginInteractive(
  context: context,
  title: 'Login',
  prompts: const ['login'],
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final skip =
      Platform.isWindows &&
          (Platform.environment['OIDC_E2E_DRIVER'] ?? '').isNotEmpty
      ? false
      : 'Set OIDC_E2E_DRIVER and run the WebView2 driver (see file header).';

  Future<BuildContext> pumpContext(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    return context;
  }

  testWidgets('WebView2 secure login: success, cancel, rapid re-login, '
      'concurrent request', (tester) async {
    HttpOverrides.global = null;
    final context = await pumpContext(tester);

    // 1. Happy path: real window, real IdP, tokens returned.
    final client = await _client();
    final identity = await tester.runAsync(() => _login(client, context));
    expect(identity!.accessToken, isNotEmpty);
    expect(identity.idToken, isNotEmpty);
    expect(identity.refreshToken, isNotNull);
    expect(identity.sub, isNotEmpty);
    // ignore: avoid_print
    print(
      'E2E 1 login ok: sub=${identity.sub} '
      'refresh=${identity.refreshToken != null}',
    );

    // 2. Closing the window maps to user_closed.
    final cancelError = await tester.runAsync<Object?>(() async {
      try {
        await _login(await _client(), context);
        return null;
      } catch (e) {
        return e;
      }
    });
    expect(cancelError, isA<AuthenticationException>());
    expect(cancelError.toString(), contains(ERROR_USER_CLOSED));
    // ignore: avoid_print
    print('E2E 2 cancel ok');

    // 3. Immediately starting another login after the cancel must work
    //    (native session must be fully released).
    final again = await tester.runAsync(
      () => (_client()).then((c) => _login(c, context)),
    );
    expect(again!.accessToken, isNotEmpty);
    // ignore: avoid_print
    print('E2E 3 rapid re-login ok');

    // 4. A second request while one window is open is rejected; the first
    //    still completes.
    final result = await tester.runAsync(() async {
      final a = _login(await _client(), context);
      await Future<void>.delayed(const Duration(seconds: 3));
      Object? concurrentError;
      try {
        await _login(await _client(), context);
      } catch (e) {
        concurrentError = e;
      }
      return (await a, concurrentError);
    });
    expect(result!.$1.accessToken, isNotEmpty);
    expect(result.$2.toString(), contains('already in progress'));
    // ignore: avoid_print
    print('E2E 4 concurrent rejected, first completed');
  }, skip: skip != false);

  testWidgets('WebView2 window can be cancelled and restarted back-to-back', (
    tester,
  ) async {
    final context = await pumpContext(tester);
    final platform = OpenIdConnectPlatform.instance;

    // No network between sessions: the native session must be released as
    // soon as the completion fires, not when the window thread finally exits.
    final errors = await tester.runAsync(() async {
      final errors = <String>[];
      for (var i = 0; i < 5; i++) {
        try {
          await platform.authorizeInteractive(
            context: context,
            title: 'Login',
            authorizationUrl: 'https://demo.duendesoftware.com/',
            redirectUrl: _redirectUrl,
            popupWidth: 640,
            popupHeight: 600,
          );
          errors.add('unexpected success');
        } catch (e) {
          errors.add(e.toString());
        }
      }
      return errors;
    });
    // ignore: avoid_print
    print('E2E 5 back-to-back results: $errors');
    expect(errors, everyElement(contains(ERROR_USER_CLOSED)));

    // Closing the last native window hands focus back to the Flutter window
    // asynchronously; let that land before the binding is torn down.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );
    await tester.pump();
  }, skip: skip != false);
}
