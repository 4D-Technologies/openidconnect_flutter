part of openidconnect;

class PasswordAuthorizationRequest extends TokenRequest {
  PasswordAuthorizationRequest({
    required String clientId,
    String? clientSecret,
    required Iterable<String> scopes,
    required String userName,
    required String password,
    required OpenIdConfiguration configuration,
    required bool autoRefresh,
    Iterable<String>? prompts,
    Map<String, String>? additionalParameters,
  }) : super(
            configuration: configuration,
            clientId: clientId,
            clientSecret: clientSecret,
            grantType: "password",
            redirectUrl: null,
            scopes: scopes,
            prompts: prompts,
            autoRefresh: autoRefresh,
            additionalParameters: {
              "username": userName,
              "password": password,
              ...(additionalParameters ?? {})
            });
}
