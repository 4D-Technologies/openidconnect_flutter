part of openidconnect;

/// Request body for exchanging a refresh token for a new access token.
class RefreshRequest extends TokenRequest {
  /// The current `id_token` to preserve across refreshes when the provider
  /// does not return a new `id_token` in the refresh response.
  ///
  /// Provide this when you already have an existing `id_token` and want it to
  /// remain available if the token endpoint omits `id_token` during refresh.
  final String? currentIdToken;

  /// Creates a refresh-token request.
  RefreshRequest({
    required super.clientId,
    super.clientSecret,
    required super.scopes,
    required String refreshToken,
    this.currentIdToken,
    required super.configuration,
    Map<String, String>? additionalParameters,
    bool autoRefresh = true,
  }) : super(
         grantType: "refresh_token",
         additionalParameters: {
           "refresh_token": refreshToken,
           ...?additionalParameters,
         },
       );
}
