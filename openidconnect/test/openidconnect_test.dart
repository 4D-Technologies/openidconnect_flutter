import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:openidconnect/openidconnect.dart';

const TEST_ID_TOKEN =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c";
const _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final storage = <String, String>{};

  setUp(() {
    storage.clear();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async {
          final arguments = Map<Object?, Object?>.from(
            (call.arguments as Map?) ?? const {},
          );
          final key = arguments['key'] as String?;

          switch (call.method) {
            case 'write':
              storage[key!] = arguments['value'] as String;
              return null;
            case 'read':
              return storage[key];
            case 'delete':
              storage.remove(key);
              return null;
            case 'deleteAll':
              storage.clear();
              return null;
            case 'containsKey':
              return storage.containsKey(key);
            case 'readAll':
              return storage;
            default:
              throw UnimplementedError('Unhandled method ${call.method}');
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
  });

  group("openididentity", () {
    test("save identity", () async {
      final identity = OpenIdIdentity(
        accessToken: "testing_access_token",
        expiresAt: DateTime.now(),
        idToken: TEST_ID_TOKEN,
        tokenType: "Bearer",
      );

      await identity.save();
    });

    test("load identity", () async {
      final identity = OpenIdIdentity(
        accessToken: "testing_access_token",
        expiresAt: DateTime.now(),
        idToken: TEST_ID_TOKEN,
        tokenType: "Bearer",
      );

      await identity.save();

      final loaded = await OpenIdIdentity.load();
      expect(loaded, isNot(null));
    });
  });

  group('interactive authorization request', () {
    test('uses authorization-endpoint parameters only', () async {
      final request = await InteractiveAuthorizationRequest.create(
        clientId: 'client-id',
        clientSecret: 'super-secret',
        redirectUrl: 'com.example.app:/oauth2redirect',
        scopes: const ['openid', 'profile', 'email'],
        configuration: _testConfiguration(),
        autoRefresh: true,
        loginHint: 'person@example.com',
        prompts: const ['login'],
        additionalParameters: const {'audience': 'api://default'},
      );

      final map = request.toMap();

      expect(map['client_id'], 'client-id');
      expect(map['scope'], 'openid profile email');
      expect(map['response_type'], 'code');
      expect(map['redirect_uri'], 'com.example.app:/oauth2redirect');
      expect(map['prompt'], 'login');
      expect(map['login_hint'], 'person@example.com');
      expect(map['audience'], 'api://default');
      expect(map['code_challenge_method'], 'S256');
      expect(map['code_challenge'], isNotEmpty);
      expect(map['state'], isNotEmpty);
      expect(map.containsKey('grant_type'), isFalse);
      expect(map.containsKey('client_secret'), isFalse);
    });

    test('generates PKCE verifier and state within expected bounds', () async {
      final request = await InteractiveAuthorizationRequest.create(
        clientId: 'client-id',
        redirectUrl: 'com.example.app:/oauth2redirect',
        scopes: const ['openid'],
        configuration: _testConfiguration(),
        autoRefresh: true,
      );

      expect(request.codeVerifier.length, inInclusiveRange(43, 128));
      expect(request.state.length, inInclusiveRange(43, 128));
      expect(request.codeChallenge, isNotEmpty);
    });
  });

  group('authorization response parsing', () {
    test('uses fallback id token for refresh responses', () {
      final response = AuthorizationResponse.fromJson({
        'access_token': 'access-token',
        'token_type': 'Bearer',
        'expires_in': 3600,
        'refresh_token': 'refresh-token',
      }, fallbackIdToken: TEST_ID_TOKEN);

      expect(response.idToken, TEST_ID_TOKEN);
      expect(response.refreshToken, 'refresh-token');
    });

    test('throws when id token is missing and no fallback is available', () {
      expect(
        () => AuthorizationResponse.fromJson({
          'access_token': 'access-token',
          'token_type': 'Bearer',
          'expires_in': 3600,
        }),
        throwsFormatException,
      );
    });
  });

  group('interactive logout request', () {
    test('serializes registered logout redirect and state', () {
      final request = InteractiveLogoutRequest(
        configuration: _testConfiguration(),
        idToken: TEST_ID_TOKEN,
        postLogoutRedirectUrl: 'com.example.app:/logout',
        state: 'logout-state',
      );

      expect(request.toMap(), {
        'id_token_hint': TEST_ID_TOKEN,
        'post_logout_redirect_uri': 'com.example.app:/logout',
        'state': 'logout-state',
      });
    });
  });
  // test('adds one to input values', () {
  //   final calculator = Calculator();
  //   expect(calculator.addOne(2), 3);
  //   expect(calculator.addOne(-7), -6);
  //   expect(calculator.addOne(0), 1);
  // });
}

OpenIdConfiguration _testConfiguration() {
  return OpenIdConfiguration(
    issuer: 'https://issuer.example.com',
    jwksUri: 'https://issuer.example.com/.well-known/jwks.json',
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
  );
}
