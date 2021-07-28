part of openidconnect;

class InteractiveAuthorizationRequest extends TokenRequest {
  static const String _charset =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

  final int popupWidth;
  final int popupHeight;
  final String codeVerifier;
  final String codeChallenge;
  final bool useWebPopup;
  final String redirectUrl;

  static Future<InteractiveAuthorizationRequest> create({
    required String clientId,
    String? clientSecret,
    required String redirectUrl,
    required Iterable<String> scopes,
    required OpenIdConfiguration configuration,
    required bool autoRefresh,
    String? loginHint,
    Iterable<String>? prompts,
    Map<String, String>? additionalParameters,
    int popupWidth = 640,
    int popupHeight = 600,
    bool useWebPopup = true,
  }) async {
    final codeVerifier = List.generate(
        128, (i) => _charset[Random.secure().nextInt(_charset.length)]).join();

    final sha256 = crypto.Sha256();

    final codeChallenge = base64Url
        .encode((await sha256.hash(ascii.encode(codeVerifier))).bytes)
        .replaceAll('=', '');

    return InteractiveAuthorizationRequest._(
      clientId: clientId,
      redirectUrl: redirectUrl,
      scopes: scopes,
      configuration: configuration,
      autoRefresh: autoRefresh,
      codeVerifier: codeVerifier,
      codeChallenge: codeChallenge,
      additionalParameters: additionalParameters,
      clientSecret: clientSecret,
      loginHint: loginHint,
      prompts: prompts,
      popupHeight: popupHeight,
      popupWidth: popupWidth,
      useWebPopup: useWebPopup,
    );
  }

  InteractiveAuthorizationRequest._({
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
            "redirect_uri": redirectUrl,
            "login_hint": loginHint ?? "",
            "response_type": "code",
            "code_challenge_method": "S256",
            "code_challenge": codeChallenge,
            ...(additionalParameters ?? {})
          },
        );
}
