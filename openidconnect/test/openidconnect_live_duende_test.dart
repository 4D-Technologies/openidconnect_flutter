import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openidconnect/openidconnect.dart';
import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

const _discoveryUrl =
    'https://demo.duendesoftware.com/.well-known/openid-configuration';
const _interactiveClientId = 'interactive.public';
const _deviceClientId = 'device';
const _redirectUrl = 'openidconnect.example://callback';
const _scopes = ['openid', 'profile', 'email', 'offline_access'];

const _sondaDiscoveryUrl =
    'https://api.sondahub.com/.well-known/openid-configuration';
const _sondaClientId = 'sonda';
const _sondaClientSecret = 'probe-secret';
const _sondaScopes = ['openid', 'profile', 'email'];

void main() {
  final skipLive = Platform.environment['SKIP_LIVE_OIDC'] == '1';

  group('Duende demo live e2e', () {
    late OpenIdConfiguration configuration;

    setUp(() {
      // Flutter's test binding stubs dart:io HttpClient with HTTP 400.
      HttpOverrides.global = _LiveHttpOverrides();
    });

    setUpAll(() async {
      HttpOverrides.global = _LiveHttpOverrides();
      configuration = await OpenIdConnect.getConfiguration(_discoveryUrl);
    });

    test('loads discovery metadata', () {
      expect(configuration.issuer, 'https://demo.duendesoftware.com');
      expect(configuration.authorizationEndpoint, isNotEmpty);
      expect(configuration.tokenEndpoint, isNotEmpty);
      expect(configuration.userInfoEndpoint, isNotEmpty);
      expect(configuration.deviceAuthorizationEndpoint, isNotEmpty);
    });

    test(
      'password grant is rejected for the public interactive client',
      () async {
        await expectLater(
          OpenIdConnect.authorizePassword(
            request: PasswordAuthorizationRequest(
              clientId: _interactiveClientId,
              scopes: _scopes,
              userName: 'alice',
              password: 'alice',
              configuration: configuration,
              autoRefresh: false,
            ),
          ),
          throwsA(
            isA<HttpResponseException>().having(
              (error) => error.error,
              'error',
              'unauthorized_client',
            ),
          ),
        );
      },
    );

    test('device code request returns RFC 8628 verification URIs', () async {
      final response = await OpenIdConnect.authorizeDeviceGetDeviceCodeResponse(
        request: DeviceAuthorizationRequest(
          clientId: _deviceClientId,
          scopes: _scopes,
          audience: null,
          configuration: configuration,
        ),
      );

      expect(response.userCode, isNotEmpty);
      expect(response.deviceCode, isNotEmpty);
      expect(
        response.verificationUrl,
        contains('https://demo.duendesoftware.com/device'),
      );
      expect(response.verificationUrlComplete, contains(response.userCode));
    });

    test(
      'authorization-code + PKCE, userinfo, refresh, revoke, logout',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final originalPlatform = OpenIdConnectPlatform.instance;
        final fakePlatform = _FakeOpenIdConnectPlatform();
        OpenIdConnectPlatform.instance = fakePlatform;

        addTearDown(() {
          OpenIdConnectPlatform.instance = originalPlatform;
        });

        final request = await InteractiveAuthorizationRequest.create(
          clientId: _interactiveClientId,
          redirectUrl: _redirectUrl,
          scopes: _scopes,
          configuration: configuration,
          autoRefresh: false,
        );

        final browser = _DuendeLoginSession();
        addTearDown(browser.close);

        fakePlatform.authorizeInteractiveHandler =
            ({
              required String title,
              required String authorizationUrl,
              required String redirectUrl,
              required int popupWidth,
              required int popupHeight,
              required bool useWebRedirectLoop,
            }) {
              return browser.completeAuthorization(authorizationUrl);
            };

        final tokens = await OpenIdConnect.authorizeInteractive(
          context: _FakeBuildContext(),
          title: 'Duende e2e',
          request: request,
        );

        expect(tokens, isNotNull);
        expect(tokens!.accessToken, isNotEmpty);
        expect(tokens.idToken, isNotEmpty);
        expect(tokens.refreshToken, isNotEmpty);
        expect(tokens.state, request.state);

        final userInfo = await OpenIdConnect.getUserInfo(
          request: UserInfoRequest(
            accessToken: tokens.accessToken,
            configuration: configuration,
          ),
        );
        expect(userInfo['sub'], '1');

        final refreshed = await OpenIdConnect.refreshToken(
          request: RefreshRequest(
            clientId: _interactiveClientId,
            scopes: _scopes,
            refreshToken: tokens.refreshToken!,
            currentIdToken: tokens.idToken,
            configuration: configuration,
          ),
        );
        expect(refreshed.accessToken, isNotEmpty);
        expect(refreshed.idToken, isNotEmpty);

        await OpenIdConnect.revokeToken(
          request: RevokeTokenRequest(
            configuration: configuration,
            token: refreshed.refreshToken ?? tokens.refreshToken!,
            tokenType: TokenType.refreshToken,
            clientId: _interactiveClientId,
          ),
          useBasicAuth: false,
        );

        await OpenIdConnect.logout(
          request: LogoutRequest(
            idToken: refreshed.idToken,
            configuration: configuration,
          ),
        );
      },
    );
  }, skip: skipLive);

  group('SondaHub live password e2e', () {
    late OpenIdConfiguration configuration;

    setUp(() {
      HttpOverrides.global = _LiveHttpOverrides();
    });

    setUpAll(() async {
      HttpOverrides.global = _LiveHttpOverrides();
      configuration = await OpenIdConnect.getConfiguration(_sondaDiscoveryUrl);
    });

    test('advertises and accepts the password grant', () async {
      expect(configuration.issuer, 'https://api.sondahub.com');
      expect(configuration.grantTypesSupported, contains('password'));
      expect(configuration.tokenEndpoint, isNotEmpty);
      expect(configuration.userInfoEndpoint, isNotEmpty);

      final tokens = await OpenIdConnect.authorizePassword(
        request: PasswordAuthorizationRequest(
          clientId: _sondaClientId,
          clientSecret: _sondaClientSecret,
          scopes: _sondaScopes,
          userName: 'sonda',
          password: 'probe',
          configuration: configuration,
          autoRefresh: false,
        ),
      );

      expect(tokens.accessToken, isNotEmpty);
      expect(tokens.idToken, isNotEmpty);
      expect(tokens.refreshToken, isNotEmpty);

      final userInfo = await OpenIdConnect.getUserInfo(
        request: UserInfoRequest(
          accessToken: tokens.accessToken,
          configuration: configuration,
        ),
      );
      expect(userInfo['sub'], 'user_sonda');
      expect(userInfo['preferred_username'], 'sonda');

      final refreshed = await OpenIdConnect.refreshToken(
        request: RefreshRequest(
          clientId: _sondaClientId,
          clientSecret: _sondaClientSecret,
          scopes: _sondaScopes,
          refreshToken: tokens.refreshToken!,
          currentIdToken: tokens.idToken,
          configuration: configuration,
        ),
      );
      expect(refreshed.accessToken, isNotEmpty);
      expect(refreshed.idToken, isNotEmpty);

      await OpenIdConnect.revokeToken(
        request: RevokeTokenRequest(
          configuration: configuration,
          token: refreshed.refreshToken ?? tokens.refreshToken!,
          tokenType: TokenType.refreshToken,
          clientId: _sondaClientId,
          clientSecret: _sondaClientSecret,
        ),
        useBasicAuth: false,
      );

      await OpenIdConnect.logout(
        request: LogoutRequest(
          idToken: refreshed.idToken,
          configuration: configuration,
        ),
      );
    });
  }, skip: skipLive);
}

class _LiveHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    HttpOverrides.global = null;
    try {
      return HttpClient(context: context);
    } finally {
      HttpOverrides.global = this;
    }
  }
}

class _DuendeLoginSession {
  _DuendeLoginSession() {
    _client.userAgent = 'openidconnect_flutter-e2e';
  }

  final HttpClient _client = HttpClient();
  final Map<String, String> _cookies = {};

  Future<String> completeAuthorization(String authorizationUrl) async {
    var page = await _followToHtml(Uri.parse(authorizationUrl));
    final inputs = _inputValues(page.body);
    final action = _formAction(page.body, page.uri);
    final body = <String, String>{
      ...inputs,
      'Input.Username': 'alice',
      'Input.Password': 'alice',
      'Input.RememberLogin': 'false',
      'Input.Button': 'login',
    };

    page = await _request(action, method: 'POST', form: body);
    for (var i = 0; i < 8; i++) {
      final callback = _callbackFrom(page);
      if (callback != null) {
        return callback;
      }

      final next = _nextLocation(page);
      if (next == null) {
        throw StateError(
          'Duende login did not return a callback URL (HTTP ${page.statusCode} at ${page.uri}).',
        );
      }
      page = await _request(next);
    }

    throw StateError('Duende login exceeded redirect hops without a code.');
  }

  Future<_HttpPage> _followToHtml(Uri uri) async {
    var page = await _request(uri);
    for (var i = 0; i < 8; i++) {
      if (page.statusCode >= 200 &&
          page.statusCode < 300 &&
          page.body.contains('<form')) {
        return page;
      }
      final next = _nextLocation(page);
      if (next == null) {
        return page;
      }
      page = await _request(next);
    }
    return page;
  }

  Future<_HttpPage> _request(
    Uri uri, {
    String method = 'GET',
    Map<String, String>? form,
  }) async {
    final request = await _client.openUrl(method, uri);
    request.followRedirects = false;
    if (_cookies.isNotEmpty) {
      request.headers.set(
        HttpHeaders.cookieHeader,
        _cookies.entries
            .map((entry) => '${entry.key}=${entry.value}')
            .join('; '),
      );
    }
    if (form != null) {
      final encoded = Uri(queryParameters: form).query;
      request.headers.contentType = ContentType.parse(
        'application/x-www-form-urlencoded',
      );
      request.add(utf8.encode(encoded));
    }

    final response = await request.close();
    _storeCookies(response.headers);
    final body = await utf8.decodeStream(response);
    return _HttpPage(
      uri: uri,
      statusCode: response.statusCode,
      location: response.headers.value(HttpHeaders.locationHeader),
      body: body,
    );
  }

  void _storeCookies(HttpHeaders headers) {
    headers.forEach((name, values) {
      if (name.toLowerCase() != 'set-cookie') return;
      for (final value in values) {
        final pair = value.split(';').first;
        final separator = pair.indexOf('=');
        if (separator <= 0) continue;
        _cookies[pair.substring(0, separator)] = pair.substring(separator + 1);
      }
    });
  }

  String? _callbackFrom(_HttpPage page) {
    final location = page.location;
    if (location != null && location.startsWith(_redirectUrl)) {
      return location;
    }
    return null;
  }

  Uri? _nextLocation(_HttpPage page) {
    if (page.location != null && page.location!.isNotEmpty) {
      return page.uri.resolve(page.location!);
    }

    final refresh = RegExp(
      r'content="0;url=([^"]+)"',
      caseSensitive: false,
    ).firstMatch(page.body);
    if (refresh != null) {
      return page.uri.resolve(_unescape(refresh.group(1)!));
    }
    return null;
  }

  Map<String, String> _inputValues(String html) {
    final values = <String, String>{};
    for (final match in RegExp(
      r'<input\b[^>]*>',
      caseSensitive: false,
    ).allMatches(html)) {
      final tag = match.group(0)!;
      final name = RegExp(r'name="([^"]*)"').firstMatch(tag)?.group(1);
      if (name == null) continue;
      final value = RegExp(r'value="([^"]*)"').firstMatch(tag)?.group(1) ?? '';
      values[name] = _unescape(value);
    }
    return values;
  }

  Uri _formAction(String html, Uri pageUri) {
    final match = RegExp(
      r'<form\b[^>]*action="([^"]*)"',
      caseSensitive: false,
    ).firstMatch(html);
    if (match == null) {
      return pageUri;
    }
    return pageUri.resolve(_unescape(match.group(1)!));
  }

  String _unescape(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#x2F;', '/')
        .replaceAll('&#39;', "'");
  }

  void close() {
    _client.close(force: true);
  }
}

class _HttpPage {
  const _HttpPage({
    required this.uri,
    required this.statusCode,
    required this.location,
    required this.body,
  });

  final Uri uri;
  final int statusCode;
  final String? location;
  final String body;
}

class _FakeBuildContext implements BuildContext {
  @override
  bool get mounted => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

typedef _AuthorizeInteractiveHandler = Future<String?> Function({
  required String title,
  required String authorizationUrl,
  required String redirectUrl,
  required int popupWidth,
  required int popupHeight,
  required bool useWebRedirectLoop,
});

class _FakeOpenIdConnectPlatform extends OpenIdConnectPlatform
    with MockPlatformInterfaceMixin {
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
  }) {
    return authorizeInteractiveHandler!(
      title: title,
      authorizationUrl: authorizationUrl,
      redirectUrl: redirectUrl,
      popupWidth: popupWidth,
      popupHeight: popupHeight,
      useWebRedirectLoop: useWebRedirectLoop,
    );
  }

  @override
  Future<String?> processStartup() async => null;

  @override
  Future<void> secureStorageDelete({required String key}) async {}

  @override
  Future<bool> secureStorageContainsKey({required String key}) async => false;

  @override
  Future<void> secureStorageInitialize() async {}

  @override
  Future<String?> secureStorageRead({required String key}) async => null;

  @override
  Future<void> secureStorageWrite({
    required String key,
    required String value,
  }) async {}
}
