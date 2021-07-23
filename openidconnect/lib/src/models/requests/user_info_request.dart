part of openidconnect;

class UserInfoRequest {
  final String accessToken;
  final OpenIdConfiguration configuration;
  final String tokenType;

  const UserInfoRequest({
    required this.accessToken,
    required this.configuration,
    this.tokenType = "Bearer",
  });
}
