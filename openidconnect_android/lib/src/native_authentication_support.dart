import 'package:flutter/services.dart';
import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';

typedef AndroidNativeAuthenticationInvoker =
    Future<String?> Function({
      required String authorizationUrl,
      required String redirectUrl,
      bool preferEphemeralSession,
    });

AndroidAuthenticationRedirect redirectDetailsForUrl(String redirectUrl) {
  final uri = Uri.parse(redirectUrl);
  final path = uri.path.isEmpty ? '/*' : uri.path;

  if (uri.scheme == 'http') {
    throw UnsupportedError(
      'Android interactive authentication only supports custom-scheme and HTTPS redirect URLs. Received: $redirectUrl',
    );
  }

  if (uri.scheme == 'https') {
    if (uri.host.isEmpty) {
      throw StateError(
        'HTTPS redirect URLs must include a host. Received: $redirectUrl',
      );
    }

    return AndroidAuthenticationRedirect.https(
      uri: uri,
      host: uri.host,
      path: path,
    );
  }

  if (uri.scheme.isEmpty) {
    throw StateError(
      'Redirect URLs for native interactive authentication must include a URI scheme. Received: $redirectUrl',
    );
  }

  return AndroidAuthenticationRedirect.custom(
    uri: uri,
    scheme: uri.scheme,
    host: uri.host.isEmpty ? '*' : uri.host,
    path: path,
  );
}

Future<String> startNativeAuthenticationFlow({
  required String authorizationUrl,
  required String redirectUrl,
  required AndroidNativeAuthenticationInvoker invokeNativeAuthentication,
  bool preferEphemeralSession = false,
}) async {
  redirectDetailsForUrl(redirectUrl);

  try {
    final result = await invokeNativeAuthentication(
      authorizationUrl: authorizationUrl,
      redirectUrl: redirectUrl,
      preferEphemeralSession: preferEphemeralSession,
    );

    if (result == null || result.isEmpty) {
      throw AuthenticationException(
        'Native authentication completed without a redirect URL.',
      );
    }

    return result.toString();
  } on PlatformException catch (e, stackTrace) {
    if (e.code == 'user_cancelled') {
      openIdConnectLogger.i(
        'Android interactive authentication was cancelled.',
      );
      throw AuthenticationException(ERROR_USER_CLOSED);
    }

    logOpenIdConnectError(
      'Android interactive authentication failed',
      e,
      stackTrace,
    );
    throw AuthenticationException(e.message);
  }
}

class AndroidAuthenticationRedirect {
  const AndroidAuthenticationRedirect._({
    required this.kind,
    required this.uri,
    required this.path,
    this.host,
    this.scheme,
  });

  const AndroidAuthenticationRedirect.https({
    required Uri uri,
    required String host,
    required String path,
  }) : this._(
         kind: AndroidAuthenticationRedirectKind.https,
         uri: uri,
         host: host,
         path: path,
       );

  const AndroidAuthenticationRedirect.custom({
    required Uri uri,
    required String scheme,
    required String host,
    required String path,
  }) : this._(
         kind: AndroidAuthenticationRedirectKind.custom,
         uri: uri,
         scheme: scheme,
         host: host,
         path: path,
       );

  final AndroidAuthenticationRedirectKind kind;
  final Uri uri;
  final String path;
  final String? host;
  final String? scheme;
}

enum AndroidAuthenticationRedirectKind { https, custom }
