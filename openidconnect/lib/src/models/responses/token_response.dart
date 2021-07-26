part of openidconnect;

class TokenResponse {
  final String tokenType;
  final Map<String, dynamic>? additionalProperties;
  final DateTime expiresAt;

  TokenResponse({
    required this.tokenType,
    required this.expiresAt,
    this.additionalProperties,
  });
}
