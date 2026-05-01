import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openidconnect/openidconnect.dart';
import 'package:test_harness/src/harness_adapter.dart';
import 'package:test_harness/src/harness_controller.dart';
import 'package:test_harness/src/harness_models.dart';

void main() {
  group('HarnessController', () {
    test('loads discovery metadata and updates the snapshot', () async {
      final adapter = _FakeHarnessAdapter();
      final controller = HarnessController(adapter: adapter);
      addTearDown(controller.dispose);

      await controller.loadDiscovery(_config());

      expect(controller.snapshot.configuration, isNotNull);
      expect(
        controller.snapshot.configuration!.issuer,
        'https://issuer.example.com',
      );
      expect(
        controller.snapshot.statusMessage,
        contains('Loaded discovery metadata'),
      );
    });

    test('initializes the session and performs login/logout flows', () async {
      final adapter = _FakeHarnessAdapter();
      final controller = HarnessController(adapter: adapter);
      addTearDown(controller.dispose);

      await controller.initializeClient(_config());
      expect(controller.snapshot.clientReady, isTrue);
      expect(adapter.createSessionCallCount, 1);

      await controller.loginInteractive(_config(), _FakeBuildContext());
      expect(controller.snapshot.identity, isNotNull);
      expect(controller.snapshot.identity!.sub, 'subject-123');
      expect(
        controller.snapshot.statusMessage,
        contains('Interactive login completed'),
      );

      await controller.logoutInteractive(_config(), _FakeBuildContext());
      expect(controller.snapshot.identity, isNull);
      expect(
        controller.snapshot.lastRedirect,
        'https://rp.example.com/logout-complete',
      );
    });

    test(
      'validates required fields before starting the interactive flow',
      () async {
        final adapter = _FakeHarnessAdapter();
        final controller = HarnessController(adapter: adapter);
        addTearDown(controller.dispose);

        await controller.loginInteractive(
          _config().copyWith(
            discoveryDocumentUrl: '',
            clientId: '',
            redirectUrl: '',
          ),
          _FakeBuildContext(),
        );

        expect(adapter.createSessionCallCount, 0);
        expect(
          controller.snapshot.statusMessage,
          contains('issuer discovery document URL'),
        );
      },
    );
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

  int createSessionCallCount = 0;

  @override
  Future<HarnessSession> createSession({required HarnessConfig config}) async {
    createSessionCallCount += 1;
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
  final _controller = StreamController<AuthEvent>.broadcast();

  OpenIdIdentity? _identity;
  AuthEvent? _currentEvent;

  @override
  Stream<AuthEvent> get changes => _controller.stream;

  @override
  AuthEvent? get currentEvent => _currentEvent;

  @override
  OpenIdIdentity? get identity => _identity;

  @override
  bool get initializationComplete => true;

  @override
  Future<void> clearIdentity() async {
    _identity = null;
    _currentEvent = const AuthEvent(AuthEventTypes.NotLoggedIn);
    _controller.add(_currentEvent!);
  }

  @override
  void dispose() {
    _controller.close();
  }

  @override
  Future<OpenIdIdentity> loginInteractive({
    required BuildContext context,
    required String title,
    required bool useWebPopup,
  }) async {
    _identity = OpenIdIdentity(
      accessToken: 'access-token',
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      idToken: _jwt(),
      tokenType: 'Bearer',
      refreshToken: 'refresh-token',
    );
    _currentEvent = const AuthEvent(AuthEventTypes.Success);
    _controller.add(_currentEvent!);
    return _identity!;
  }

  @override
  Future<void> logout() => clearIdentity();

  @override
  Future<String?> logoutInteractive({
    required BuildContext context,
    required String title,
    required String? postLogoutRedirectUri,
    required bool useWebPopup,
  }) async {
    await clearIdentity();
    return 'https://rp.example.com/logout-complete';
  }
}

HarnessConfig _config() {
  return const HarnessConfig(
    discoveryDocumentUrl:
        'https://issuer.example.com/.well-known/openid-configuration',
    clientId: 'client-id',
    clientSecret: '',
    redirectUrl: 'https://rp.example.com/callback',
    scopesText: 'openid profile email',
    loginTitle: 'Harness Login',
    postLogoutRedirectUrl: 'https://rp.example.com/logout-complete',
    autoRefresh: false,
    useWebPopup: false,
  );
}

String _jwt() {
  return 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJzdWJqZWN0LTEyMyIsImVtYWlsIjoiaGFybmVzc0BleGFtcGxlLmNvbSJ9.signature';
}

class _FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
