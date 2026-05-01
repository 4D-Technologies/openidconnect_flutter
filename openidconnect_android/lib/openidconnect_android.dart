import 'package:flutter/widgets.dart';
import 'package:native_authentication/native_authentication.dart';
import 'package:openidconnect_android/src/native_authentication_support.dart';
import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';

class OpenIdConnectAndroid extends OpenIdConnectPlatform {
  OpenIdConnectAndroid({NativeAuthentication? nativeAuthentication})
    : _nativeAuthentication = nativeAuthentication ?? NativeAuthentication();

  final NativeAuthentication _nativeAuthentication;

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
      nativeAuthentication: _nativeAuthentication,
      authorizationUrl: authorizationUrl,
      redirectUrl: redirectUrl,
    );
  }

  @override
  Future<String?> processStartup() => Future<String?>.value(null);
}
