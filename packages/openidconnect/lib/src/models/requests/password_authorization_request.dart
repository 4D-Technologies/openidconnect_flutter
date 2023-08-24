part of openidconnect;

class PasswordAuthorizationRequest extends TokenRequest {
  PasswordAuthorizationRequest({
    required super.clientId,
    super.clientSecret,
    required super.scopes,
    required String userName,
    required String password,
    required super.configuration,
    required bool autoRefresh,
    super.prompts,
    Map<String, String>? additionalParameters,
  }) : super(
          grantType: "password",
          additionalParameters: {
            "username": userName,
            "password": password,
            ...?additionalParameters,
          },
        );
}
