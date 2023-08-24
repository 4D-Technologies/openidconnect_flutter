part of openidconnect;

class RefreshRequest extends TokenRequest {
  RefreshRequest({
    required super.clientId,
    super.clientSecret,
    required super.scopes,
    required String refreshToken,
    required super.configuration,
    Map<String, String>? additionalParameters,
    bool autoRefresh = true,
  }) : super(
          grantType: "refresh_token",
          additionalParameters: {
            "refresh_token": refreshToken,
            ...?additionalParameters,
          },
        );
}
