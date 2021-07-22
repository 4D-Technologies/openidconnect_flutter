part of openidconnect_platform_interface;

class InteractiveAuthorizationPlatformRequest extends TokenRequest {
  final int webPopupWidth;
  final int webPopupHeight;
  final String codeVerifier;
  final String codeChallenge;

  InteractiveAuthorizationPlatformRequest({
    required String clientId,
    String? clientSecret,
    required String redirectUrl,
    required Iterable<String> scopes,
    required OpenIdConfiguration configuration,
    required bool autoRefresh,
    required this.codeVerifier,
    required this.codeChallenge,
    String? loginHint,
    Iterable<String>? prompts,
    Map<String, String>? additionalParameters,
    this.webPopupWidth = 640,
    this.webPopupHeight = 480,
  }) : super(
          configuration: configuration,
          clientId: clientId,
          clientSecret: clientSecret,
          grantType: "code",
          redirectUrl: redirectUrl,
          scopes: scopes,
          prompts: prompts,
          autoRefresh: autoRefresh,
          additionalParameters: {
            "login_hint": loginHint ?? "",
            "response_type": "code",
            "code_challenge_method": "S256",
            "code_challenge": codeChallenge,
            ...(additionalParameters ?? {})
          },
        );
}
