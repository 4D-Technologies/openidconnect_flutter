import 'dart:async';
import 'dart:io';

import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';

typedef DesktopUrlLauncher = Future<void> Function(String url);

typedef WindowsSecureAuthenticationInvoker = Future<String> Function({
  required String authorizationUrl,
  required String redirectUrl,
  int popupWidth,
  int popupHeight,
});

DesktopAuthenticationRedirect redirectDetailsForUrl(String redirectUrl) {
  final uri = Uri.parse(redirectUrl);
  final path = uri.path.isEmpty ? '/*' : uri.path;

  if (uri.scheme == 'http') {
    if (uri.host != 'localhost') {
      throw StateError(
        'Native interactive authentication only supports http://localhost callbacks for HTTP redirect URLs. Received: $redirectUrl',
      );
    }

    if (!uri.hasPort || uri.port <= 0) {
      throw StateError(
        'Loopback redirect URLs for Windows interactive authentication must include an explicit port greater than 0. Received: $redirectUrl',
      );
    }

    return DesktopAuthenticationRedirect.localhost(
      uri: uri,
      port: uri.port,
      path: path,
    );
  }

  if (uri.scheme == 'https') {
    if (uri.host.isEmpty) {
      throw StateError(
        'HTTPS redirect URLs must include a host. Received: $redirectUrl',
      );
    }

    return DesktopAuthenticationRedirect.https(
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

  return DesktopAuthenticationRedirect.custom(
    uri: uri,
    scheme: uri.scheme,
    path: path,
  );
}

bool callbackMatchesRedirect({
  required String callbackUrl,
  required String redirectUrl,
}) {
  if (callbackUrl == redirectUrl) {
    return true;
  }
  if (!callbackUrl.startsWith(redirectUrl) ||
      callbackUrl.length <= redirectUrl.length) {
    return false;
  }
  final next = callbackUrl[redirectUrl.length];
  return next == '?' || next == '#' || next == '/';
}

Future<String> startNativeAuthenticationFlow({
  required String authorizationUrl,
  required String redirectUrl,
  required WindowsSecureAuthenticationInvoker invokeSecureAuthentication,
  int popupWidth = 640,
  int popupHeight = 600,
}) async {
  redirectDetailsForUrl(redirectUrl);
  final result = await invokeSecureAuthentication(
    authorizationUrl: authorizationUrl,
    redirectUrl: redirectUrl,
    popupWidth: popupWidth,
    popupHeight: popupHeight,
  );
  if (result.isEmpty) {
    throw AuthenticationException(
      'Native authentication completed without a redirect URL.',
    );
  }
  if (!callbackMatchesRedirect(callbackUrl: result, redirectUrl: redirectUrl)) {
    throw AuthenticationException(
      'Interactive authentication returned an unexpected redirect URL.',
    );
  }
  return result;
}

Future<String> startLoopbackAuthenticationFlow({
  required String authorizationUrl,
  required String redirectUrl,
  required DesktopUrlLauncher launchUrl,
  bool preferEphemeralSession = false,
  Duration authenticationTimeout = _interactiveAuthenticationTimeout,
}) async {
  final redirect = redirectDetailsForUrl(redirectUrl);
  if (redirect.kind != DesktopAuthenticationRedirectKind.localhost) {
    throw UnsupportedError(
      'Windows loopback authentication only supports http://localhost redirect URLs. Received: $redirectUrl',
    );
  }
  HttpServer? server;
  StreamSubscription<HttpRequest>? requestSubscription;
  final port = redirect.port!;

  try {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);

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
  } on SocketException catch (e, stackTrace) {
    logOpenIdConnectError(
      'Windows interactive authentication failed to bind localhost',
      e,
      stackTrace,
    );
    throw AuthenticationException(
      'Failed to bind to http://localhost:$port. ${e.message}',
    );
  } on ProcessException catch (e, stackTrace) {
    logOpenIdConnectError(
      'Windows interactive authentication failed to launch the browser',
      e,
      stackTrace,
    );
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
  const DesktopAuthenticationRedirect._({
    required this.kind,
    required this.uri,
    required this.path,
    this.port,
    this.host,
    this.scheme,
  });

  const DesktopAuthenticationRedirect.localhost({
    required Uri uri,
    required int port,
    required String path,
  }) : this._(
         kind: DesktopAuthenticationRedirectKind.localhost,
         uri: uri,
         port: port,
         path: path,
       );

  const DesktopAuthenticationRedirect.https({
    required Uri uri,
    required String host,
    required String path,
  }) : this._(
         kind: DesktopAuthenticationRedirectKind.https,
         uri: uri,
         host: host,
         path: path,
       );

  const DesktopAuthenticationRedirect.custom({
    required Uri uri,
    required String scheme,
    required String path,
  }) : this._(
         kind: DesktopAuthenticationRedirectKind.custom,
         uri: uri,
         scheme: scheme,
         path: path,
       );

  final DesktopAuthenticationRedirectKind kind;
  final Uri uri;
  final String path;
  final int? port;
  final String? host;
  final String? scheme;
}

enum DesktopAuthenticationRedirectKind { localhost, https, custom }

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
