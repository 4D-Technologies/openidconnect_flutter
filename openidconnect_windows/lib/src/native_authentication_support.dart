import 'dart:async';
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
  Duration authenticationTimeout = _interactiveAuthenticationTimeout,
}) async {
  final redirect = redirectDetailsForUrl(redirectUrl);
  HttpServer? server;
  StreamSubscription<HttpRequest>? requestSubscription;

  try {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, redirect.port);

    final redirectCompleter = Completer<String>();
    requestSubscription = server.listen(
      (request) {
        unawaited(
          _handleLoopbackRequest(
            request: request,
            redirect: redirect,
            redirectCompleter: redirectCompleter,
          ).catchError((Object error, StackTrace stackTrace) {
            _completeRedirectError(redirectCompleter, error, stackTrace);
          }),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        _completeRedirectError(redirectCompleter, error, stackTrace);
      },
      onDone: () {
        _completeRedirectError(
          redirectCompleter,
          AuthenticationException(
            'The browser authentication flow ended before a localhost redirect was received.',
          ),
        );
      },
      cancelOnError: true,
    );

    await launchUrl(authorizationUrl);
    return await redirectCompleter.future.timeout(
      authenticationTimeout,
      onTimeout: () => throw AuthenticationException(ERROR_USER_CLOSED),
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
    await requestSubscription?.cancel();
    await server?.close(force: true);
  }
}

Future<void> _handleLoopbackRequest({
  required HttpRequest request,
  required DesktopAuthenticationRedirect redirect,
  required Completer<String> redirectCompleter,
}) async {
  if (request.method != 'GET') {
    request.response.statusCode = HttpStatus.methodNotAllowed;
    await request.response.close();
    return;
  }

  final requestedUri = request.requestedUri;
  if (redirect.path != '/*' && requestedUri.path != redirect.path) {
    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
    return;
  }

  request.response.statusCode = HttpStatus.ok;
  request.response.headers.contentType = ContentType.html;
  request.response.write(_loopbackAuthenticationCompleteHtml);
  await request.response.close();

  if (!redirectCompleter.isCompleted) {
    redirectCompleter.complete(requestedUri.toString());
  }
}

void _completeRedirectError(
  Completer<String> redirectCompleter,
  Object error, [
  StackTrace? stackTrace,
]) {
  if (redirectCompleter.isCompleted) {
    return;
  }

  try {
    if (stackTrace == null) {
      redirectCompleter.completeError(error);
    } else {
      redirectCompleter.completeError(error, stackTrace);
    }
  } on StateError {
    // The redirect already completed via another callback, timeout, or error.
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

const _interactiveAuthenticationTimeout = Duration(minutes: 5);

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
