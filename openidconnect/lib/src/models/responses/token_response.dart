part of '../../../openidconnect.dart';

/// Base token response returned by the provider.
class TokenResponse {
  final String tokenType;
  final Map<String, dynamic>? additionalProperties;
  final DateTime expiresAt;

  /// Creates a token response wrapper.
  const TokenResponse({
    required this.tokenType,
    required this.expiresAt,
    this.additionalProperties,
  });
}
