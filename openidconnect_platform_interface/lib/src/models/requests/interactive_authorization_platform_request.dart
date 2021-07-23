part of openidconnect_platform_interface;

class InteractiveAuthorizationPlatformRequest extends TokenRequest {
  final int popupWidth;
  final int popupHeight;
  final String codeVerifier;
  final String codeChallenge;
  final bool useWebPopup;
  final String redirectUrl;

  InteractiveAuthorizationPlatformRequest({
    required String clientId,
    String? clientSecret,
    required this.redirectUrl,
    required Iterable<String> scopes,
    required OpenIdConfiguration configuration,
    required bool autoRefresh,
    required this.codeVerifier,
    required this.codeChallenge,
    String? loginHint,
    Iterable<String>? prompts,
    Map<String, String>? additionalParameters,
    this.popupWidth = 640,
    this.popupHeight = 480,
    this.useWebPopup = true,
  }) : super(
          configuration: configuration,
          clientId: clientId,
          clientSecret: clientSecret,
          grantType: "code",
          scopes: scopes,
          prompts: prompts,
          additionalParameters: {
            "redirect_url": redirectUrl,
            "login_hint": loginHint ?? "",
            "response_type": "code",
            "code_challenge_method": "S256",
            "code_challenge": codeChallenge,
            ...(additionalParameters ?? {})
          },
        );
}
