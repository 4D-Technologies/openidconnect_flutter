part of openidconnect;

/// Request body for the device authorization endpoint.
class DeviceAuthorizationRequest {
  final OpenIdConfiguration configuration;
  final String clientId;
  final String? clientSecret;
  final Iterable<String> scopes;
  final String? audience;
  final Map<String, String>? additionalParameters;

  /// Creates a device authorization request.
  const DeviceAuthorizationRequest({
    required this.clientId,
    required this.scopes,
    required this.audience,
    required this.configuration,
    this.clientSecret,
    this.additionalParameters,
  });

  /// Builds the form body sent to the device authorization endpoint.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      "client_id": clientId,
      "scope": scopes.join(" "),
      if (audience != null) "audience": audience!,
      if (clientSecret != null) "client_secret": clientSecret!,
      ...?additionalParameters,
    };
  }
}
