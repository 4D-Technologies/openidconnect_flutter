import 'dart:async';
import 'dart:convert';
import 'dart:js_interop' as js_interop;
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as html;

// In order to *not* need this ignore, consider extracting the "web" version
// of your plugin as a separate package, instead of inlining it in the same
// package as the core of your plugin.
// ignore: avoid_web_libraries_in_flutter
import 'package:flutter/widgets.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';

/// A web implementation of the OpenidconnectWeb plugin.
class OpenIdConnectWeb extends OpenIdConnectPlatform {
  static final _secureStorage = _OpenIdConnectWebSecureStorage();

  static void registerWith(Registrar registrar) {
    OpenIdConnectPlatform.instance = OpenIdConnectWeb();
  }

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
    if (useWebRedirectLoop) {
      const authDestinationKey = "openidconnect_auth_destination_url";
      html.window.sessionStorage
          .setItem(authDestinationKey, html.window.location.toString());
      html.window.location.assign(authorizationUrl);

      // Same-tab redirect flows intentionally hand control to the browser and
      // resume via processStartup/OpenIdConnectClient.create() after the app is
      // loaded again on the callback page.
      return Completer<String?>().future;
    }

    final top = (html.window.outerHeight - popupHeight) / 2 +
        (html.window.screen.availHeight);
    final left = (html.window.outerWidth - popupWidth) / 2 +
        (html.window.screen.availWidth);

    var options =
        'width=$popupWidth,height=$popupHeight,toolbar=no,location=no,directories=no,status=no,menubar=no,copyhistory=no&top=$top,left=$left';

    final child = html.window.open(
      authorizationUrl,
      "open_id_connect_authentication",
      options,
    );

    final c = Completer<String>();
    html.window.onMessage.first.then((event) {
      final url = event.data.toString();
      c.complete(url);
      child?.close();
    });

    return c.future;
  }

  @override
  Future<String?> processStartup() async {
    const authResponseKey = "openidconnect_auth_response_info";

    final url = html.window.sessionStorage.getItem(authResponseKey);
    html.window.sessionStorage.removeItem(authResponseKey);

    return url;
  }

  @override
  Future<void> secureStorageInitialize() => _secureStorage.initialize();

  @override
  Future<void> secureStorageWrite({
    required String key,
    required String value,
  }) =>
      _secureStorage.write(key: key, value: value);

  @override
  Future<String?> secureStorageRead({required String key}) =>
      _secureStorage.read(key: key);

  @override
  Future<void> secureStorageDelete({required String key}) =>
      _secureStorage.delete(key: key);

  @override
  Future<bool> secureStorageContainsKey({required String key}) =>
      _secureStorage.containsKey(key: key);
}

class _OpenIdConnectWebSecureStorage {
  static const _storagePrefix = 'openidconnect_secure_storage';
  static const _masterKeyName = '$_storagePrefix.master_key';

  html.Crypto get _crypto {
    if (html.window.isSecureContext) {
      return html.window.crypto;
    }

    throw UnsupportedError(
      'OpenIdConnect web secure storage requires a secure context.',
    );
  }

  html.Storage get _storage => html.window.localStorage;

  String _entryKey(String key) => '$_storagePrefix.$key';

  Future<void> initialize() async {
    await _getOrCreateMasterKey();
  }

  Future<bool> containsKey({required String key}) async {
    return _storage.has(_entryKey(key));
  }

  Future<void> delete({required String key}) async {
    _storage.removeItem(_entryKey(key));
  }

  Future<String?> read({required String key}) async {
    final encryptedValue = _storage.getItem(_entryKey(key));
    if (encryptedValue == null) {
      return null;
    }

    try {
      final parts = encryptedValue.split('.');
      if (parts.length != 2) {
        return null;
      }

      final iv = base64Decode(parts[0]);
      final ciphertext = base64Decode(parts[1]);
      final keyHandle = await _getOrCreateMasterKey();

      final decrypted = await _crypto.subtle
          .decrypt(
            _algorithm(iv),
            keyHandle,
            Uint8List.fromList(ciphertext).toJS,
          )
          .toDart;

      return utf8.decode(
        (decrypted! as js_interop.JSArrayBuffer).toDart.asUint8List(),
      );
    } on Exception catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('$error');
        debugPrintStack(stackTrace: stackTrace);
      }
      return null;
    }
  }

  Future<void> write({required String key, required String value}) async {
    final iv =
        (_crypto.getRandomValues(Uint8List(12).toJS) as js_interop.JSUint8Array)
            .toDart;
    final keyHandle = await _getOrCreateMasterKey();
    final encrypted = await _crypto.subtle
        .encrypt(
          _algorithm(iv),
          keyHandle,
          Uint8List.fromList(utf8.encode(value)).toJS,
        )
        .toDart;

    _storage.setItem(
      _entryKey(key),
      '${base64Encode(iv)}.'
      '${base64Encode((encrypted! as js_interop.JSArrayBuffer).toDart.asUint8List())}',
    );
  }

  js_interop.JSAny _algorithm(Uint8List iv) {
    return {
      'name': 'AES-GCM',
      'length': 256,
      'iv': iv,
    }.jsify()!;
  }

  Future<html.CryptoKey> _getOrCreateMasterKey() async {
    if (_storage.has(_masterKeyName)) {
      final rawKey = base64Decode(_storage.getItem(_masterKeyName)!);
      return _crypto.subtle
          .importKey(
            'raw',
            rawKey.toJS,
            _algorithm(Uint8List(12)),
            false,
            _cryptoKeyUsages.toJS,
          )
          .toDart;
    }

    final generated = (await _crypto.subtle
        .generateKey(_algorithm(Uint8List(12)), true, _cryptoKeyUsages.toJS)
        .toDart)! as html.CryptoKey;
    final exported = await _crypto.subtle.exportKey('raw', generated).toDart;
    _storage.setItem(
      _masterKeyName,
      base64Encode(
        (exported! as js_interop.JSArrayBuffer).toDart.asUint8List(),
      ),
    );
    return generated;
  }
}

extension on List<String> {
  js_interop.JSArray<js_interop.JSString> get toJS => [
        ...map((entry) => entry.toJS),
      ].toJS;
}

const _cryptoKeyUsages = <String>['encrypt', 'decrypt'];
