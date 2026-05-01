part of openidconnect_platform_interface;

const MethodChannel _channel =
    MethodChannel('plugins.concerti.io/openidconnect');
const MethodChannel _secureStorageChannel = MethodChannel(
  'plugins.concerti.io/openidconnect_secure_storage',
);

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
        "title": title,
        "authorizationUrl": authorizationUrl,
        "redirectUrl": redirectUrl,
        "popupWidth": popupWidth,
        "popupHeight": popupHeight,
        "useWebRedirectLoop": useWebRedirectLoop,
      });

  @override
  Future<String?> processStartup() =>
      _channel.invokeMethod<String>("processStartup");

  @override
  Future<void> secureStorageInitialize() async {
    await _secureStorageChannel.invokeMethod<void>('initialize');
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
