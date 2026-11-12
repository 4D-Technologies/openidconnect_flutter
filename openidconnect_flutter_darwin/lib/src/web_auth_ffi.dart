import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';

typedef OidcWebAuthCompletionNative = Void Function(
  Pointer<Utf8> callbackUrl,
  Pointer<Utf8> error,
  Int32 cancelled,
);

typedef _OidcWebAuthStartNative = Void Function(
  Pointer<Utf8> authorizationUrl,
  Pointer<Utf8> redirectUrl,
  Int32 preferEphemeral,
  Pointer<NativeFunction<OidcWebAuthCompletionNative>> completion,
);

typedef _OidcWebAuthStart = void Function(
  Pointer<Utf8> authorizationUrl,
  Pointer<Utf8> redirectUrl,
  int preferEphemeral,
  Pointer<NativeFunction<OidcWebAuthCompletionNative>> completion,
);

typedef _OidcWebAuthCancelNative = Void Function();
typedef _OidcWebAuthCancel = void Function();

typedef _OidcWebAuthFreeNative = Void Function(Pointer<Utf8> value);
typedef _OidcWebAuthFree = void Function(Pointer<Utf8> value);

DynamicLibrary get _processLibrary => DynamicLibrary.process();

_OidcWebAuthStart get _start {
  return _processLibrary
      .lookupFunction<_OidcWebAuthStartNative, _OidcWebAuthStart>(
        'oidc_web_auth_start',
      );
}

_OidcWebAuthCancel get _cancel {
  return _processLibrary
      .lookupFunction<_OidcWebAuthCancelNative, _OidcWebAuthCancel>(
        'oidc_web_auth_cancel',
      );
}

_OidcWebAuthFree get _freeString {
  return _processLibrary
      .lookupFunction<_OidcWebAuthFreeNative, _OidcWebAuthFree>(
        'oidc_web_auth_string_free',
      );
}

void _releaseNativeString(Pointer<Utf8> ptr) {
  if (ptr == nullptr) {
    return;
  }
  try {
    _freeString(ptr);
  } on ArgumentError {
    malloc.free(ptr);
  }
}

String? _takeNativeString(Pointer<Utf8> ptr) {
  if (ptr == nullptr) {
    return null;
  }
  try {
    return ptr.toDartString();
  } finally {
    _releaseNativeString(ptr);
  }
}

/// Starts `ASWebAuthenticationSession` on iOS and macOS through the in-plugin
/// C ABI.
Future<String> startDarwinWebAuthSession({
  required String authorizationUrl,
  required String redirectUrl,
  bool preferEphemeralSession = false,
}) {
  if (!Platform.isIOS && !Platform.isMacOS) {
    throw AuthenticationException(
      'ASWebAuthenticationSession is only available on iOS and macOS.',
    );
  }

  final completer = Completer<String>();
  NativeCallable<OidcWebAuthCompletionNative>? callable;
  final authorizationUrlPtr = authorizationUrl.toNativeUtf8(allocator: calloc);
  final redirectUrlPtr = redirectUrl.toNativeUtf8(allocator: calloc);
  var nativeStartSucceeded = false;
  var buffersReleased = false;

  void completeError(Object error, [StackTrace? stackTrace]) {
    if (!completer.isCompleted) {
      completer.completeError(error, stackTrace);
    }
  }

  void releaseNativeBuffers() {
    if (buffersReleased) {
      return;
    }
    buffersReleased = true;
    calloc.free(authorizationUrlPtr);
    calloc.free(redirectUrlPtr);
  }

  callable = NativeCallable<OidcWebAuthCompletionNative>.listener((
    Pointer<Utf8> callbackUrl,
    Pointer<Utf8> error,
    int cancelled,
  ) {
    try {
      final errorMessage = _takeNativeString(error);
      final callback = _takeNativeString(callbackUrl);
      if (cancelled != 0) {
        completeError(AuthenticationException(ERROR_USER_CLOSED));
        return;
      }
      if (errorMessage != null && errorMessage.isNotEmpty) {
        completeError(AuthenticationException(errorMessage));
        return;
      }
      if (callback == null || callback.isEmpty) {
        completeError(
          AuthenticationException(
            'Native authentication completed without a redirect URL.',
          ),
        );
        return;
      }
      if (!completer.isCompleted) {
        completer.complete(callback);
      }
    } finally {
      releaseNativeBuffers();
      callable?.close();
    }
  });

  try {
    _start(
      authorizationUrlPtr,
      redirectUrlPtr,
      preferEphemeralSession ? 1 : 0,
      callable.nativeFunction,
    );
    nativeStartSucceeded = true;
  } on ArgumentError catch (error, stackTrace) {
    completeError(
      AuthenticationException(
        'Failed to load the Darwin ASWebAuthenticationSession FFI symbols. $error',
      ),
      stackTrace,
    );
  } catch (error, stackTrace) {
    completeError(error, stackTrace);
  } finally {
    if (!nativeStartSucceeded) {
      releaseNativeBuffers();
      callable.close();
    }
  }

  return completer.future;
}

/// Cancels an in-flight Apple authentication session, if one exists.
void cancelDarwinWebAuthSession() {
  if (!Platform.isIOS && !Platform.isMacOS) {
    return;
  }
  try {
    _cancel();
  } on ArgumentError {
    // The native plugin is not linked into this process.
  }
}
