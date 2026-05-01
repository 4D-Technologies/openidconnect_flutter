import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:openidconnect/openidconnect.dart';

const TEST_ID_TOKEN =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c";
const _secureStorageChannel = MethodChannel(
  'plugins.concerti.io/openidconnect_secure_storage',
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
            case 'initialize':
              return null;
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

    test('clears invalid stored identity values', () async {
      storage['ACCESS_TOKEN'] = 'stale-access-token';
      storage['ID_TOKEN'] = 'not-a-jwt';
      storage['EXPIRES_ON'] = DateTime.now().millisecondsSinceEpoch.toString();
      storage['TOKEN_TYPE'] = 'Bearer';

      final loaded = await OpenIdIdentity.load();

      expect(loaded, isNull);
      expect(storage, isEmpty);
    });

    test('exposes identity claims via convenience getters', () {
      final identity = OpenIdIdentity(
        accessToken: 'access-token',
        expiresAt: DateTime.now(),
        idToken: _buildJwt({
          'sub': 'subject-123',
          'given_name': 'Jane',
          'family_name': 'Doe',
          'preferred_username': 'jane.doe',
          'email': 'jane@example.com',
          'act': 'delegated-user',
          'role': ['admin', 'reader'],
          'picture': 'https://images.example.com/avatar.png',
        }),
        tokenType: 'Bearer',
      );

      expect(identity.sub, 'subject-123');
      expect(identity.givenName, 'Jane');
      expect(identity.familyName, 'Doe');
      expect(identity.fullName, 'Jane Doe');
      expect(identity.userName, 'jane.doe');
      expect(identity.email, 'jane@example.com');
      expect(identity.act, 'delegated-user');
      expect(identity.roles, ['admin', 'reader']);
      expect(identity.picture, 'https://images.example.com/avatar.png');
    });

    test('rejects id tokens without a subject claim', () {
      expect(
        () => OpenIdIdentity(
          accessToken: 'access-token',
          expiresAt: DateTime.now(),
          idToken: _buildJwt({'name': 'No Subject'}),
          tokenType: 'Bearer',
        ),
        throwsFormatException,
      );
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

  group('request and configuration models', () {
    test('serializes logout token request optional fields', () {
      final request = LogoutTokenRequest(
        configuration: _testConfiguration(),
        refreshToken: 'refresh-token',
        clientId: 'client-id',
        clientSecret: 'client-secret',
        redirectUrl: 'com.example.app:/logout',
      );

      expect(request.toMap(), {
        'client_id': 'client-id',
        'client_secret': 'client-secret',
        'redirect_uri': 'com.example.app:/logout',
        'refresh_token': 'refresh-token',
      });
    });

    test('serializes revoke token request with explicit form credentials', () {
      final request = RevokeTokenRequest(
        configuration: _testConfiguration(),
        token: 'refresh-token',
        tokenType: TokenType.refreshToken,
        clientId: 'client-id',
        clientSecret: 'client-secret',
      );

      expect(request.toMap(useBasicAuth: false), {
        'client_secret': 'client-secret',
        'client_id': 'client-id',
        'token': 'refresh-token',
        'token_type_hint': 'refresh_token',
      });
    });

    test('parses optional discovery metadata and api endpoints', () {
      final configuration = OpenIdConfiguration.fromJson({
        'issuer': 'https://issuer.example.com',
        'jwks_uri': 'https://issuer.example.com/jwks',
        'authorization_endpoint': 'https://issuer.example.com/authorize',
        'token_endpoint': 'https://issuer.example.com/token',
        'userinfo_endpoint': 'https://issuer.example.com/userinfo',
        'mfa_challenge_endpoint': 'https://issuer.example.com/mfa',
        'api_endpoint': 'https://issuer.example.com/api',
        'check_session_iframe': 'https://issuer.example.com/session',
      });

      expect(
        configuration.mfaChallengeEndpoint,
        'https://issuer.example.com/mfa',
      );
      expect(configuration.apiEndpoints, ['https://issuer.example.com/api']);
      expect(
        configuration.checkSessionIFrame,
        'https://issuer.example.com/session',
      );
      expect(configuration.responseTypesSupported, isEmpty);
      expect(configuration.responseModesSupported, isEmpty);
      expect(configuration.tokenEndpointAuthMethodsSupported, isEmpty);
      expect(configuration.codeChallengeMethodsSupported, isEmpty);
      expect(configuration.requestUriParameterSupported, isFalse);
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

String _buildJwt(Map<String, Object?> payload) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

  return '${encode({'alg': 'HS256', 'typ': 'JWT'})}.${encode(payload)}.sig';
}
