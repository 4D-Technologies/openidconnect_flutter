part of openidconnect;

/// Request payload for calling the dynamic client registration endpoint.
class UserRegistrationRequest {
  final String accessToken;
  final OpenIdConfiguration configuration;
  final String tokenType;

  /// Creates a user-registration request.
  const UserRegistrationRequest({
    required this.accessToken,
    required this.configuration,
    this.tokenType = "Bearer",
  });
}
