part of '../../../openidconnect.dart';

/// Request payload for the interactive authorization-code flow with PKCE.
class InteractiveAuthorizationRequest extends TokenRequest {
  static const String _charset =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

  final int popupWidth;
  final int popupHeight;
  final String codeVerifier;
  final String codeChallenge;
  final String state;
  final bool useWebPopup;
  final String redirectUrl;
  final String? loginHint;

  /// read: https://openid.net/specs/openid-connect-core-1_0.html#AuthRequest
  ///
  /// [prompts]
  /// * none - The Authorization Server MUST NOT display any authentication or consent user interface pages. An error is returned if an End-User is not already authenticated or the Client does not have pre-configured consent for the requested Claims or does not fulfill other conditions for processing the request. The error code will typically be login_required, interaction_required, or another code defined in Section 3.1.2.6. This can be used as a method to check for existing authentication and/or consent.
  /// * login - The Authorization Server SHOULD prompt the End-User for reauthentication. If it cannot reauthenticate the End-User, it MUST return an error, typically login_required.
  /// * consent - The Authorization Server SHOULD prompt the End-User for consent before returning information to the Client. If it cannot obtain consent, it MUST return an error, typically consent_required.
  /// * select_account - The Authorization Server SHOULD prompt the End-User to select a user account. This enables an End-User who has multiple accounts at the Authorization Server to select amongst the multiple accounts that they might have current sessions for. If it cannot obtain an account selection choice made by the End-User, it MUST return an error, typically account_selection_required.
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
      128,
      (i) => _charset[Random.secure().nextInt(_charset.length)],
    ).join();

    final codeChallenge = base64Url
        .encode(crypto.sha256.convert(ascii.encode(codeVerifier)).bytes)
        .replaceAll('=', '');
    final state = List.generate(
      43,
      (i) => _charset[Random.secure().nextInt(_charset.length)],
    ).join();

    return InteractiveAuthorizationRequest._(
      clientId: clientId,
      redirectUrl: redirectUrl,
      scopes: scopes,
      configuration: configuration,
      autoRefresh: autoRefresh,
      codeVerifier: codeVerifier,
      codeChallenge: codeChallenge,
      state: state,
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
    required super.clientId,
    super.clientSecret,
    required this.redirectUrl,
    required super.scopes,
    required super.configuration,
    required bool autoRefresh,
    required this.codeVerifier,
    required this.codeChallenge,
    required this.state,
    this.loginHint,
    super.prompts,
    super.additionalParameters,
    this.popupWidth = 640,
    this.popupHeight = 480,
    this.useWebPopup = true,
  }) : super(grantType: "authorization_code");

  /// Builds the authorization request parameters sent to the provider.
  @override
  Map<String, String> toMap() {
    final map = super.toMap();

    map.remove('grant_type');
    map.remove('client_secret');
    map['response_type'] = 'code';
    map['redirect_uri'] = redirectUrl;
    map['state'] = state;
    map['code_challenge_method'] = 'S256';
    map['code_challenge'] = codeChallenge;

    if (loginHint != null && loginHint!.isNotEmpty) {
      map['login_hint'] = loginHint!;
    }

    return map;
  }
}
