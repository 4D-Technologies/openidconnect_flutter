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
    var map = {
      "client_id": clientId,
      "scope": scopes.join(" "),
    };

    if (audience != null) map = {"audience": audience!, ...map};
    if (clientSecret != null) map = {"client_secret": clientSecret!, ...map};

    return map;
  }
}
