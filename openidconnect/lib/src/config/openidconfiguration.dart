part of openidconnect;

class OpenIdConfiguration {
  final String issuer;
  final String jwksUri;
  final String authorizationEndpoint;
  final String tokenEndpoint;
  final String userInfoEndpoint;
  final String? endSessionEndpoint;
  final String? revocationEndpoint;
  final String? registrationEndpoint;
  final String? mfaChallengeEndpoint;

  final List<String>? scopesSupported;
  final List<String>? claimsSupported;
  final List<String>? grantTypesSupported;
  final List<String> responseTypesSupported;
  final List<String> responseModesSupported;
  final bool requestUriParameterSupported;

  final String? checkSessionIFrame;
  final String? deviceAuthorizationEndpoint;
  final List<String>? apiEndpoints;
  final List<String> tokenEndpointAuthMethodsSupported;
  final List<String> idTokenSigningAlgValuesSupported;
  final List<String> subjectTypesSupported;
  final List<String> codeChallengeMethodsSupported;

  final Map<String, dynamic> document;

  OpenIdConfiguration({
    required this.issuer,
    required this.jwksUri,
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    required this.userInfoEndpoint,
    this.endSessionEndpoint,
    this.revocationEndpoint,
    this.registrationEndpoint,
    this.mfaChallengeEndpoint,
    this.scopesSupported,
    this.claimsSupported,
    this.grantTypesSupported,
    required this.responseTypesSupported,
    required this.responseModesSupported,
    this.checkSessionIFrame,
    this.deviceAuthorizationEndpoint,
    required this.tokenEndpointAuthMethodsSupported,
    required this.idTokenSigningAlgValuesSupported,
    required this.subjectTypesSupported,
    required this.codeChallengeMethodsSupported,
    this.apiEndpoints,
    required this.document,
    required this.requestUriParameterSupported,
  });

  factory OpenIdConfiguration.fromJson(Map<String, dynamic> json) =>
      OpenIdConfiguration(
        document: json,
        issuer: json["issuer"].toString(),
        jwksUri: json["jwks_uri"].toString(),
        authorizationEndpoint: json["authorization_endpoint"].toString(),
        tokenEndpoint: json["token_endpoint"].toString(),
        userInfoEndpoint: json["userinfo_endpoint"].toString(),
        endSessionEndpoint: json["end_session_endpoint"]?.toString(),
        revocationEndpoint: json["revocation_endpoint"]?.toString(),
        registrationEndpoint: json["registration_endpoint"]?.toString(),
        mfaChallengeEndpoint: json["mfa_challenge_endpoint"]?.toString(),
        deviceAuthorizationEndpoint:
            json["device_authorization_endpoint"]?.toString(),
        scopesSupported: json["scopes_supported"] == null
            ? null
            : List<String>.from(json["scopes_supported"] as List<dynamic>),
        claimsSupported: json["claims_supported"] == null
            ? null
            : List<String>.from(json["claims_supported"] as List<dynamic>),
        grantTypesSupported: json["grant_types_supported"] == null
            ? null
            : List<String>.from(json["grant_types_supported"] as List<dynamic>),
        responseTypesSupported: json["response_types_supported"] == null
            ? List<String>.empty()
            : List<String>.from(
                json["response_types_supported"] as List<dynamic>),
        responseModesSupported: json["response_modes_supported"] == null
            ? List<String>.empty()
            : List<String>.from(
                json["response_modes_supported"] as List<dynamic>),
        apiEndpoints: json["api_endpoint"] == null
            ? null
            : json["api_endpoint"] is List<dynamic>
                ? List<String>.from(json["api_endpoint"] as List<dynamic>)
                : [json["api_endpoint"]!.toString()],
        checkSessionIFrame: json["check_session_iframe"]?.toString(),
        codeChallengeMethodsSupported: List<String>.from(
            (json["code_challenge_methods_supported"] ?? <List<String>>[])
                as List<dynamic>),
        idTokenSigningAlgValuesSupported: List<String>.from(
            (json["id_token_signing_alg_values_supported"] ?? <List<String>>[])
                as List<dynamic>),
        subjectTypesSupported: List<String>.from(
            (json["subject_types_supported"] ?? <List<String>>[])
                as List<dynamic>),
        tokenEndpointAuthMethodsSupported: List<String>.from(
            (json["token_endpoint_auth_methods_supported"] ?? <List<String>>[])
                as List<dynamic>),
        requestUriParameterSupported:
            (json["request_uri_parameter_supported"] ?? false) as bool,
      );

  @override
  operator ==(Object o) {
    if (identical(this, o)) return true;

    return o is OpenIdConfiguration &&
        o.issuer == issuer &&
        o.jwksUri == jwksUri &&
        o.authorizationEndpoint == authorizationEndpoint &&
        o.tokenEndpoint == tokenEndpoint &&
        o.userInfoEndpoint == userInfoEndpoint &&
        o.endSessionEndpoint == endSessionEndpoint &&
        o.revocationEndpoint == revocationEndpoint &&
        o.mfaChallengeEndpoint == mfaChallengeEndpoint &&
        o.registrationEndpoint == registrationEndpoint &&
        o.scopesSupported == scopesSupported &&
        o.claimsSupported == claimsSupported &&
        o.grantTypesSupported == grantTypesSupported &&
        o.responseTypesSupported == responseTypesSupported &&
        o.responseModesSupported == responseModesSupported &&
        o.checkSessionIFrame == checkSessionIFrame &&
        o.deviceAuthorizationEndpoint == deviceAuthorizationEndpoint &&
        o.apiEndpoints == apiEndpoints &&
        o.tokenEndpointAuthMethodsSupported ==
            tokenEndpointAuthMethodsSupported &&
        o.idTokenSigningAlgValuesSupported ==
            idTokenSigningAlgValuesSupported &&
        o.subjectTypesSupported == subjectTypesSupported &&
        o.codeChallengeMethodsSupported == codeChallengeMethodsSupported &&
        o.requestUriParameterSupported == requestUriParameterSupported;
  }

  @override
  int get hashCode =>
      issuer.hashCode ^
      jwksUri.hashCode ^
      authorizationEndpoint.hashCode ^
      tokenEndpoint.hashCode ^
      userInfoEndpoint.hashCode ^
      registrationEndpoint.hashCode ^
      mfaChallengeEndpoint.hashCode ^
      (endSessionEndpoint?.hashCode ?? 0) ^
      (revocationEndpoint?.hashCode ?? 0) ^
      scopesSupported.hashCode ^
      claimsSupported.hashCode ^
      grantTypesSupported.hashCode ^
      responseTypesSupported.hashCode ^
      responseModesSupported.hashCode ^
      (checkSessionIFrame?.hashCode ?? 0) ^
      (deviceAuthorizationEndpoint?.hashCode ?? 0) ^
      apiEndpoints.hashCode ^
      tokenEndpointAuthMethodsSupported.hashCode ^
      idTokenSigningAlgValuesSupported.hashCode ^
      subjectTypesSupported.hashCode ^
      codeChallengeMethodsSupported.hashCode ^
      requestUriParameterSupported.hashCode;
}
