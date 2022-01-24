part of openidconnect;

enum TokenType { idToken, accessToken }

class RevokeTokenRequest {
  final OpenIdConfiguration configuration;
  final String token;
  final TokenType tokenType;
  final String? clientId;
  final String? clientSecret;

  const RevokeTokenRequest({
    required this.configuration,
    required this.token,
    required this.tokenType,
    this.clientId,
    this.clientSecret,
  });

  Map<String, String> toMap() {
    var map = {"token": token,
      "token_type_hint": tokenType == TokenType.accessToken
          ? "access_token"
          : "refresh_token",
    };
    if (clientId != null) map = {"client_id": clientId!, ...map};
    if (clientSecret != null) map = {"client_secret": clientSecret!, ...map};
    return map;
  }
}
