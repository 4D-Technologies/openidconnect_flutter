import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:native_authentication/native_authentication.dart';
import 'package:openidconnect_linux/src/native_authentication_support.dart';
import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';

const MethodChannel _secureStorageChannel = MethodChannel(
  'plugins.concerti.io/openidconnect_secure_storage',
);

class OpenIdConnectLinux extends OpenIdConnectPlatform {
  OpenIdConnectLinux({NativeAuthentication? nativeAuthentication})
    : _nativeAuthentication = nativeAuthentication ?? NativeAuthentication();

  final NativeAuthentication _nativeAuthentication;

  static void registerWith() {
    OpenIdConnectPlatform.instance = OpenIdConnectLinux();
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
}
