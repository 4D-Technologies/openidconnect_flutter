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
    return {
      "client_id": clientId,
      "grant_type": grantType,
      "scope": scopes.join(" "),
      if (prompts != null && prompts!.isNotEmpty) 'prompt': prompts!.join(' '),
      if (clientSecret != null) "client_secret": clientSecret!,
      ...?additionalParameters
    };
  }
}
