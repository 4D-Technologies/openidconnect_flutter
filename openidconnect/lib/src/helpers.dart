part of '../openidconnect.dart';

Map<String, dynamic> _decodeJwtPayload(String token) {
  final tokenParts = token.split('.');
  if (tokenParts.length != 3) {
    throw const FormatException('Invalid JWT format.');
  }

  final normalizedPayload = base64Url.normalize(tokenParts[1]);
  final decodedPayload = utf8.decode(base64Url.decode(normalizedPayload));
  final payload = jsonDecode(decodedPayload);

  if (payload is! Map<String, dynamic>) {
    throw const FormatException('JWT payload is not a JSON object.');
  }

  return payload;
}

/// Executes an HTTP request with retry behavior and decodes JSON responses.
///
/// Returns `null` when the response body is empty.
Future<Map<String, dynamic>?> httpRetry<T extends http.Response>(
  FutureOr<T> Function() fn, {
  Duration delayFactor = const Duration(milliseconds: 200),
  double randomizationFactor = 0.25,
  Duration maxDelay = const Duration(seconds: 30),
  int maxAttempts = 8,
  FutureOr<bool> Function(Exception)? retryIf,
  FutureOr<void> Function(Exception)? onRetry,
}) async {
  var attempt = 1;
  while (true) {
    final options = RetryOptions(
      delayFactor: delayFactor,
      randomizationFactor: randomizationFactor,
      maxDelay: maxDelay,
      maxAttempts: maxAttempts,
    );

    var result = await options.retry(
      fn,
      retryIf: retryIf ?? (e) => e is IOException || e is TimeoutException,
      onRetry: (e) async {
        logOpenIdConnectWarning('Retrying OpenID Connect HTTP request', e);
        await onRetry?.call(e);
      },
    );

    if (result.statusCode == 503 ||
        result.statusCode == 502 ||
        result.statusCode == 504) {
      if (attempt >= maxAttempts) {
        final exception = HttpException(
          'The server could not be reached. Please try again later.',
        );
        logOpenIdConnectError(
          'OpenID Connect HTTP ${result.statusCode} persisted after $maxAttempts attempts',
          exception,
        );
        throw exception;
      }
      openIdConnectLogger.w(
        'OpenID Connect HTTP ${result.statusCode}; retrying ($attempt/$maxAttempts).',
      );
      await Future<void>.delayed(options.delay(attempt));
      attempt++;
      continue;
    }

    final body = result.body.isEmpty
        ? "{}"
        : result.body.startsWith("{")
        ? result.body
        : result.body.startsWith("<html")
        ? "{}"
        : "{\"error\": \"${result.body.replaceAll("\"", "'")}\"}";

    final jsonResponse = jsonDecode(body) as Map<String, dynamic>?;

    if (result.statusCode < 200 || result.statusCode >= 300) {
      if (jsonResponse!["error"] != null) {
        var error = jsonResponse["error"].toString();
        if (jsonResponse["error_description"] != null) {
          error += ": ${jsonResponse["error_description"]}";
        }
        final exception = HttpResponseException(
          ERROR_MESSAGE_FORMAT.replaceAll("%2", error),
        );
        logOpenIdConnectError(
          'OpenID Connect HTTP ${result.statusCode}',
          exception,
        );
        throw exception;
      } else {
        final exception = HttpResponseException(
          ERROR_MESSAGE_FORMAT.replaceAll("%2", "unknown_error"),
        );
        logOpenIdConnectError(
          'OpenID Connect HTTP ${result.statusCode}',
          exception,
        );
        throw exception;
      }
    }

    return result.body.isEmpty ? null : jsonResponse;
  }
}
