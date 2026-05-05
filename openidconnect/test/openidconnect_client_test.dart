import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openidconnect/openidconnect.dart';
import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';

const _secureStorageChannel = MethodChannel(
  'plugins.concerti.io/openidconnect_secure_storage',
);
const _testIdToken =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJjbGllbnQtdGVzdC1zdWJqZWN0IiwibmFtZSI6IkNsaWVudCBUZXN0ZXIiLCJpYXQiOjE1MTYyMzkwMjJ9.c2ln';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final storage = <String, String>{};
  String? writeFailureKey;
  String? deleteFailureKey;

  setUp(() {
    storage.clear();
    writeFailureKey = null;
    deleteFailureKey = null;

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
              if (key == writeFailureKey) {
                throw PlatformException(
                  code: 'secure_storage_error',
                  message: 'write failed for $key',
                );
              }
              storage[key!] = arguments['value'] as String;
              return null;
            case 'read':
              return storage[key];
            case 'delete':
              if (key == deleteFailureKey) {
                throw PlatformException(
                  code: 'secure_storage_error',
                  message: 'delete failed for $key',
                );
              }
              storage.remove(key);
              return null;
            case 'containsKey':
              return storage.containsKey(key);
            default:
              throw UnimplementedError('Unhandled method ${call.method}');
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
  });

  group('OpenIdConnectClient', () {
    test('reports not logged in when storage is empty', () async {
      final client = await OpenIdConnectClient.create(
        discoveryDocumentUrl: 'https://issuer.example.com/.well-known/openid',
        clientId: 'client-id',
        encryptionKey: 'unused',
        autoRefresh: false,
      );
      addTearDown(client.dispose);

      expect(client.initializationComplete, isTrue);
      expect(client.identity, isNull);
      expect(client.currentEvent, const AuthEvent(AuthEventTypes.NotLoggedIn));
      expect(await client.verifyToken(), isFalse);
      expect(await client.isLoggedIn(), isFalse);
    });

    test('loads a persisted identity and reports success', () async {
      await _saveIdentity(
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      );

      final client = await OpenIdConnectClient.create(
        discoveryDocumentUrl: 'https://issuer.example.com/.well-known/openid',
        clientId: 'client-id',
        encryptionKey: 'unused',
        autoRefresh: false,
      );
      addTearDown(client.dispose);

      expect(client.identity, isNotNull);
      expect(client.currentEvent, const AuthEvent(AuthEventTypes.Success));
      expect(await client.isLoggedIn(), isTrue);
    });

    test(
      'treats expired persisted identities as logged out when auto refresh is disabled',
      () async {
        await _saveIdentity(
          expiresAt: DateTime.now().toUtc().subtract(
            const Duration(minutes: 1),
          ),
        );

        final client = await OpenIdConnectClient.create(
          discoveryDocumentUrl: 'https://issuer.example.com/.well-known/openid',
          clientId: 'client-id',
          encryptionKey: 'unused',
          autoRefresh: false,
        );
        addTearDown(client.dispose);

        expect(
          client.currentEvent,
          const AuthEvent(AuthEventTypes.NotLoggedIn),
        );
        expect(await client.isLoggedIn(), isFalse);
      },
    );

    test('clears persisted identity data', () async {
      await _saveIdentity(
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      );

      final client = await OpenIdConnectClient.create(
        discoveryDocumentUrl: 'https://issuer.example.com/.well-known/openid',
        clientId: 'client-id',
        encryptionKey: 'unused',
        autoRefresh: false,
      );
      addTearDown(client.dispose);

      await client.clearIdentity();

      expect(client.identity, isNull);
      expect(await OpenIdIdentity.load(), isNull);
    });

    test('loads isolated identities for different tenant ids', () async {
      await _saveIdentity(
        accessToken: 'tenant-a-access-token',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        tenantId: 'tenant-a',
      );
      await _saveIdentity(
        accessToken: 'tenant-b-access-token',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        tenantId: 'tenant-b',
      );

      final tenantAClient = await OpenIdConnectClient.create(
        discoveryDocumentUrl: 'https://issuer.example.com/.well-known/openid',
        clientId: 'client-id',
        encryptionKey: 'unused',
        tenantId: 'tenant-a',
        autoRefresh: false,
      );
      final tenantBClient = await OpenIdConnectClient.create(
        discoveryDocumentUrl: 'https://issuer.example.com/.well-known/openid',
        clientId: 'client-id',
        encryptionKey: 'unused',
        tenantId: 'tenant-b',
        autoRefresh: false,
      );
      addTearDown(tenantAClient.dispose);
      addTearDown(tenantBClient.dispose);

      expect(tenantAClient.identity?.accessToken, 'tenant-a-access-token');
      expect(tenantBClient.identity?.accessToken, 'tenant-b-access-token');
    });

    test('clearIdentity clears only the matching tenant namespace', () async {
      await _saveIdentity(
        accessToken: 'tenant-a-access-token',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        tenantId: 'tenant-a',
      );
      await _saveIdentity(
        accessToken: 'tenant-b-access-token',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        tenantId: 'tenant-b',
      );

      final tenantAClient = await OpenIdConnectClient.create(
        discoveryDocumentUrl: 'https://issuer.example.com/.well-known/openid',
        clientId: 'client-id',
        encryptionKey: 'unused',
        tenantId: 'tenant-a',
        autoRefresh: false,
      );
      addTearDown(tenantAClient.dispose);

      await tenantAClient.clearIdentity();

      expect(await OpenIdIdentity.load(tenantId: 'tenant-a'), isNull);
      expect(await OpenIdIdentity.load(tenantId: 'tenant-b'), isNotNull);
    });

    test('publishes reported errors to the event stream', () async {
      final client = await OpenIdConnectClient.create(
        discoveryDocumentUrl: 'https://issuer.example.com/.well-known/openid',
        clientId: 'client-id',
        encryptionKey: 'unused',
        autoRefresh: false,
      );
      addTearDown(client.dispose);

      final nextEvent = client.changes.firstWhere(
        (event) => event.type == AuthEventTypes.Error,
      );
      client.reportError('boom');

      expect(
        await nextEvent,
        isA<AuthEvent>()
            .having((event) => event.type, 'type', AuthEventTypes.Error)
            .having((event) => event.message, 'message', 'boom'),
      );
      expect(
        client.currentEvent,
        isA<AuthEvent>()
            .having((event) => event.type, 'type', AuthEventTypes.Error)
            .having((event) => event.message, 'message', 'boom'),
      );
    });

    test('executes queued requests when the identity is valid', () async {
      await _saveIdentity(
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      );

      final client = await OpenIdConnectClient.create(
        discoveryDocumentUrl: 'https://issuer.example.com/.well-known/openid',
        clientId: 'client-id',
        encryptionKey: 'unused',
        autoRefresh: false,
      );
      addTearDown(client.dispose);

      var executed = false;
      await client.sendRequests(
        () => <Future<void>>[
          Future<void>.sync(() {
            executed = true;
          }),
        ],
      );

      expect(executed, isTrue);
    });

    test('throws when queued requests run without an identity', () async {
      final client = await OpenIdConnectClient.create(
        discoveryDocumentUrl: 'https://issuer.example.com/.well-known/openid',
        clientId: 'client-id',
        encryptionKey: 'unused',
        autoRefresh: false,
      );
      addTearDown(client.dispose);

      await expectLater(
        () async =>
            client.sendRequests(() => <Future<void>>[Future<void>.value()]),
        throwsA(isA<AuthenticationException>()),
      );
    });

    test('dispose cancels auto renew state cleanly', () async {
      await _saveIdentity(
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 2)),
      );

      final client = await OpenIdConnectClient.create(
        discoveryDocumentUrl: 'https://issuer.example.com/.well-known/openid',
        clientId: 'client-id',
        encryptionKey: 'unused',
        autoRefresh: true,
      );

      expect(client.currentEvent, const AuthEvent(AuthEventTypes.Success));
      expect(() => client.dispose(), returnsNormally);
    });

    test(
      'loginWithPassword preserves the original storage failure when cleanup also fails',
      () async {
        final baseUri = Uri.parse('https://issuer.example.com');

        writeFailureKey = 'ID_TOKEN';
        deleteFailureKey = 'ACCESS_TOKEN';

        final client = await OpenIdConnectClient.create(
          discoveryDocumentUrl: baseUri
              .resolve('/.well-known/openid-configuration')
              .toString(),
          clientId: 'client-id',
          clientSecret: 'secret',
          encryptionKey: 'unused',
          autoRefresh: false,
        );
        addTearDown(client.dispose);

        client.configuration = OpenIdConfiguration.fromJson({
          'issuer': baseUri.toString(),
          'jwks_uri': baseUri.resolve('/jwks').toString(),
          'authorization_endpoint': baseUri.resolve('/authorize').toString(),
          'token_endpoint': baseUri.resolve('/token').toString(),
          'response_types_supported': ['code'],
          'response_modes_supported': ['query'],
          'token_endpoint_auth_methods_supported': ['client_secret_basic'],
          'id_token_signing_alg_values_supported': ['RS256'],
          'subject_types_supported': ['public'],
          'code_challenge_methods_supported': ['S256'],
          'request_uri_parameter_supported': false,
        });

        await HttpOverrides.runZoned(() async {
          await expectLater(
            () =>
                client.loginWithPassword(userName: 'alice', password: 'secret'),
            throwsA(
              isA<AuthenticationException>().having(
                (error) => error.toString(),
                'message',
                contains('write failed for ID_TOKEN'),
              ),
            ),
          );
        }, createHttpClient: (_) => _FakeTokenHttpClient());

        expect(client.currentEvent?.type, AuthEventTypes.Error);
        expect(
          client.currentEvent?.message,
          contains('write failed for ID_TOKEN'),
        );
        expect(client.identity, isNull);
      },
    );
  });
}

Future<void> _saveIdentity({
  required DateTime expiresAt,
  String accessToken = 'access-token',
  String? tenantId,
}) {
  return OpenIdIdentity(
    accessToken: accessToken,
    expiresAt: expiresAt,
    idToken: _testIdToken,
    tokenType: 'Bearer',
    refreshToken: 'refresh-token',
  ).save(tenantId: tenantId);
}

class _FakeTokenHttpClient extends Fake implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return _FakeTokenHttpClientRequest(method: method, uri: url);
  }

  @override
  void close({bool force = false}) {}
}

class _FakeTokenHttpClientRequest extends Fake implements HttpClientRequest {
  _FakeTokenHttpClientRequest({required this.method, required this.uri});

  @override
  final String method;

  @override
  final Uri uri;

  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  bool persistentConnection = true;

  @override
  int contentLength = -1;

  final BytesBuilder _body = BytesBuilder();

  @override
  void add(List<int> data) {
    _body.add(data);
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      _body.add(chunk);
    }
  }

  @override
  Future<HttpClientResponse> close() async {
    expect(method, 'POST');
    expect(uri.path, '/token');

    final body = utf8.decode(_body.takeBytes());
    final values = Uri.splitQueryString(body);
    expect(values['grant_type'], 'password');
    expect(values['username'], 'alice');
    expect(values['password'], 'secret');
    expect(values['client_id'], 'client-id');

    return _FakeTokenHttpClientResponse(
      jsonEncode({
        'access_token': 'access-token',
        'token_type': 'Bearer',
        'expires_in': 3600,
        'id_token': _testIdToken,
        'refresh_token': 'refresh-token',
      }),
    );
  }
}

class _FakeTokenHttpClientResponse extends Fake implements HttpClientResponse {
  _FakeTokenHttpClientResponse(String body)
    : _bytes = utf8.encode(body),
      headers = _FakeHttpHeaders(contentType: ContentType.json);

  final List<int> _bytes;

  @override
  final HttpHeaders headers;

  @override
  int get statusCode => HttpStatus.ok;

  @override
  int get contentLength => _bytes.length;

  @override
  bool get persistentConnection => false;

  @override
  X509Certificate? get certificate => null;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  List<RedirectInfo> get redirects => const <RedirectInfo>[];

  @override
  bool get isRedirect => false;

  @override
  String get reasonPhrase => 'OK';

  @override
  Future<Socket> detachSocket() {
    throw UnsupportedError('detachSocket is not supported in tests');
  }

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_bytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class _FakeHttpHeaders extends Fake implements HttpHeaders {
  _FakeHttpHeaders({ContentType? contentType}) : _contentType = contentType;

  final Map<String, List<String>> _values = <String, List<String>>{};
  ContentType? _contentType;

  @override
  ContentType? get contentType => _contentType;

  @override
  set contentType(ContentType? value) {
    _contentType = value;
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _values[name.toLowerCase()] = <String>[value.toString()];
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _values.forEach(action);
  }

  @override
  String? value(String name) {
    final values = _values[name.toLowerCase()];
    if (values == null || values.isEmpty) {
      return null;
    }

    return values.single;
  }
}
