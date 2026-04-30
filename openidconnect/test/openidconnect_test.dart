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
  // test('adds one to input values', () {
  //   final calculator = Calculator();
  //   expect(calculator.addOne(2), 3);
  //   expect(calculator.addOne(-7), -6);
  //   expect(calculator.addOne(0), 1);
  // });
}
