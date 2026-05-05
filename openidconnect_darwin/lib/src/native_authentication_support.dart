import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';

typedef DarwinNativeAuthenticationInvoker =
    Future<String?> Function({
      required String authorizationUrl,
      required String redirectUrl,
      bool preferEphemeralSession,
    });

typedef MacOSLoopbackAuthenticationRunner =
    Future<String> Function({
      required Uri redirectUri,
      required String authorizationUrl,
    });

DarwinAuthenticationRedirect redirectDetailsForUrl(String redirectUrl) {
  final uri = Uri.parse(redirectUrl);
  final path = uri.path.isEmpty ? '/*' : uri.path;

  if (uri.scheme == 'http') {
    if (uri.host != 'localhost') {
      throw StateError(
        'Native interactive authentication only supports http://localhost callbacks for HTTP redirect URLs. Received: $redirectUrl',
      );
    }

    return DarwinAuthenticationRedirect.localhost(
      uri: uri,
      port: uri.hasPort ? uri.port : 0,
      path: path,
    );
  }

  if (uri.scheme == 'https') {
    if (uri.host.isEmpty) {
      throw StateError(
        'HTTPS redirect URLs must include a host. Received: $redirectUrl',
      );
    }

    return DarwinAuthenticationRedirect.https(
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

  return DarwinAuthenticationRedirect.custom(
    uri: uri,
    scheme: uri.scheme,
    host: uri.host.isEmpty ? '*' : uri.host,
    path: path,
  );
}

Future<String> startNativeAuthenticationFlow({
  required String authorizationUrl,
  required String redirectUrl,
  required DarwinNativeAuthenticationInvoker invokeNativeAuthentication,
  required MacOSLoopbackAuthenticationRunner runMacOSLoopbackAuthentication,
  bool preferEphemeralSession = false,
}) async {
  final redirect = redirectDetailsForUrl(redirectUrl);

  if (Platform.isMacOS &&
      redirect.kind == DarwinAuthenticationRedirectKind.localhost) {
    return runMacOSLoopbackAuthentication(
      redirectUri: redirect.uri,
      authorizationUrl: authorizationUrl,
    );
  }

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
  } on PlatformException catch (e) {
    if (e.code == 'user_cancelled') {
      throw AuthenticationException(ERROR_USER_CLOSED);
    }

    throw AuthenticationException(e.message);
  }
}

Future<String> runMacOSLoopbackAuthenticationFlow({
  required Uri redirectUri,
  required String authorizationUrl,
}) async {
  final server = await HttpServer.bind(
    InternetAddress.loopbackIPv4,
    redirectUri.hasPort ? redirectUri.port : 0,
  );

  try {
    final launchResult = await Process.run('open', [authorizationUrl]);
    if (launchResult.exitCode != 0) {
      throw AuthenticationException(
        'Unable to launch the system browser for interactive authentication.',
      );
    }

    final expectedPath = redirectUri.path.isEmpty ? '/*' : redirectUri.path;
    await for (final request in server) {
      if (request.method != 'GET') {
        request.response.statusCode = HttpStatus.methodNotAllowed;
        await request.response.close();
        continue;
      }

      final requestedUri = request.requestedUri;
      if (expectedPath != '/*' && requestedUri.path != expectedPath) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        continue;
      }

      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.html;
      request.response.write(_loopbackAuthenticationCompleteHtml);
      await request.response.close();
      return requestedUri.toString();
    }

    throw AuthenticationException(
      'The browser authentication flow ended before a localhost redirect was received.',
    );
  } finally {
    await server.close(force: true);
  }
}

class DarwinAuthenticationRedirect {
  const DarwinAuthenticationRedirect._({
    required this.kind,
    required this.uri,
    required this.path,
    this.host,
    this.port,
    this.scheme,
  });

  const DarwinAuthenticationRedirect.localhost({
    required Uri uri,
    required int port,
    required String path,
  }) : this._(
         kind: DarwinAuthenticationRedirectKind.localhost,
         uri: uri,
         port: port,
         path: path,
       );

  const DarwinAuthenticationRedirect.https({
    required Uri uri,
    required String host,
    required String path,
  }) : this._(
         kind: DarwinAuthenticationRedirectKind.https,
         uri: uri,
         host: host,
         path: path,
       );

  const DarwinAuthenticationRedirect.custom({
    required Uri uri,
    required String scheme,
    required String host,
    required String path,
  }) : this._(
         kind: DarwinAuthenticationRedirectKind.custom,
         uri: uri,
         scheme: scheme,
         host: host,
         path: path,
       );

  final DarwinAuthenticationRedirectKind kind;
  final Uri uri;
  final String path;
  final String? host;
  final int? port;
  final String? scheme;
}

enum DarwinAuthenticationRedirectKind { localhost, https, custom }

const _loopbackAuthenticationCompleteHtml = '''
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Authentication complete</title>
  </head>
  <body>
    <p>Authentication complete. You can close this window.</p>
  </body>
</html>
''';
