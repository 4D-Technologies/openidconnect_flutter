import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openidconnect/openidconnect.dart';
import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';

const _testIdToken =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJodHRwLXRlc3Qtc3ViamVjdCIsImlhdCI6MTUxNjIzOTAyMn0.c2ln';

void main() {
  late HttpServer server;
  late Uri baseUri;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUri = Uri.parse('http://${server.address.address}:${server.port}');
  });

  tearDown(() async {
    await server.close(force: true);
  });

  test('loads and parses the discovery document', () async {
    server.listen((request) async {
      expect(request.method, 'GET');
      expect(request.uri.path, '/.well-known/openid-configuration');
      await _writeJson(request.response, _discoveryDocument(baseUri));
    });

    final configuration = await OpenIdConnect.getConfiguration(
      baseUri.resolve('/.well-known/openid-configuration').toString(),
    );

    expect(configuration.issuer, baseUri.toString());
    expect(configuration.tokenEndpoint, baseUri.resolve('/token').toString());
    expect(
      configuration.userInfoEndpoint,
      baseUri.resolve('/userinfo').toString(),
    );
    expect(
      configuration.revocationEndpoint,
      baseUri.resolve('/revoke').toString(),
    );
  });

  test('authorizes with password grant against the token endpoint', () async {
    server.listen((request) async {
      expect(request.method, 'POST');
      expect(request.uri.path, '/token');

      final body = Uri.splitQueryString(
        await utf8.decoder.bind(request).join(),
      );
      expect(body['grant_type'], 'password');
      expect(body['username'], 'alice');
      expect(body['password'], 'secret');
      expect(body['client_id'], 'client-id');

      await _writeJson(request.response, {
        'access_token': 'access-token',
        'token_type': 'Bearer',
        'expires_in': 3600,
        'id_token': _testIdToken,
        'refresh_token': 'refresh-token',
      });
    });

    final response = await OpenIdConnect.authorizePassword(
      request: PasswordAuthorizationRequest(
        clientId: 'client-id',
        clientSecret: 'super-secret',
        scopes: const ['openid', 'profile'],
        userName: 'alice',
        password: 'secret',
        configuration: _configuration(baseUri),
        autoRefresh: false,
      ),
    );

    expect(response.accessToken, 'access-token');
    expect(response.refreshToken, 'refresh-token');
    expect(response.idToken, _testIdToken);
  });

  test('refreshes tokens while preserving the current id token', () async {
    server.listen((request) async {
      expect(request.method, 'POST');
      expect(request.uri.path, '/token');

      final body = Uri.splitQueryString(
        await utf8.decoder.bind(request).join(),
      );
      expect(body['grant_type'], 'refresh_token');
      expect(body['refresh_token'], 'refresh-token');

      await _writeJson(request.response, {
        'access_token': 'updated-access-token',
        'token_type': 'Bearer',
        'expires_in': 1800,
      });
    });

    final response = await OpenIdConnect.refreshToken(
      request: RefreshRequest(
        clientId: 'client-id',
        scopes: const ['openid'],
        refreshToken: 'refresh-token',
        currentIdToken: _testIdToken,
        configuration: _configuration(baseUri),
      ),
    );

    expect(response.accessToken, 'updated-access-token');
    expect(response.idToken, _testIdToken);
  });

  test(
    'returns device-code metadata without launching the verification flow',
    () async {
      server.listen((request) async {
        expect(request.method, 'POST');
        expect(request.uri.path, '/device');

        final body = Uri.splitQueryString(
          await utf8.decoder.bind(request).join(),
        );
        expect(body['client_id'], 'client-id');

        await _writeJson(request.response, {
          'device_code': 'device-code',
          'user_code': 'ABCD-EFGH',
          'verification_uri': baseUri.resolve('/verify').toString(),
          'verification_uri_complete': baseUri
              .resolve('/verify-complete')
              .toString(),
          'expires_in': 900,
          'interval': 1,
        });
      });

      final response = await OpenIdConnect.authorizeDeviceGetDeviceCodeResponse(
        request: DeviceAuthorizationRequest(
          audience: null,
          clientId: 'client-id',
          configuration: _configuration(baseUri),
          scopes: const ['openid'],
        ),
      );

      expect(response.deviceCode, 'device-code');
      expect(response.userCode, 'ABCD-EFGH');
    },
  );

  test('requests user info with a bearer token', () async {
    server.listen((request) async {
      expect(request.method, 'GET');
      expect(request.uri.path, '/userinfo');
      expect(request.headers.value('authorization'), 'Bearer access-token');

      await _writeJson(request.response, {'sub': 'subject-123'});
    });

    final response = await OpenIdConnect.getUserInfo(
      request: UserInfoRequest(
        accessToken: 'access-token',
        configuration: _configuration(baseUri),
      ),
    );

    expect(response, {'sub': 'subject-123'});
  });

  test(
    'revokes tokens using HTTP basic authentication when credentials exist',
    () async {
      server.listen((request) async {
        expect(request.method, 'POST');
        expect(request.uri.path, '/revoke');
        expect(
          request.headers.value('authorization'),
          'Basic ${base64Encode(utf8.encode('client-id:secret'))}',
        );

        final body = Uri.splitQueryString(
          await utf8.decoder.bind(request).join(),
        );
        expect(body['token'], 'refresh-token');
        expect(body['token_type_hint'], 'refresh_token');
        request.response.statusCode = HttpStatus.ok;
        await request.response.close();
      });

      await OpenIdConnect.revokeToken(
        request: RevokeTokenRequest(
          clientId: 'client-id',
          clientSecret: 'secret',
          configuration: _configuration(baseUri),
          token: 'refresh-token',
          tokenType: TokenType.refreshToken,
        ),
      );
    },
  );

  test('wraps logout endpoint failures as LogoutException', () async {
    server.listen((request) async {
      expect(request.method, 'GET');
      expect(request.uri.path, '/logout');
      request.response.statusCode = HttpStatus.badRequest;
      await _writeJson(request.response, {
        'error': 'logout_failed',
        'error_description': 'No session',
      }, statusCode: HttpStatus.badRequest);
    });

    await expectLater(
      () => OpenIdConnect.logout(
        request: LogoutRequest(
          configuration: _configuration(baseUri),
          idToken: _testIdToken,
        ),
      ),
      throwsA(isA<LogoutException>()),
    );
  });

  test('returns null from processStartup outside web runtimes', () async {
    final response = await OpenIdConnect.processStartup(
      clientId: 'client-id',
      redirectUrl: 'com.example.app:/callback',
      scopes: const ['openid'],
      configuration: _configuration(baseUri),
    );

    expect(response, isNull);
  });

  test(
    'returns null from logoutInteractive when no end-session endpoint exists',
    () async {
      final configuration = OpenIdConfiguration.fromJson({
        ..._discoveryDocument(baseUri),
        'end_session_endpoint': null,
      });

      final response = await OpenIdConnect.logoutInteractive(
        context: _FakeBuildContext(),
        title: 'Logout',
        request: InteractiveLogoutRequest(
          configuration: configuration,
          postLogoutRedirectUrl: 'com.example.app:/logout',
          idToken: _testIdToken,
        ),
      );

      expect(response, isNull);
    },
  );

  test('registers users with the configured registration endpoint', () async {
    server.listen((request) async {
      expect(request.method, 'GET');
      expect(request.uri.path, '/register');
      expect(request.headers.value('authorization'), 'Bearer access-token');

      await _writeJson(request.response, {'status': 'ok'});
    });

    await OpenIdConnect.registerUser(
      request: UserRegistrationRequest(
        accessToken: 'access-token',
        configuration: _configuration(baseUri),
      ),
    );
  });
}

OpenIdConfiguration _configuration(Uri baseUri) {
  return OpenIdConfiguration.fromJson(_discoveryDocument(baseUri));
}

Map<String, dynamic> _discoveryDocument(Uri baseUri) {
  return {
    'issuer': baseUri.toString(),
    'jwks_uri': baseUri.resolve('/jwks').toString(),
    'authorization_endpoint': baseUri.resolve('/authorize').toString(),
    'token_endpoint': baseUri.resolve('/token').toString(),
    'device_authorization_endpoint': baseUri.resolve('/device').toString(),
    'userinfo_endpoint': baseUri.resolve('/userinfo').toString(),
    'end_session_endpoint': baseUri.resolve('/logout').toString(),
    'revocation_endpoint': baseUri.resolve('/revoke').toString(),
    'registration_endpoint': baseUri.resolve('/register').toString(),
    'response_types_supported': ['code'],
    'response_modes_supported': ['query'],
    'token_endpoint_auth_methods_supported': ['client_secret_basic'],
    'id_token_signing_alg_values_supported': ['RS256'],
    'subject_types_supported': ['public'],
    'code_challenge_methods_supported': ['S256'],
    'request_uri_parameter_supported': false,
  };
}

Future<void> _writeJson(
  HttpResponse response,
  Object body, {
  int statusCode = HttpStatus.ok,
}) async {
  response.statusCode = statusCode;
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(body));
  await response.close();
}

class _FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
