import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:openidconnect_android/src/native_authentication_support.dart';
import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';

const MethodChannel _secureStorageChannel = MethodChannel(
  'plugins.concerti.io/openidconnect_secure_storage',
);
const MethodChannel _authenticationChannel = MethodChannel(
  'plugins.concerti.io/openidconnect_android_auth',
);

class OpenIdConnectAndroid extends OpenIdConnectPlatform {
  OpenIdConnectAndroid({
    AndroidNativeAuthenticationInvoker? invokeNativeAuthentication,
  }) : _invokeNativeAuthentication =
           invokeNativeAuthentication ?? _defaultNativeAuthenticationInvoker;

  final AndroidNativeAuthenticationInvoker _invokeNativeAuthentication;

  static void registerWith() {
    OpenIdConnectPlatform.instance = OpenIdConnectAndroid();
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
      authorizationUrl: authorizationUrl,
      redirectUrl: redirectUrl,
      invokeNativeAuthentication: _invokeNativeAuthentication,
    );
  }

  @override
  Future<String?> processStartup() => Future<String?>.value(null);

  @override
  Future<void> secureStorageInitialize() {
    return _secureStorageChannel.invokeMethod<void>('initialize');
  }

  @override
  Future<void> secureStorageWrite({
    required String key,
    required String value,
  }) {
    return _secureStorageChannel.invokeMethod<void>('write', {
      'key': key,
      'value': value,
    });
  }

  @override
  Future<String?> secureStorageRead({required String key}) {
    return _secureStorageChannel.invokeMethod<String>('read', {'key': key});
  }

  @override
  Future<void> secureStorageDelete({required String key}) {
    return _secureStorageChannel.invokeMethod<void>('delete', {'key': key});
  }

  @override
  Future<bool> secureStorageContainsKey({required String key}) async {
    return await _secureStorageChannel.invokeMethod<bool>('containsKey', {
          'key': key,
        }) ??
        false;
  }

  static Future<String?> _defaultNativeAuthenticationInvoker({
    required String authorizationUrl,
    required String redirectUrl,
    bool preferEphemeralSession = false,
  }) {
    return _authenticationChannel.invokeMethod<String>('authorizeInteractive', {
      'authorizationUrl': authorizationUrl,
      'redirectUrl': redirectUrl,
      'preferEphemeralSession': preferEphemeralSession,
    });
  }
}
