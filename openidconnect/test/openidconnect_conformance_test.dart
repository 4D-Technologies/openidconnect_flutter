import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openidconnect/openidconnect.dart';
import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

const _testIdToken =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJjb25mb3JtYW5jZS1zdWJqZWN0IiwibmFtZSI6IkNvbmZvcm1hbmNlIFRlc3RlciIsImlhdCI6MTUxNjIzOTAyMn0.c2ln';

void main() {
  late HttpServer server;
  late Uri baseUri;
  late OpenIdConnectPlatform originalPlatform;
  late _FakeOpenIdConnectPlatform fakePlatform;

  setUp(() async {
    originalPlatform = OpenIdConnectPlatform.instance;
    fakePlatform = _FakeOpenIdConnectPlatform();
    OpenIdConnectPlatform.instance = fakePlatform;

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUri = Uri.parse('http://${server.address.address}:${server.port}');
  });

  tearDown(() async {
    OpenIdConnectPlatform.instance = originalPlatform;
    await server.close(force: true);
  });

  group('authorization code conformance', () {
    test('exchanges a valid authorization code and preserves state', () async {
      late InteractiveAuthorizationRequest request;

      server.listen((httpRequest) async {
        expect(httpRequest.method, 'POST');
        expect(httpRequest.uri.path, '/token');

        final body = Uri.splitQueryString(
          await utf8.decoder.bind(httpRequest).join(),
        );

        expect(body['grant_type'], 'authorization_code');
        expect(body['client_id'], 'client-id');
        expect(body['redirect_uri'], 'com.example.app:/oauth2redirect');
        expect(body['code'], 'auth-code');
        expect(body['code_verifier'], request.codeVerifier);
        expect(body['client_secret'], 'super-secret');

        await _writeJson(httpRequest.response, {
          'access_token': 'access-token',
          'token_type': 'Bearer',
          'expires_in': 3600,
          'refresh_token': 'refresh-token',
          'id_token': _testIdToken,
        });
      });

      request = await InteractiveAuthorizationRequest.create(
        clientId: 'client-id',
        clientSecret: 'super-secret',
        redirectUrl: 'com.example.app:/oauth2redirect',
        scopes: const ['openid', 'profile', 'email'],
        configuration: _configuration(baseUri),
        autoRefresh: true,
        prompts: const ['login'],
        additionalParameters: const {'audience': 'api://example'},
      );

      fakePlatform.authorizeInteractiveResponse =
          'com.example.app:/oauth2redirect?code=auth-code&state=${request.state}';

      final response = await OpenIdConnect.authorizeInteractive(
        context: _FakeBuildContext(),
        title: 'Sign in to Example',
        request: request,
      );

      final authorizationUrl = Uri.parse(
        fakePlatform.lastAuthorizeArguments!['authorizationUrl'] as String,
      );

      expect(
        fakePlatform.lastAuthorizeArguments!['title'],
        'Sign in to Example',
      );
      expect(
        fakePlatform.lastAuthorizeArguments!['redirectUrl'],
        'com.example.app:/oauth2redirect',
      );
      expect(authorizationUrl.queryParameters['client_id'], 'client-id');
      expect(authorizationUrl.queryParameters['response_type'], 'code');
      expect(authorizationUrl.queryParameters['scope'], 'openid profile email');
      expect(authorizationUrl.queryParameters['prompt'], 'login');
      expect(authorizationUrl.queryParameters['audience'], 'api://example');
      expect(authorizationUrl.queryParameters['state'], request.state);
      expect(
        authorizationUrl.queryParameters['code_challenge'],
        request.codeChallenge,
      );
      expect(response, isNotNull);
      expect(response!.accessToken, 'access-token');
      expect(response.refreshToken, 'refresh-token');
      expect(response.idToken, _testIdToken);
      expect(response.state, request.state);
    });

    test('rejects authorization responses with mismatched state', () async {
      final request = await InteractiveAuthorizationRequest.create(
        clientId: 'client-id',
        redirectUrl: 'com.example.app:/oauth2redirect',
        scopes: const ['openid'],
        configuration: _configuration(baseUri),
        autoRefresh: false,
      );

      fakePlatform.authorizeInteractiveResponse =
          'com.example.app:/oauth2redirect?code=auth-code&state=wrong-state';

      await expectLater(
        () => OpenIdConnect.authorizeInteractive(
          context: _FakeBuildContext(),
          title: 'Sign in',
          request: request,
        ),
        throwsA(isA<AuthenticationException>()),
      );
    });

    test(
      'surfaces provider authorization errors without exchanging code',
      () async {
        final request = await InteractiveAuthorizationRequest.create(
          clientId: 'client-id',
          redirectUrl: 'com.example.app:/oauth2redirect',
          scopes: const ['openid'],
          configuration: _configuration(baseUri),
          autoRefresh: false,
        );

        fakePlatform.authorizeInteractiveResponse =
            'com.example.app:/oauth2redirect?error=access_denied';

        await expectLater(
          () => OpenIdConnect.authorizeInteractive(
            context: _FakeBuildContext(),
            title: 'Sign in',
            request: request,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.message.toString(),
              'message',
              contains('access_denied'),
            ),
          ),
        );
      },
    );

    test(
      'throws when the discovery document endpoint returns an empty body',
      () async {
        server.listen((httpRequest) async {
          expect(httpRequest.method, 'GET');
          httpRequest.response.statusCode = HttpStatus.ok;
          await httpRequest.response.close();
        });

        await expectLater(
          () => OpenIdConnect.getConfiguration(
            baseUri.resolve('/.well-known/openid-configuration').toString(),
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test(
      'builds RP-initiated logout requests with the supplied title',
      () async {
        fakePlatform.authorizeInteractiveResponse =
            'com.example.app:/logout?state=logout-state';

        final response = await OpenIdConnect.logoutInteractive(
          context: _FakeBuildContext(),
          title: 'Sign out of Example',
          request: InteractiveLogoutRequest(
            configuration: _configuration(baseUri),
            idToken: _testIdToken,
            postLogoutRedirectUrl: 'com.example.app:/logout',
            state: 'logout-state',
          ),
        );

        final authorizationUrl = Uri.parse(
          fakePlatform.lastAuthorizeArguments!['authorizationUrl'] as String,
        );

        expect(
          fakePlatform.lastAuthorizeArguments!['title'],
          'Sign out of Example',
        );
        expect(authorizationUrl.queryParameters['id_token_hint'], _testIdToken);
        expect(
          authorizationUrl.queryParameters['post_logout_redirect_uri'],
          'com.example.app:/logout',
        );
        expect(authorizationUrl.queryParameters['state'], 'logout-state');
        expect(response, 'com.example.app:/logout?state=logout-state');
      },
    );
  });

  group('client conformance-critical behavior', () {
    test(
      'logs in with password grant and persists the resulting identity',
      () async {
        server.listen((httpRequest) async {
          switch (httpRequest.uri.path) {
            case '/.well-known/openid-configuration':
              await _writeJson(
                httpRequest.response,
                _discoveryDocument(baseUri),
              );
              break;
            case '/token':
              final body = Uri.splitQueryString(
                await utf8.decoder.bind(httpRequest).join(),
              );
              expect(body['grant_type'], 'password');
              expect(body['username'], 'alice');
              expect(body['password'], 'secret');
              expect(body['scope'], 'openid profile');
              await _writeJson(httpRequest.response, {
                'access_token': 'access-token',
                'token_type': 'Bearer',
                'expires_in': 3600,
                'refresh_token': 'refresh-token',
                'id_token': _testIdToken,
              });
              break;
            default:
              fail('Unexpected request to ${httpRequest.uri.path}');
          }
        });

        final client = await OpenIdConnectClient.create(
          discoveryDocumentUrl: baseUri
              .resolve('/.well-known/openid-configuration')
              .toString(),
          clientId: 'client-id',
          clientSecret: 'client-secret',
          encryptionKey: 'unused',
          autoRefresh: false,
          scopes: const ['openid', 'profile'],
        );
        addTearDown(client.dispose);

        final identity = await client.loginWithPassword(
          userName: 'alice',
          password: 'secret',
        );

        expect(identity.accessToken, 'access-token');
        expect(identity.refreshToken, 'refresh-token');
        expect(client.identity, isNotNull);
        expect(client.currentEvent, const AuthEvent(AuthEventTypes.Success));
        expect(await OpenIdIdentity.load(), isNotNull);
      },
    );

    test('keeps a valid identity when refresh fails before expiry', () async {
      await _saveIdentity(
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
        refreshToken: 'refresh-token',
      );

      server.listen((httpRequest) async {
        switch (httpRequest.uri.path) {
          case '/.well-known/openid-configuration':
            await _writeJson(httpRequest.response, _discoveryDocument(baseUri));
            break;
          case '/token':
            await _writeJson(httpRequest.response, {
              'error': 'temporarily_unavailable',
              'error_description': 'Try again later',
            }, statusCode: HttpStatus.badRequest);
            break;
          default:
            fail('Unexpected request to ${httpRequest.uri.path}');
        }
      });

      final client = await OpenIdConnectClient.create(
        discoveryDocumentUrl: baseUri
            .resolve('/.well-known/openid-configuration')
            .toString(),
        clientId: 'client-id',
        encryptionKey: 'unused',
        autoRefresh: false,
      );
      addTearDown(client.dispose);

      final refreshed = await client.refresh();

      expect(refreshed, isFalse);
      expect(client.identity, isNotNull);
      expect(client.currentEvent!.type, AuthEventTypes.Error);
      expect(client.currentEvent!.message, contains('temporarily_unavailable'));
    });

    test('clears an expired identity when refresh fails', () async {
      await _saveIdentity(
        expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
        refreshToken: 'refresh-token',
      );

      server.listen((httpRequest) async {
        switch (httpRequest.uri.path) {
          case '/.well-known/openid-configuration':
            await _writeJson(httpRequest.response, _discoveryDocument(baseUri));
            break;
          case '/token':
            await _writeJson(httpRequest.response, {
              'error': 'invalid_grant',
              'error_description': 'Refresh token expired',
            }, statusCode: HttpStatus.badRequest);
            break;
          default:
            fail('Unexpected request to ${httpRequest.uri.path}');
        }
      });

      final client = await OpenIdConnectClient.create(
        discoveryDocumentUrl: baseUri
            .resolve('/.well-known/openid-configuration')
            .toString(),
        clientId: 'client-id',
        encryptionKey: 'unused',
        autoRefresh: false,
      );
      addTearDown(client.dispose);

      final refreshed = await client.refresh();

      expect(refreshed, isFalse);
      expect(client.identity, isNull);
      expect(client.currentEvent!.type, AuthEventTypes.NotLoggedIn);
      expect(await OpenIdIdentity.load(), isNull);
    });

    test(
      'logs out by revoking the refresh token and clearing local state',
      () async {
        await _saveIdentity(
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
          refreshToken: 'refresh-token',
        );

        server.listen((httpRequest) async {
          switch (httpRequest.uri.path) {
            case '/.well-known/openid-configuration':
              await _writeJson(
                httpRequest.response,
                _discoveryDocument(baseUri),
              );
              break;
            case '/revoke':
              final body = Uri.splitQueryString(
                await utf8.decoder.bind(httpRequest).join(),
              );
              expect(body['token'], 'refresh-token');
              expect(body['token_type_hint'], 'refresh_token');
              httpRequest.response.statusCode = HttpStatus.ok;
              await httpRequest.response.close();
              break;
            default:
              fail('Unexpected request to ${httpRequest.uri.path}');
          }
        });

        final client = await OpenIdConnectClient.create(
          discoveryDocumentUrl: baseUri
              .resolve('/.well-known/openid-configuration')
              .toString(),
          clientId: 'client-id',
          encryptionKey: 'unused',
          autoRefresh: false,
        );
        addTearDown(client.dispose);

        final events = <AuthEvent>[];
        final subscription = client.changes.listen(events.add);
        addTearDown(subscription.cancel);

        await client.logout();
        await Future<void>.delayed(Duration.zero);

        expect(client.identity, isNull);
        final eventTypes = events.map((event) => event.type).toList();
        expect(eventTypes.sublist(eventTypes.length - 2), [
          AuthEventTypes.LoggingOut,
          AuthEventTypes.NotLoggedIn,
        ]);
      },
    );

    test(
      'logoutInteractive revokes locally before native sign-out and forwards title',
      () async {
        await _saveIdentity(
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
          refreshToken: 'refresh-token',
        );

        var revoked = false;
        fakePlatform.authorizeInteractiveHandler =
            ({
              required title,
              required authorizationUrl,
              required redirectUrl,
              required popupWidth,
              required popupHeight,
              required useWebRedirectLoop,
            }) async {
              expect(revoked, isTrue);
              return 'com.example.app:/logout?state=logout-state';
            };

        server.listen((httpRequest) async {
          switch (httpRequest.uri.path) {
            case '/.well-known/openid-configuration':
              await _writeJson(
                httpRequest.response,
                _discoveryDocument(baseUri),
              );
              break;
            case '/revoke':
              revoked = true;
              httpRequest.response.statusCode = HttpStatus.ok;
              await httpRequest.response.close();
              break;
            default:
              fail('Unexpected request to ${httpRequest.uri.path}');
          }
        });

        final client = await OpenIdConnectClient.create(
          discoveryDocumentUrl: baseUri
              .resolve('/.well-known/openid-configuration')
              .toString(),
          clientId: 'client-id',
          encryptionKey: 'unused',
          redirectUrl: 'com.example.app:/callback',
          autoRefresh: false,
        );
        addTearDown(client.dispose);

        final response = await client.logoutInteractive(
          context: _FakeBuildContext(),
          title: 'Sign out now',
          postLogoutRedirectUri: 'com.example.app:/logout',
        );

        final authorizationUrl = Uri.parse(
          fakePlatform.lastAuthorizeArguments!['authorizationUrl'] as String,
        );

        expect(fakePlatform.lastAuthorizeArguments!['title'], 'Sign out now');
        expect(authorizationUrl.queryParameters['id_token_hint'], _testIdToken);
        expect(
          authorizationUrl.queryParameters['post_logout_redirect_uri'],
          'com.example.app:/logout',
        );
        expect(client.identity, isNull);
        expect(response, 'com.example.app:/logout?state=logout-state');
      },
    );

    test(
      'logoutInteractive falls back to local revoke when no end-session endpoint exists',
      () async {
        await _saveIdentity(
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
          refreshToken: 'refresh-token',
        );

        server.listen((httpRequest) async {
          switch (httpRequest.uri.path) {
            case '/.well-known/openid-configuration':
              await _writeJson(
                httpRequest.response,
                _discoveryDocument(baseUri, includeEndSessionEndpoint: false),
              );
              break;
            case '/revoke':
              httpRequest.response.statusCode = HttpStatus.ok;
              await httpRequest.response.close();
              break;
            default:
              fail('Unexpected request to ${httpRequest.uri.path}');
          }
        });

        final client = await OpenIdConnectClient.create(
          discoveryDocumentUrl: baseUri
              .resolve('/.well-known/openid-configuration')
              .toString(),
          clientId: 'client-id',
          encryptionKey: 'unused',
          autoRefresh: false,
        );
        addTearDown(client.dispose);

        final response = await client.logoutInteractive(
          context: _FakeBuildContext(),
          title: 'Sign out',
          postLogoutRedirectUri: 'com.example.app:/logout',
        );

        expect(response, isNull);
        expect(fakePlatform.lastAuthorizeArguments, isNull);
        expect(client.identity, isNull);
        expect(
          client.currentEvent,
          const AuthEvent(AuthEventTypes.NotLoggedIn),
        );
      },
    );

    test(
      'revokes the access token when no refresh token is available',
      () async {
        await _saveIdentity(
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        );

        server.listen((httpRequest) async {
          switch (httpRequest.uri.path) {
            case '/.well-known/openid-configuration':
              await _writeJson(
                httpRequest.response,
                _discoveryDocument(baseUri),
              );
              break;
            case '/revoke':
              final body = Uri.splitQueryString(
                await utf8.decoder.bind(httpRequest).join(),
              );
              expect(body['token'], 'access-token');
              expect(body['token_type_hint'], 'access_token');
              expect(body['client_id'], 'client-id');
              expect(body['client_secret'], 'client-secret');
              httpRequest.response.statusCode = HttpStatus.ok;
              await httpRequest.response.close();
              break;
            default:
              fail('Unexpected request to ${httpRequest.uri.path}');
          }
        });

        final client = await OpenIdConnectClient.create(
          discoveryDocumentUrl: baseUri
              .resolve('/.well-known/openid-configuration')
              .toString(),
          clientId: 'client-id',
          clientSecret: 'client-secret',
          encryptionKey: 'unused',
          autoRefresh: false,
        );
        addTearDown(client.dispose);

        await client.revokeTokens(useBasicAuth: false);

        expect(client.identity, isNotNull);
      },
    );
  });
}

Future<void> _saveIdentity({
  required DateTime expiresAt,
  String? refreshToken,
}) async {
  final identity = OpenIdIdentity(
    accessToken: 'access-token',
    expiresAt: expiresAt,
    idToken: _testIdToken,
    tokenType: 'Bearer',
    refreshToken: refreshToken,
  );

  await identity.save();
}

OpenIdConfiguration _configuration(Uri baseUri) {
  return OpenIdConfiguration.fromJson(_discoveryDocument(baseUri));
}

Map<String, dynamic> _discoveryDocument(
  Uri baseUri, {
  bool includeEndSessionEndpoint = true,
}) {
  return {
    'issuer': baseUri.toString(),
    'jwks_uri': baseUri.resolve('/jwks').toString(),
    'authorization_endpoint': baseUri.resolve('/authorize').toString(),
    'token_endpoint': baseUri.resolve('/token').toString(),
    'userinfo_endpoint': baseUri.resolve('/userinfo').toString(),
    'revocation_endpoint': baseUri.resolve('/revoke').toString(),
    'registration_endpoint': baseUri.resolve('/register').toString(),
    if (includeEndSessionEndpoint)
      'end_session_endpoint': baseUri.resolve('/logout').toString(),
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

typedef _AuthorizeInteractiveHandler =
    Future<String?> Function({
      required String title,
      required String authorizationUrl,
      required String redirectUrl,
      required int popupWidth,
      required int popupHeight,
      required bool useWebRedirectLoop,
    });

class _FakeOpenIdConnectPlatform extends OpenIdConnectPlatform
    with MockPlatformInterfaceMixin {
  final Map<String, String> storage = <String, String>{};
  Map<Object?, Object?>? lastAuthorizeArguments;
  String? authorizeInteractiveResponse;
  String? processStartupResponse;
  _AuthorizeInteractiveHandler? authorizeInteractiveHandler;

  @override
  Future<String?> authorizeInteractive({
    required BuildContext context,
    required String title,
    required String authorizationUrl,
    required String redirectUrl,
    required int popupWidth,
    required int popupHeight,
    bool useWebRedirectLoop = false,
  }) async {
    lastAuthorizeArguments = <Object?, Object?>{
      'title': title,
      'authorizationUrl': authorizationUrl,
      'redirectUrl': redirectUrl,
      'popupWidth': popupWidth,
      'popupHeight': popupHeight,
      'useWebRedirectLoop': useWebRedirectLoop,
    };

    if (authorizeInteractiveHandler != null) {
      return authorizeInteractiveHandler!(
        title: title,
        authorizationUrl: authorizationUrl,
        redirectUrl: redirectUrl,
        popupWidth: popupWidth,
        popupHeight: popupHeight,
        useWebRedirectLoop: useWebRedirectLoop,
      );
    }

    return authorizeInteractiveResponse;
  }

  @override
  Future<String?> processStartup() async => processStartupResponse;

  @override
  Future<void> secureStorageDelete({required String key}) async {
    storage.remove(key);
  }

  @override
  Future<bool> secureStorageContainsKey({required String key}) async {
    return storage.containsKey(key);
  }

  @override
  Future<void> secureStorageInitialize() async {}

  @override
  Future<String?> secureStorageRead({required String key}) async {
    return storage[key];
  }

  @override
  Future<void> secureStorageWrite({
    required String key,
    required String value,
  }) async {
    storage[key] = value;
  }
}
