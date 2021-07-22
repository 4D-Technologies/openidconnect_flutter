part of openidconnect_platform_interface;

abstract class TokenRequest {
  final String clientId;
  final String? clientSecret;
  final String? redirectUrl;
  final String grantType;
  final Iterable<String> scopes;
  final Map<String, String>? additionalParameters;
  final Iterable<String>? prompts;
  final OpenIdConfiguration configuration;

  final bool autoRefresh;

  TokenRequest({
    required this.clientId,
    this.clientSecret,
    required this.scopes,
    this.redirectUrl,
    required this.grantType,
    required this.autoRefresh,
    this.additionalParameters,
    this.prompts,
    required this.configuration,
  });

  @mustCallSuper
  Map<String, String> toMap() {
    var map = {
      "client_id": clientId,
      "grant_type": grantType,
      "scope": scopes.join(" "),
    };

    if (redirectUrl != null) map = {"redirect_url": redirectUrl!, ...map};

    if (clientSecret != null) map = {"client_secret": clientSecret!, ...map};

    if (additionalParameters != null) map = {...map, ...additionalParameters!};

    return map;
  }
}
