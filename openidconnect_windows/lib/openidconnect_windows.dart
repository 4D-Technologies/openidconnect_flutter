// ignore_for_file: non_constant_identifier_names

import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/widgets.dart';
import 'package:native_authentication/native_authentication.dart';
import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';
import 'package:openidconnect_windows/src/native_authentication_support.dart';

const _credTypeGeneric = 1;
const _credPersistLocalMachine = 2;
const _errorNotFound = 1168;

final DynamicLibrary _advapi32 = DynamicLibrary.open('Advapi32.dll');
final DynamicLibrary _kernel32 = DynamicLibrary.open('Kernel32.dll');

final int Function(Pointer<Utf16>, int, int) _credDelete = _advapi32
    .lookupFunction<
      Int32 Function(Pointer<Utf16>, Uint32, Uint32),
      int Function(Pointer<Utf16>, int, int)
    >('CredDeleteW');

final int Function(Pointer<Utf16>, int, int, Pointer<Pointer<_Credential>>)
_credRead = _advapi32
    .lookupFunction<
      Int32 Function(
        Pointer<Utf16>,
        Uint32,
        Uint32,
        Pointer<Pointer<_Credential>>,
      ),
      int Function(Pointer<Utf16>, int, int, Pointer<Pointer<_Credential>>)
    >('CredReadW');

final int Function(Pointer<_Credential>, int) _credWrite = _advapi32
    .lookupFunction<
      Int32 Function(Pointer<_Credential>, Uint32),
      int Function(Pointer<_Credential>, int)
    >('CredWriteW');

final void Function(Pointer<Void>) _credFree = _advapi32
    .lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>(
      'CredFree',
    );

final int Function() _getLastError = _kernel32
    .lookupFunction<Uint32 Function(), int Function()>('GetLastError');

final class _FileTime extends Struct {
  @Uint32()
  external int dwLowDateTime;

  @Uint32()
  external int dwHighDateTime;
}

final class _Credential extends Struct {
  @Uint32()
  external int Flags;

  @Uint32()
  external int Type;

  external Pointer<Utf16> TargetName;

  external Pointer<Utf16> Comment;

  external _FileTime LastWritten;

  @Uint32()
  external int CredentialBlobSize;

  external Pointer<Uint8> CredentialBlob;

  @Uint32()
  external int Persist;

  @Uint32()
  external int AttributeCount;

  external Pointer<Void> Attributes;

  external Pointer<Utf16> TargetAlias;

  external Pointer<Utf16> UserName;
}

class OpenIdConnectWindows extends OpenIdConnectPlatform {
  static const _credentialNamePrefix = 'io.concerti.openidconnect.';

  OpenIdConnectWindows({NativeAuthentication? nativeAuthentication})
    : _nativeAuthentication = nativeAuthentication ?? NativeAuthentication();

  final NativeAuthentication _nativeAuthentication;

  static void registerWith() {
    OpenIdConnectPlatform.instance = OpenIdConnectWindows();
  }

  @override
  Future<String?> processStartup() {
    return Future.value(null);
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
  }) {
    return startNativeAuthenticationFlow(
      nativeAuthentication: _nativeAuthentication,
      authorizationUrl: authorizationUrl,
      redirectUrl: redirectUrl,
    );
  }

  String _storageName(String key) => '$_credentialNamePrefix$key';

  @override
  Future<void> secureStorageInitialize() => Future<void>.value();

  @override
  Future<void> secureStorageWrite({
    required String key,
    required String value,
  }) async {
    final valueBytes = Uint8List.fromList(utf8.encode(value));
    final blob = valueBytes.isEmpty
        ? nullptr
        : calloc<Uint8>(valueBytes.length);
    if (blob != nullptr) {
      blob.asTypedList(valueBytes.length).setAll(0, valueBytes);
    }

    final targetName = _storageName(key).toNativeUtf16(allocator: calloc);
    final userName = 'openidconnect'.toNativeUtf16(allocator: calloc);
    final credential = calloc<_Credential>()
      ..ref.Type = _credTypeGeneric
      ..ref.TargetName = targetName
      ..ref.Persist = _credPersistLocalMachine
      ..ref.UserName = userName
      ..ref.CredentialBlob = blob
      ..ref.CredentialBlobSize = valueBytes.length;

    try {
      final result = _credWrite(credential, 0);
      if (result == 0) {
        throw Exception(
          'Error writing secure storage value for $key: ${_getLastError()}',
        );
      }
    } finally {
      if (blob != nullptr) {
        calloc.free(blob);
      }
      calloc.free(credential);
      calloc.free(targetName);
      calloc.free(userName);
    }
  }

  @override
  Future<String?> secureStorageRead({required String key}) async {
    final credentialPointer = calloc<Pointer<_Credential>>();
    final targetName = _storageName(key).toNativeUtf16(allocator: calloc);

    try {
      final result = _credRead(
        targetName,
        _credTypeGeneric,
        0,
        credentialPointer,
      );

      if (result == 0) {
        final errorCode = _getLastError();
        if (errorCode == _errorNotFound) {
          return null;
        }
        throw Exception(
          'Error reading secure storage value for $key: $errorCode',
        );
      }

      final credential = credentialPointer.value.ref;
      if (credential.CredentialBlobSize == 0) {
        return '';
      }

      final bytes = Uint8List.fromList(
        credential.CredentialBlob.asTypedList(credential.CredentialBlobSize),
      );
      return utf8.decode(bytes);
    } finally {
      if (credentialPointer.value != nullptr) {
        _credFree(credentialPointer.value.cast<Void>());
      }
      calloc.free(credentialPointer);
      calloc.free(targetName);
    }
  }

  @override
  Future<void> secureStorageDelete({required String key}) async {
    final targetName = _storageName(key).toNativeUtf16(allocator: calloc);
    try {
      final result = _credDelete(targetName, _credTypeGeneric, 0);
      if (result == 0) {
        final errorCode = _getLastError();
        if (errorCode != _errorNotFound) {
          throw Exception(
            'Error deleting secure storage value for $key: $errorCode',
          );
        }
      }
    } finally {
      calloc.free(targetName);
    }
  }

  @override
  Future<bool> secureStorageContainsKey({required String key}) async {
    return await secureStorageRead(key: key) != null;
  }
}
