part of openidconnect;

class DeviceAuthorizationRequest {
  final OpenIdConfiguration configuration;
  final String clientId;
  final String? clientSecret;
  final Iterable<String> scopes;
  final String? audience;
  final Map<String, String>? additionalParameters;

  const DeviceAuthorizationRequest({
    required this.clientId,
    required this.scopes,
    required this.audience,
    required this.configuration,
    this.clientSecret,
    this.additionalParameters,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      "client_id": clientId,
      "scope": scopes.join(" "),
      if (audience != null) "audience": audience!,
      if (clientSecret != null) "client_secret": clientSecret!,
      ...?additionalParameters
    };
  }
}
