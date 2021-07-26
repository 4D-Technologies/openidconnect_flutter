part of openidconnect;

class AuthorizationResponse extends TokenResponse {
  final String accessToken;
  final String? refreshToken;
  final String idToken;
  final String? state;

  AuthorizationResponse({
    required this.accessToken,
    required this.idToken,
    this.refreshToken,
    this.state,
    required String tokenType,
    required DateTime expiresAt,
    Map<String, dynamic>? additionalProperties,
  }) : super(
          tokenType: tokenType,
          expiresAt: expiresAt,
          additionalProperties: additionalProperties,
        );

  factory AuthorizationResponse.fromJson(
    Map<String, dynamic> json, {
    String? state,
  }) =>
      AuthorizationResponse(
        accessToken: json["access_token"].toString(),
        tokenType: json["token_type"].toString(),
        idToken: json["id_token"].toString(),
        refreshToken: json["refresh_token"]?.toString(),
        expiresAt: DateTime.now().add(
          Duration(seconds: (json['expires_in'] as int?) ?? 0),
        ),
        additionalProperties: json,
        state: state,
      );
}
