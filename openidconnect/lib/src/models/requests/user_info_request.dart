part of openidconnect;

/// Request payload for calling the UserInfo endpoint.
class UserInfoRequest {
  final String accessToken;
  final OpenIdConfiguration configuration;
  final String tokenType;

  /// Creates a user-info request.
  const UserInfoRequest({
    required this.accessToken,
    required this.configuration,
    this.tokenType = "Bearer",
  });
}
