import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';

const _interactiveChannel = MethodChannel('plugins.concerti.io/openidconnect');
const _secureStorageChannel = MethodChannel(
  'plugins.concerti.io/openidconnect_secure_storage',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final storage = <String, String>{};

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_interactiveChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
    storage.clear();
  });

  test('authorizeInteractive forwards the provided title and arguments',
      () async {
    MethodCall? capturedCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_interactiveChannel, (call) async {
      capturedCall = call;
      return 'https://app.example.com/callback?code=abc';
    });

    final platform = MethodChannelOpenIdConnect();
    final result = await platform.authorizeInteractive(
      context: _FakeBuildContext(),
      title: 'Sign in',
      authorizationUrl: 'https://issuer.example.com/authorize',
      redirectUrl: 'com.example.app:/callback',
      popupWidth: 640,
      popupHeight: 480,
      useWebRedirectLoop: true,
    );

    expect(result, 'https://app.example.com/callback?code=abc');
    expect(capturedCall?.method, 'authorizeInteractive');
    expect(capturedCall?.arguments, {
      'title': 'Sign in',
      'authorizationUrl': 'https://issuer.example.com/authorize',
      'redirectUrl': 'com.example.app:/callback',
      'popupWidth': 640,
      'popupHeight': 480,
      'useWebRedirectLoop': true,
    });
  });

  test('processStartup delegates to the method channel', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_interactiveChannel, (call) async {
      expect(call.method, 'processStartup');
      return 'https://app.example.com/callback?code=startup';
    });

    final platform = MethodChannelOpenIdConnect();
    final result = await platform.processStartup();

    expect(result, 'https://app.example.com/callback?code=startup');
  });

  test('secure storage methods delegate to the secure storage channel',
      () async {
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
          throw UnimplementedError('Unexpected method ${call.method}');
      }
    });

    final platform = MethodChannelOpenIdConnect();
    await platform.secureStorageInitialize();
    await platform.secureStorageWrite(key: 'token', value: 'abc123');

    expect(await platform.secureStorageRead(key: 'token'), 'abc123');
    expect(await platform.secureStorageContainsKey(key: 'token'), isTrue);

    await platform.secureStorageDelete(key: 'token');

    expect(await platform.secureStorageContainsKey(key: 'token'), isFalse);
    expect(await platform.secureStorageRead(key: 'token'), isNull);
  });
}

class _FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
