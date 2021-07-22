part of openidconnect_platform_interface;

const MethodChannel _channel =
    MethodChannel('plugins.concerti.io/openidconnect');

class MethodChannelOpenIdConnect extends OpenIdConnectPlatform {
  @override
  Future<String> authorizeInteractive(
      {required BuildContext context,
      required String title,
      required InteractiveAuthorizationPlatformRequest request}) async {
    final response = await _channel.invokeMethod<String>(
        'authorizeInteractive', request.toMap());

    if (response == null) throw UnsupportedError('The response was null.');

    return response;
  }
}
