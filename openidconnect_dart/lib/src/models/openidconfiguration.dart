import 'package:json_annotation/json_annotation.dart';

import 'json_with_original.dart';
part 'openidconfiguration.g.dart';

/// src: https://connect2id.com/products/server/docs/api/discovery#metadata
@JsonSerializable(createToJson: false)
class OpenIdConfiguration extends JsonObjectWithOriginal {
  //Core https://openid.net/specs/openid-connect-discovery-1_0.html#ProviderMetadata
  @JsonKey(name: 'issuer')
  final String issuer;
  @JsonKey(name: 'authorization_endpoint')
  final String authorizationEndpoint;
  @JsonKey(name: 'token_endpoint')
  final String? tokenEndpoint;
  @JsonKey(name: 'userinfo_endpoint')
  final String? userInfoEndpoint;

  @JsonKey(name: 'jwks_uri')
  final String jwksUri;

  @JsonKey(name: 'registration_endpoint')
  final String? registrationEndpoint;
  @JsonKey(name: 'scopes_supported')
  final List<String>? scopesSupported;
  @JsonKey(name: 'response_types_supported')
  final List<String> responseTypesSupported;
  @JsonKey(
    name: 'response_modes_supported',
  )
  final List<String> responseModesSupported;
  @JsonKey(name: 'grant_types_supported')
  final List<String> grantTypesSupported;

  @JsonKey(name: 'acr_values_supported')
  final List<String>? acrValuesSupported;
  @JsonKey(name: 'subject_types_supported')
  final List<String> subjectTypesSupported;
  @JsonKey(name: 'id_token_signing_alg_values_supported')
  final List<String> idTokenSigningAlgValuesSupported;
  @JsonKey(name: 'id_token_encryption_alg_values_supported')
  final List<String>? idTokenEncryptionAlgValuesSupported;
  @JsonKey(name: 'id_token_encryption_enc_values_supported')
  final List<String>? idTokenEncryptionEncValuesSupported;
  @JsonKey(name: 'userinfo_signing_alg_values_supported')
  final List<String>? userinfoSigningAlgValuesSupported;
  @JsonKey(name: 'userinfo_encryption_alg_values_supported')
  final List<String>? userinfoEncryptionAlgValuesSupported;
  @JsonKey(name: 'userinfo_encryption_enc_values_supported')
  final List<String>? userinfoEncryptionEncValuesSupported;
  @JsonKey(name: 'request_object_signing_alg_values_supported')
  final List<String>? requestObjectSigningAlgValuesSupported;
  @JsonKey(name: 'request_object_encryption_alg_values_supported')
  final List<String>? requestObjectEncryptionAlgValuesSupported;
  @JsonKey(name: 'request_object_encryption_enc_values_supported')
  final List<String>? requestObjectEncryptionEncValuesSupported;
  @JsonKey(name: 'token_endpoint_auth_methods_supported')
  final List<String> tokenEndpointAuthMethodsSupported;
  @JsonKey(name: 'token_endpoint_auth_signing_alg_values_supported')
  final List<String>? tokenEndpointAuthSigningAlgValuesSupported;
  @JsonKey(name: 'display_values_supported')
  final List<String>? displayValuesSupported;
  @JsonKey(name: 'claim_types_supported')
  final List<String> claimTypesSupported;
  @JsonKey(name: 'claims_supported')
  final List<String>? claimsSupported;
  @JsonKey(name: 'service_documentation')
  final String? serviceDocumentation;
  @JsonKey(name: 'claims_locales_supported')
  final List<String>? claimsLocalesSupported;
  @JsonKey(name: 'ui_locales_supported')
  final List<String>? uiLocalesSupported;
  @JsonKey(name: 'claims_parameter_supported')
  final bool claimsParameterSupported;
  @JsonKey(name: 'request_parameter_supported')
  final bool requestParameterSupported;
  @JsonKey(name: 'request_uri_parameter_supported')
  final bool requestUriParameterSupported;
  @JsonKey(name: 'require_request_uri_registration')
  final bool requireRequestUriRegistration;
  @JsonKey(name: 'op_policy_uri')
  final String? opPolicyUri;
  @JsonKey(name: 'op_tos_uri')
  final String? opTosUri;

  //OpenID Connect Session Management 1.0: https://openid.net/specs/openid-connect-session-1_0.html#OPMetadata
  @JsonKey(name: 'check_session_iframe')
  final String? checkSessionIFrame;
  // OpenID Connect RP-Initiated Logout 1.0: https://openid.net/specs/openid-connect-rpinitiated-1_0.html#OPMetadata
  @JsonKey(name: 'end_session_endpoint')
  final String? endSessionEndpoint;

  // Initiating User Registration via OpenID Connect 1.0: https://openid.net/specs/openid-connect-prompt-create-1_0.html
  @JsonKey(name: 'prompt_values_supported')
  final List<String>? promptValuesSupported;

  //OAuth 2.0 Device Authorization Grant: https://datatracker.ietf.org/doc/html/rfc8628#section-4
  @JsonKey(name: 'device_authorization_endpoint')
  final String? deviceAuthorizationEndpoint;
  //OAuth 2.0 Token Revocation: https://datatracker.ietf.org/doc/html/rfc7009
  @JsonKey(name: 'revocation_endpoint')
  final String? revocationEndpoint;

  //Proof Key for Code Exchange by OAuth Public Clients: https://datatracker.ietf.org/doc/html/rfc7636
  @JsonKey(name: 'code_challenge_methods_supported')
  final List<String>? codeChallengeMethodsSupported;

  ///The original document

  const OpenIdConfiguration({
    this.acrValuesSupported,
    this.idTokenEncryptionAlgValuesSupported,
    this.idTokenEncryptionEncValuesSupported,
    this.userinfoSigningAlgValuesSupported,
    this.userinfoEncryptionAlgValuesSupported,
    this.userinfoEncryptionEncValuesSupported,
    this.requestObjectSigningAlgValuesSupported,
    this.requestObjectEncryptionAlgValuesSupported,
    this.requestObjectEncryptionEncValuesSupported,
    this.tokenEndpointAuthSigningAlgValuesSupported,
    this.displayValuesSupported,
    this.claimTypesSupported = const ['normal'],
    this.serviceDocumentation,
    this.claimsLocalesSupported,
    this.uiLocalesSupported,
    this.claimsParameterSupported = false,
    this.requestParameterSupported = true,
    this.requireRequestUriRegistration = false,
    this.opPolicyUri,
    this.opTosUri,
    this.promptValuesSupported,
    required super.src,
    required this.issuer,
    required this.jwksUri,
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    required this.userInfoEndpoint,
    this.endSessionEndpoint,
    this.revocationEndpoint,
    this.registrationEndpoint,
    this.scopesSupported,
    this.claimsSupported,
    this.grantTypesSupported = const [
      "authorization_code",
      "implicit",
    ],
    required this.responseTypesSupported,
    this.responseModesSupported = const ["query", "fragment"],
    this.checkSessionIFrame,
    this.deviceAuthorizationEndpoint,
    this.requestUriParameterSupported = true,
    this.tokenEndpointAuthMethodsSupported = const [
      'client_secret_basic',
    ],
    required this.idTokenSigningAlgValuesSupported,
    required this.subjectTypesSupported,
    required this.codeChallengeMethodsSupported,
  });

  factory OpenIdConfiguration.fromJson(Map<String, dynamic> json) =>
      _$OpenIdConfigurationFromJson(json);
}
