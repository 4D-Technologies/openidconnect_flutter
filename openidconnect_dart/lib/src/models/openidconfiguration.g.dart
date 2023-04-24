// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'openidconfiguration.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OpenIdConfiguration _$OpenIdConfigurationFromJson(Map<String, dynamic> json) =>
    OpenIdConfiguration(
      acrValuesSupported: (json['acr_values_supported'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      idTokenEncryptionAlgValuesSupported:
          (json['id_token_encryption_alg_values_supported'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      idTokenEncryptionEncValuesSupported:
          (json['id_token_encryption_enc_values_supported'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      userinfoSigningAlgValuesSupported:
          (json['userinfo_signing_alg_values_supported'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      userinfoEncryptionAlgValuesSupported:
          (json['userinfo_encryption_alg_values_supported'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      userinfoEncryptionEncValuesSupported:
          (json['userinfo_encryption_enc_values_supported'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      requestObjectSigningAlgValuesSupported:
          (json['request_object_signing_alg_values_supported']
                  as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      requestObjectEncryptionAlgValuesSupported:
          (json['request_object_encryption_alg_values_supported']
                  as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      requestObjectEncryptionEncValuesSupported:
          (json['request_object_encryption_enc_values_supported']
                  as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      tokenEndpointAuthSigningAlgValuesSupported:
          (json['token_endpoint_auth_signing_alg_values_supported']
                  as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      displayValuesSupported:
          (json['display_values_supported'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      claimTypesSupported: (json['claim_types_supported'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const ['normal'],
      serviceDocumentation: json['service_documentation'] as String?,
      claimsLocalesSupported:
          (json['claims_locales_supported'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      uiLocalesSupported: (json['ui_locales_supported'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      claimsParameterSupported:
          json['claims_parameter_supported'] as bool? ?? false,
      requestParameterSupported:
          json['request_parameter_supported'] as bool? ?? true,
      requireRequestUriRegistration:
          json['require_request_uri_registration'] as bool? ?? false,
      opPolicyUri: json['op_policy_uri'] as String?,
      opTosUri: json['op_tos_uri'] as String?,
      promptValuesSupported: (json['prompt_values_supported'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      src: readSelf(json, '') as Map<String, dynamic>,
      issuer: json['issuer'] as String,
      jwksUri: json['jwks_uri'] as String,
      authorizationEndpoint: json['authorization_endpoint'] as String,
      tokenEndpoint: json['token_endpoint'] as String?,
      userInfoEndpoint: json['userinfo_endpoint'] as String?,
      endSessionEndpoint: json['end_session_endpoint'] as String?,
      revocationEndpoint: json['revocation_endpoint'] as String?,
      registrationEndpoint: json['registration_endpoint'] as String?,
      scopesSupported: (json['scopes_supported'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      claimsSupported: (json['claims_supported'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      grantTypesSupported: (json['grant_types_supported'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const ["authorization_code", "implicit"],
      responseTypesSupported:
          (json['response_types_supported'] as List<dynamic>)
              .map((e) => e as String)
              .toList(),
      responseModesSupported:
          (json['response_modes_supported'] as List<dynamic>?)
                  ?.map((e) => e as String)
                  .toList() ??
              const ["query", "fragment"],
      checkSessionIFrame: json['check_session_iframe'] as String?,
      deviceAuthorizationEndpoint:
          json['device_authorization_endpoint'] as String?,
      requestUriParameterSupported:
          json['request_uri_parameter_supported'] as bool? ?? true,
      tokenEndpointAuthMethodsSupported:
          (json['token_endpoint_auth_methods_supported'] as List<dynamic>?)
                  ?.map((e) => e as String)
                  .toList() ??
              const ['client_secret_basic'],
      idTokenSigningAlgValuesSupported:
          (json['id_token_signing_alg_values_supported'] as List<dynamic>)
              .map((e) => e as String)
              .toList(),
      subjectTypesSupported: (json['subject_types_supported'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      codeChallengeMethodsSupported:
          (json['code_challenge_methods_supported'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
    );
