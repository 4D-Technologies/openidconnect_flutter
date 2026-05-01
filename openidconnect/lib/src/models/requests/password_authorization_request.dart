part of '../../../openidconnect.dart';

/// Request body for the resource-owner password grant.
class PasswordAuthorizationRequest extends TokenRequest {
  /// Creates a password-grant token request.
  PasswordAuthorizationRequest({
    required super.clientId,
    super.clientSecret,
    required super.scopes,
    required String userName,
    required String password,
    required super.configuration,
    required bool autoRefresh,
    super.prompts,
    Map<String, String>? additionalParameters,
  }) : super(
         grantType: "password",
         additionalParameters: {
           "username": userName,
           "password": password,
           ...?additionalParameters,
         },
       );
}
