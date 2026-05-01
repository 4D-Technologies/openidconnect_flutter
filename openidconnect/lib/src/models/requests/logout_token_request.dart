part of openidconnect;

/// Request payload used to revoke a refresh token during logout.
class LogoutTokenRequest {
  final String refreshToken;
  final String? clientId;
  final String? clientSecret;
  final String? redirectUrl;
  final OpenIdConfiguration configuration;

  /// Creates a logout-token request.
  const LogoutTokenRequest({
    required this.configuration,
    required this.refreshToken,
    this.clientId,
    this.clientSecret,
    this.redirectUrl,
  });

  /// Builds the form body for logout-token related requests.
  Map<String, String> toMap() {
    var map = {"refresh_token": refreshToken};
    if (clientId != null) map = {"client_id": clientId!, ...map};
    if (clientSecret != null) map = {"client_secret": clientSecret!, ...map};
    if (redirectUrl != null) map = {"redirect_uri": redirectUrl!, ...map};
    return map;
  }
}
