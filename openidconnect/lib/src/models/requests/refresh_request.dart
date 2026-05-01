part of openidconnect;

class RefreshRequest extends TokenRequest {
  final String? currentIdToken;

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
