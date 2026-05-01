import 'package:native_authentication/native_authentication.dart';
import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';

CallbackType callbackTypeForRedirectUrl(String redirectUrl) {
  final uri = Uri.parse(redirectUrl);
  final path = uri.path.isEmpty ? '/*' : uri.path;

  if (uri.scheme == 'http') {
    if (uri.host != 'localhost') {
      throw StateError(
        'Native interactive authentication only supports http://localhost callbacks for HTTP redirect URLs. Received: $redirectUrl',
      );
    }

    return CallbackTypeLocalhost(port: uri.hasPort ? uri.port : 0, path: path);
  }

  if (uri.scheme == 'https') {
    if (uri.host.isEmpty) {
      throw StateError(
        'HTTPS redirect URLs must include a host. Received: $redirectUrl',
      );
    }

    return CallbackTypeHttps(host: uri.host, path: path);
  }

  if (uri.scheme.isEmpty) {
    throw StateError(
      'Redirect URLs for native interactive authentication must include a URI scheme. Received: $redirectUrl',
    );
  }

  return CallbackTypeCustom(
    uri.scheme,
    host: uri.host.isEmpty ? '*' : uri.host,
    path: path,
  );
}

Future<String> startNativeAuthenticationFlow({
  required NativeAuthentication nativeAuthentication,
  required String authorizationUrl,
  required String redirectUrl,
  bool preferEphemeralSession = false,
}) async {
  final session = nativeAuthentication.startCallback(
    uri: Uri.parse(authorizationUrl),
    type: callbackTypeForRedirectUrl(redirectUrl),
    preferEphemeralSession: preferEphemeralSession,
  );

  try {
    final result = await session.redirectUri;
    return result.toString();
  } on NativeAuthCanceledException {
    throw AuthenticationException(ERROR_USER_CLOSED);
  } on NativeAuthException catch (e) {
    throw AuthenticationException(e.message);
  }
}
