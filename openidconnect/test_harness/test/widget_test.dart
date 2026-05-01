import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openidconnect/openidconnect.dart';

import 'package:test_harness/src/harness_adapter.dart';
import 'package:test_harness/src/harness_controller.dart';
import 'package:test_harness/src/harness_models.dart';
import 'package:test_harness/src/test_harness_app.dart';

void main() {
  testWidgets('renders the harness controls and guidance', (
    WidgetTester tester,
  ) async {
    final controller = HarnessController(adapter: _FakeHarnessAdapter());
    addTearDown(controller.dispose);

    await tester.pumpWidget(TestHarnessApp(controller: controller));

    expect(find.text('OpenID Connect Test Harness'), findsWidgets);
    expect(find.byKey(const Key('discovery-url-field')), findsOneWidget);
    expect(find.byKey(const Key('client-id-field')), findsOneWidget);
    expect(find.byKey(const Key('load-discovery-button')), findsOneWidget);
    expect(find.byKey(const Key('login-button')), findsOneWidget);
    expect(find.byKey(const Key('rp-logout-button')), findsOneWidget);
    expect(find.textContaining('conformance suite'), findsOneWidget);
  });

  testWidgets('loads discovery and shows issuer details', (
    WidgetTester tester,
  ) async {
    final controller = HarnessController(adapter: _FakeHarnessAdapter());
    addTearDown(controller.dispose);

    await tester.pumpWidget(TestHarnessApp(controller: controller));

    await tester.enterText(
      find.byKey(const Key('discovery-url-field')),
      'https://issuer.example.com/.well-known/openid-configuration',
    );
    await tester.ensureVisible(find.byKey(const Key('load-discovery-button')));
    await tester.tap(find.byKey(const Key('load-discovery-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('issuer-text')), findsOneWidget);
    expect(find.textContaining('https://issuer.example.com'), findsWidgets);
    expect(find.byKey(const Key('status-message')), findsOneWidget);
  });

  testWidgets('starts interactive login and renders the current identity', (
    WidgetTester tester,
  ) async {
    final controller = HarnessController(adapter: _FakeHarnessAdapter());
    addTearDown(controller.dispose);

    await tester.pumpWidget(TestHarnessApp(controller: controller));

    await tester.enterText(
      find.byKey(const Key('discovery-url-field')),
      'https://issuer.example.com/.well-known/openid-configuration',
    );
    await tester.enterText(find.byKey(const Key('client-id-field')), 'client');
    await tester.enterText(
      find.byKey(const Key('redirect-url-field')),
      'https://rp.example.com/callback',
    );

    await tester.ensureVisible(find.byKey(const Key('login-button')));
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('identity-subject')), findsOneWidget);
    expect(find.textContaining('subject-123'), findsWidgets);
  });
}

class _FakeHarnessAdapter implements HarnessAdapter {
  final OpenIdConfiguration configuration = OpenIdConfiguration(
    issuer: 'https://issuer.example.com',
    jwksUri: 'https://issuer.example.com/jwks',
    authorizationEndpoint: 'https://issuer.example.com/authorize',
    tokenEndpoint: 'https://issuer.example.com/token',
    userInfoEndpoint: 'https://issuer.example.com/userinfo',
    responseTypesSupported: const ['code'],
    responseModesSupported: const ['query'],
    tokenEndpointAuthMethodsSupported: const ['client_secret_post'],
    idTokenSigningAlgValuesSupported: const ['RS256'],
    subjectTypesSupported: const ['public'],
    codeChallengeMethodsSupported: const ['S256'],
    document: const {},
    requestUriParameterSupported: false,
    endSessionEndpoint: 'https://issuer.example.com/logout',
    revocationEndpoint: 'https://issuer.example.com/revoke',
  );

  @override
  Future<HarnessSession> createSession({required HarnessConfig config}) async {
    return _FakeHarnessSession();
  }

  @override
  Future<OpenIdConfiguration> loadConfiguration(
    String discoveryDocumentUrl,
  ) async {
    return configuration;
  }
}

class _FakeHarnessSession implements HarnessSession {
  OpenIdIdentity? _identity;

  @override
  Stream<AuthEvent> get changes =>
      const Stream<AuthEvent>.empty().asBroadcastStream();

  @override
  AuthEvent? get currentEvent => const AuthEvent(AuthEventTypes.Success);

  @override
  OpenIdIdentity? get identity => _identity;

  @override
  bool get initializationComplete => true;

  @override
  Future<void> clearIdentity() async {
    _identity = null;
  }

  @override
  void dispose() {}

  @override
  Future<OpenIdIdentity> loginInteractive({
    required BuildContext context,
    required String title,
    required bool useWebPopup,
  }) async {
    _identity = OpenIdIdentity(
      accessToken: 'access-token-for-ui',
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      idToken:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJzdWJqZWN0LTEyMyIsInByZWZlcnJlZF91c2VybmFtZSI6Imhhcm5lc3MifQ.signature',
      tokenType: 'Bearer',
      refreshToken: 'refresh-token-for-ui',
    );
    return _identity!;
  }

  @override
  Future<void> logout() async {
    _identity = null;
  }

  @override
  Future<String?> logoutInteractive({
    required BuildContext context,
    required String title,
    required String? postLogoutRedirectUri,
    required bool useWebPopup,
  }) async {
    _identity = null;
    return postLogoutRedirectUri;
  }
}
