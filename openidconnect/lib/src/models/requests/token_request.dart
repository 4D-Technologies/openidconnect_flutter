part of openidconnect;

abstract class TokenRequest {
  final String clientId;
  final String? clientSecret;

  final String grantType;
  final Iterable<String> scopes;
  final Map<String, String>? additionalParameters;
  final Iterable<String>? prompts;
  final OpenIdConfiguration configuration;

  const TokenRequest({
    required this.clientId,
    this.clientSecret,
    required this.scopes,
    required this.grantType,
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

    if (clientSecret != null) map = {"client_secret": clientSecret!, ...map};

    if (additionalParameters != null) map = {...map, ...additionalParameters!};

    return map;
  }
}
