import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';
import 'package:openidconnect_web/openidconnect_web.dart';
import 'package:web/web.dart' as html;

const _storagePrefix = 'openidconnect_secure_storage.';
const _masterKeyName = '${_storagePrefix}master_key';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OpenIdConnectWeb plugin;

  setUp(() {
    plugin = OpenIdConnectWeb();
    _clearPrefixedStorage();
  });

  tearDown(_clearPrefixedStorage);

  test('registers web implementation', () {
    OpenIdConnectPlatform.instance = OpenIdConnectWeb();

    expect(OpenIdConnectPlatform.instance, isA<OpenIdConnectWeb>());
  });

  test('write and read round-trip a stored value', () async {
    await plugin.secureStorageInitialize();
    await plugin.secureStorageWrite(key: 'ACCESS_TOKEN', value: 'secret-value');

    expect(await plugin.secureStorageRead(key: 'ACCESS_TOKEN'), 'secret-value');
  });

  test(
    'importKey rejection with a WebCrypto DOMException resets prefixed storage',
    () async {
      final storage = html.window.localStorage;
      storage.setItem(
        _masterKeyName,
        base64Encode(Uint8List.fromList([1, 2, 3])),
      );
      storage.setItem('${_storagePrefix}ACCESS_TOKEN', 'stale-ciphertext');
      storage.setItem('${_storagePrefix}ID_TOKEN', 'stale-id-token');

      await plugin.secureStorageInitialize();

      expect(storage.getItem('${_storagePrefix}ACCESS_TOKEN'), isNull);
      expect(storage.getItem('${_storagePrefix}ID_TOKEN'), isNull);

      final masterKey = storage.getItem(_masterKeyName);
      expect(masterKey, isNotNull);
      expect(base64Decode(masterKey!).length, 32);

      await plugin.secureStorageWrite(key: 'ACCESS_TOKEN', value: 'new-token');
      expect(await plugin.secureStorageRead(key: 'ACCESS_TOKEN'), 'new-token');
    },
  );

  test('decrypt rejection with a WebCrypto DOMException makes read return null', () async {
    await plugin.secureStorageInitialize();

    html.window.localStorage.setItem(
      '${_storagePrefix}ACCESS_TOKEN',
      '${base64Encode(Uint8List(12))}.'
          '${base64Encode(Uint8List.fromList(List<int>.generate(32, (i) => i)))}',
    );

    expect(await plugin.secureStorageRead(key: 'ACCESS_TOKEN'), isNull);
  });
}

List<String> _prefixedKeys() {
  final storage = html.window.localStorage;
  final keys = <String>[];
  for (var i = 0; i < storage.length; i++) {
    final key = storage.key(i);
    if (key != null && key.startsWith(_storagePrefix)) {
      keys.add(key);
    }
  }
  return keys;
}

void _clearPrefixedStorage() {
  for (final key in _prefixedKeys()) {
    html.window.localStorage.removeItem(key);
  }
}
