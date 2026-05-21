import 'dart:io';

import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';

typedef DesktopUrlLauncher = Future<void> Function(String url);

DesktopAuthenticationRedirect redirectDetailsForUrl(String redirectUrl) {
  final uri = Uri.parse(redirectUrl);
  final path = uri.path.isEmpty ? '/*' : uri.path;

  if (uri.scheme == 'http') {
    if (uri.host != 'localhost') {
      throw StateError(
        'Native interactive authentication only supports http://localhost callbacks for HTTP redirect URLs. Received: $redirectUrl',
      );
    }

    return DesktopAuthenticationRedirect.localhost(
      uri: uri,
      port: uri.hasPort ? uri.port : 0,
      path: path,
    );
  }

  if (uri.scheme.isEmpty) {
    throw StateError(
      'Redirect URLs for native interactive authentication must include a URI scheme. Received: $redirectUrl',
    );
  }

  throw UnsupportedError(
    'Interactive authentication on Windows only supports http://localhost redirect URLs. Received: $redirectUrl',
  );
}

Future<String> startNativeAuthenticationFlow({
  required String authorizationUrl,
  required String redirectUrl,
  required DesktopUrlLauncher launchUrl,
  bool preferEphemeralSession = false,
}) async {
  final redirect = redirectDetailsForUrl(redirectUrl);
  HttpServer? server;

  try {
    server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      redirect.port,
    );

    await launchUrl(authorizationUrl);

    await for (final request in server) {
      if (request.method != 'GET') {
        request.response.statusCode = HttpStatus.methodNotAllowed;
        await request.response.close();
        continue;
      }

      final requestedUri = request.requestedUri;
      if (redirect.path != '/*' && requestedUri.path != redirect.path) {
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
  } on SocketException catch (e) {
    throw AuthenticationException(
      'Failed to bind to http://localhost:${redirect.port}. ${e.message}',
    );
  } on ProcessException catch (e) {
    throw AuthenticationException(
      'Unable to launch the system browser for interactive authentication. ${e.message}',
    );
  } finally {
    await server?.close(force: true);
  }
}

Future<void> launchUrlOnWindows(String url) async {
  final result = await Process.run('powershell', [
    '-NoProfile',
    '-Command',
    'Start-Process',
    url,
  ]);
  if (result.exitCode != 0) {
    throw ProcessException(
      'powershell',
      ['-NoProfile', '-Command', 'Start-Process', url],
      '${result.stdout}\n${result.stderr}',
      result.exitCode,
    );
  }
}

class DesktopAuthenticationRedirect {
  const DesktopAuthenticationRedirect.localhost({
    required this.uri,
    required this.port,
    required this.path,
  });

  final Uri uri;
  final int port;
  final String path;
}

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
