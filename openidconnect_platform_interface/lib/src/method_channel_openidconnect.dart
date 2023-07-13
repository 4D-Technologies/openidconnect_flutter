part of openidconnect_platform_interface;

const MethodChannel _channel =
    MethodChannel('plugins.concerti.io/openidconnect');

class MethodChannelOpenIdConnect extends OpenIdConnectPlatform {
  @override
  Future<String?> authorizeInteractive({
    required BuildContext context,
    required String title,
    required String authorizationUrl,
    required String redirectUrl,
    required int popupWidth,
    required int popupHeight,
    bool useWebRedirectLoop = false,
  }) =>
      _channel.invokeMethod<String>('authorizeInteractive', {
        "title": "title",
        "authorizationUrl": authorizationUrl,
        "redirectUrl": redirectUrl,
        "popupWidth": popupWidth,
        "popupHeight": popupHeight,
        "useWebRedirectLoop": useWebRedirectLoop,
      });

  @override
  Future<String?> processStartup() =>
      _channel.invokeMethod<String>("processStartup");
}
