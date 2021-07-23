part of openidconnect;

class LogoutRequest {
  final String idToken;
  final String? postLogoutRedirectUrl;
  final String? state;
  final OpenIdConfiguration configuration;

  const LogoutRequest({
    required this.idToken,
    this.postLogoutRedirectUrl,
    this.state,
    required this.configuration,
  });

  Map<String, String> toMap() {
    var map = {"id_token_hint": idToken};

    if (postLogoutRedirectUrl != null)
      map = {"post_logout_redirect_url": postLogoutRedirectUrl!, ...map};

    if (state != null) map = {"state": state!, ...map};

    return map;
  }
}
