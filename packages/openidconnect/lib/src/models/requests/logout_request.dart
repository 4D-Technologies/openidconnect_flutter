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
    return {
      "id_token_hint": idToken,
      if (postLogoutRedirectUrl != null)
        "post_logout_redirect_url": postLogoutRedirectUrl!,
      if (state != null) "state": state!,
    };
  }
}
