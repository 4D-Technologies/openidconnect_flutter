part of openidconnect;

/// Token response returned from a successful authorization or refresh flow.
class AuthorizationResponse extends TokenResponse {
  final String accessToken;
  final String? refreshToken;
  final String idToken;
  final String? state;

  /// Creates an authorization response.
  AuthorizationResponse({
    required this.accessToken,
    required this.idToken,
    this.refreshToken,
    this.state,
    required super.tokenType,
    required super.expiresAt,
    super.additionalProperties,
  });

  /// Creates an [AuthorizationResponse] from token endpoint JSON.
  ///
  /// Some providers omit `id_token` from refresh-token responses after the
  /// initial login completes. In that case, [fallbackIdToken] preserves the
  /// existing `id_token` instead of treating the response as malformed.
  factory AuthorizationResponse.fromJson(
    Map<String, dynamic> json, {
    String? state,
    String? fallbackIdToken,
  }) => (() {
    final accessToken = json['access_token']?.toString();
    final tokenType = json['token_type']?.toString();
    final idToken = json['id_token']?.toString() ?? fallbackIdToken;
    final expiresIn = int.tryParse(json['expires_in']?.toString() ?? '') ?? 0;

    if (accessToken == null || accessToken.isEmpty) {
      throw const FormatException('Missing access_token');
    }

    if (tokenType == null || tokenType.isEmpty) {
      throw const FormatException('Missing token_type');
    }

    if (idToken == null || idToken.isEmpty) {
      throw const FormatException('Missing id_token');
    }

    return AuthorizationResponse(
      accessToken: accessToken,
      tokenType: tokenType,
      idToken: idToken,
      refreshToken: json['refresh_token']?.toString(),
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
      additionalProperties: json,
      state: state,
    );
  })();
}
