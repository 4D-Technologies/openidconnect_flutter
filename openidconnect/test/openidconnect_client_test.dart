
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
