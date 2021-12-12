part of openidconnect;

class UserRegistrationRequest {
  final String accessToken;
  final OpenIdConfiguration configuration;
  final String tokenType;

  const UserRegistrationRequest({
    required this.accessToken,
    required this.configuration,
    this.tokenType = "Bearer",
  });
}
