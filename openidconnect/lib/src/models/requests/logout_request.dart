part of '../../../openidconnect.dart';

/// Request payload for non-interactive RP-initiated logout.
class LogoutRequest {
  final String idToken;
  final String? postLogoutRedirectUri;
  final String? state;
  final OpenIdConfiguration configuration;

  /// Creates a logout request.
  const LogoutRequest({
    required this.idToken,
    this.postLogoutRedirectUri,
    this.state,
    required this.configuration,
  });

  /// Builds the query parameters sent to the end-session endpoint.
  Map<String, String> toMap() {
    return {
      "id_token_hint": idToken,
      "post_logout_redirect_uri": ?postLogoutRedirectUri,
      "state": ?state,
    };
  }
}
