part of openidconnect_platform_interface;

class AuthenticationFailedException implements Exception {
  final String? errorMessage;
  AuthenticationFailedException([this.errorMessage]);

  @override
  String toString() => errorMessage ?? "Unknown";
}
