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
  Int32 width,
  Int32 height,
  Pointer<NativeFunction<OidcWebAuthCompletionNative>> completion,
);

typedef _OidcWebAuthStart = void Function(
  Pointer<Utf8> authorizationUrl,
  Pointer<Utf8> redirectUrl,
  int width,
  int height,
  Pointer<NativeFunction<OidcWebAuthCompletionNative>> completion,
);

typedef _OidcWebAuthFreeNative = Void Function(Pointer<Utf8> value);
typedef _OidcWebAuthFree = void Function(Pointer<Utf8> value);

DynamicLibrary _openPluginLibrary() {
  if (!Platform.isWindows) {
    throw AuthenticationException(
      'The Windows WebView2 authentication session is only available on Windows.',
    );
  }
  return DynamicLibrary.open('openidconnect_windows_plugin.dll');
}

DynamicLibrary? _pluginLibrary;
DynamicLibrary get _library => _pluginLibrary ??= _openPluginLibrary();

_OidcWebAuthStart get _start {
  return _library.lookupFunction<_OidcWebAuthStartNative, _OidcWebAuthStart>(
    'oidc_windows_web_auth_start',
  );
}

_OidcWebAuthFree get _freeString {
  return _library.lookupFunction<_OidcWebAuthFreeNative, _OidcWebAuthFree>(
    'oidc_windows_web_auth_string_free',
  );
}

void _releaseNativeString(Pointer<Utf8> ptr) {
  if (ptr == nullptr) {
    return;
  }
  _freeString(ptr);
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

/// Starts the default Windows interactive login window (WebView2) via FFI.
Future<String> startWindowsWebView2Auth({
  required String authorizationUrl,
  required String redirectUrl,
  int popupWidth = 640,
  int popupHeight = 600,
}) {
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
      popupWidth,
      popupHeight,
      callable.nativeFunction,
    );
    nativeStartSucceeded = true;
  } on ArgumentError catch (error, stackTrace) {
    completeError(
      AuthenticationException(
        'Failed to load the Windows WebView2 FFI symbols. $error',
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
