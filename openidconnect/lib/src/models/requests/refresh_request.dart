part of openidconnect;

class RefreshRequest extends TokenRequest {
  RefreshRequest({
    required String clientId,
    String? clientSecret,
    required String redirectUrl,
    required Iterable<String> scopes,
    required String refreshToken,
    required OpenIdConfiguration configuration,
    required bool autoRefresh,
    Map<String, String>? additionalParameters,
  }) : super(
            configuration: configuration,
            clientId: clientId,
            clientSecret: clientSecret,
            grantType: "refresh_token",
            redirectUrl: redirectUrl,
            scopes: scopes,
            autoRefresh: autoRefresh,
            additionalParameters: {
              "refresh_token": refreshToken,
              ...(additionalParameters ?? {})
            });
}
