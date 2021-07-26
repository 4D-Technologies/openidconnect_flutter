part of openidconnect;

abstract class OpenIdConnectException implements Exception {
  final String? errorMessage;
  OpenIdConnectException([this.errorMessage]);

  @override
  String toString() => errorMessage ?? "Unknown";
}
