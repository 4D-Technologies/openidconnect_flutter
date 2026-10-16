part of '../../openidconnect_platform_interface.dart';

class HttpResponseException implements Exception {
  final String? errorMessage;

  /// OAuth 2.0 `error` code from the response body, if present.
  ///
  /// See RFC 6749 §5.2 and RFC 7009 §2.2.1 (`unsupported_token_type`).
  final String? error;

  HttpResponseException([this.errorMessage, this.error]);

  @override
  String toString() => errorMessage ?? "Unknown";
}
