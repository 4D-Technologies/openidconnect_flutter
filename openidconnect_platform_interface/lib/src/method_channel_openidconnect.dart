part of openidconnect_platform_interface;

const MethodChannel _channel =
    MethodChannel('plugins.concerti.io/openidconnect');

class MethodChannelOpenIdConnect extends OpenIdConnectPlatform {
  @override
  Future<String> authorizeInteractive({
    required String title,
    required String authorizationUrl,
    required String redirectUrl,
    required int popupWidth,
    required int popupHeight,
  }) async {
    final response =
        await _channel.invokeMethod<String>('authorizeInteractive', {
      "title": "title",
      "authorizationUrl": authorizationUrl,
      "redirectUrl": redirectUrl,
      "popupWidth": popupWidth,
      "popupHeight": popupHeight,
    });

    if (response == null) throw UnsupportedError('The response was null.');

    return response;
  }
}
