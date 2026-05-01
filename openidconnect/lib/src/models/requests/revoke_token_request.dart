part of '../../../openidconnect.dart';

/// Token types supported by the revocation endpoint.
enum TokenType { idToken, accessToken, refreshToken }

/// Request payload for token revocation.
class RevokeTokenRequest {
  final OpenIdConfiguration configuration;
  final String token;
  final TokenType tokenType;
  final String? clientId;
  final String? clientSecret;

  /// Creates a token revocation request.
  const RevokeTokenRequest({
    required this.configuration,
    required this.token,
    required this.tokenType,
    this.clientId,
    this.clientSecret,
  }) : assert(tokenType != TokenType.idToken, "ID Tokens cannot be revoked.");

  /// Builds the form body sent to the revocation endpoint.
  Map<String, String> toMap({bool useBasicAuth = true}) {
    var map = {
      "token": token,
      "token_type_hint": tokenType == TokenType.accessToken
          ? "access_token"
          : "refresh_token",
    };
    if (!useBasicAuth && clientId != null) {
      map = {"client_id": clientId!, ...map};
    }
    if (!useBasicAuth && clientSecret != null) {
      map = {"client_secret": clientSecret!, ...map};
    }
    return map;
  }
}
