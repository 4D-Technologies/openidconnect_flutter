library openidconnect;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:retry/retry.dart';
import 'package:url_launcher/url_launcher.dart';

part 'openidconnect_client.dart';
part './src/helpers.dart';

part './src/models/identity.dart';
part './src/models/event.dart';

part 'src/config/openidconfiguration.dart';

part 'src/models/requests/interactive_authorization_request.dart';
part 'src/models/requests/interactive_logout_request.dart';
part 'src/models/requests/password_authorization_request.dart';
part 'src/models/requests/refresh_request.dart';
part 'src/models/requests/logout_request.dart';
part 'src/models/requests/logout_token_request.dart';
part 'src/models/requests/revoke_token_request.dart';
part 'src/models/requests/device_authorization_request.dart';
part 'src/models/requests/user_info_request.dart';
part 'src/models/requests/token_request.dart';
part 'src/models/requests/user_registration_request.dart';

part 'src/models/responses/token_response.dart';
part 'src/models/responses/device_code_response.dart';
part 'src/models/responses/authorization_response.dart';

OpenIdConnectPlatform get _platform => OpenIdConnectPlatform.instance;

void _ensureSecureStorageInitialized() {
  WidgetsFlutterBinding.ensureInitialized();
}

class _OpenIdConnectSecureStorage {
  const _OpenIdConnectSecureStorage._();

  static Future<void> initialize([String? _]) async {
    _ensureSecureStorageInitialized();
    await _platform.secureStorageInitialize();
  }

  static Future<void> setString(String key, String value) async {
    _ensureSecureStorageInitialized();
    await _platform.secureStorageWrite(key: key, value: value);
  }

  static Future<String?> getString(String key) async {
    _ensureSecureStorageInitialized();
    return await _platform.secureStorageRead(key: key);
  }

  static Future<void> setInt(String key, int value) async {
    await setString(key, value.toString());
  }

  static Future<int?> getInt(String key) async {
    final value = await getString(key);
    if (value == null) return null;

    return int.tryParse(value);
  }

  static Future<void> remove(String key) async {
    _ensureSecureStorageInitialized();
    await _platform.secureStorageDelete(key: key);
  }
}

/// Provides static helpers for performing OpenID Connect discovery, login,
/// token refresh, logout, revocation, and user-info operations.
class OpenIdConnect {
  /// Storage key used to persist the PKCE code verifier during web redirects.
  static const CODE_VERIFIER_STORAGE_KEY = "openidconnect_code_verifier";

  /// Storage key used to persist the PKCE code challenge during web redirects.
  static const CODE_CHALLENGE_STORAGE_KEY = "openidconnect_code_challenge";

  /// Storage key used to persist the authorization request state during web
  /// redirects.
  static const STATE_STORAGE_KEY = "openidconnect_state";

  /// Initializes secure storage for compatibility with older callers.
  ///
  /// The [encryptionKey] parameter is retained for backward compatibility, even
  /// though the endorsed platform implementations now manage secure storage.
  static Future<void> initalizeEncryption(String encryptionKey) async {
    await _OpenIdConnectSecureStorage.initialize(encryptionKey);
  }

  /// Downloads and parses the OpenID Provider discovery document.
  ///
  /// Throws an [ArgumentError] when the document cannot be retrieved or when it
  /// is missing required OpenID Connect metadata fields.
  static Future<OpenIdConfiguration> getConfiguration(
    String discoveryDocumentUri,
  ) async {
    final response = await httpRetry(
      () => http.get(Uri.parse(discoveryDocumentUri)),
    );
    if (response == null) {
      throw ArgumentError(
        "The discovery document could not be found at: ${discoveryDocumentUri}",
      );
    }

    const requiredFields = <String>[
      'issuer',
      'jwks_uri',
      'authorization_endpoint',
      'token_endpoint',
      'userinfo_endpoint',
    ];

    final missingFields = requiredFields
        .where(
          (field) =>
              response[field] == null ||
              response[field].toString().trim().isEmpty,
        )
        .toList(growable: false);

    if (missingFields.isNotEmpty) {
      throw ArgumentError(
        'The discovery document was invalid and missing: ${missingFields.join(', ')}',
      );
    }

    return OpenIdConfiguration.fromJson(response);
  }

  /// Authenticates with the resource-owner password flow.
  static Future<AuthorizationResponse> authorizePassword({
    required PasswordAuthorizationRequest request,
  }) async {
    final response = await httpRetry(
      () => http.post(
        Uri.parse(request.configuration.tokenEndpoint),
        body: request.toMap(),
      ),
    );

    if (response == null) throw UnsupportedError('The response was null.');

    return AuthorizationResponse.fromJson(response);
  }

  /// Starts an interactive authorization-code flow and exchanges the returned
  /// code for tokens.
  ///
  /// Returns `null` when the user closes the flow before a response is
  /// received.
  static Future<AuthorizationResponse?> authorizeInteractive({
    required BuildContext context,
    required String title,
    required InteractiveAuthorizationRequest request,
  }) async {
    late String? responseUrl;

    final authEndpoint = Uri.parse(request.configuration.authorizationEndpoint);
    final uri = authEndpoint.replace(
      queryParameters: <String, String>{
        ...authEndpoint.queryParameters,
        ...request.toMap(),
      },
    );

    if (kIsWeb) {
      await _OpenIdConnectSecureStorage.setString(
        CODE_VERIFIER_STORAGE_KEY,
        request.codeVerifier,
      );
      await _OpenIdConnectSecureStorage.setString(
        CODE_CHALLENGE_STORAGE_KEY,
        request.codeChallenge,
      );
      await _OpenIdConnectSecureStorage.setString(
        STATE_STORAGE_KEY,
        request.state,
      );

      responseUrl = await _platform.authorizeInteractive(
        context: context,
        title: title,
        authorizationUrl: uri.toString(),
        redirectUrl: request.redirectUrl,
        popupHeight: request.popupHeight,
        popupWidth: request.popupWidth,
        useWebRedirectLoop: !request.useWebPopup,
      );

      if (responseUrl == null) {
        await _OpenIdConnectSecureStorage.remove(CODE_VERIFIER_STORAGE_KEY);
        await _OpenIdConnectSecureStorage.remove(CODE_CHALLENGE_STORAGE_KEY);
        await _OpenIdConnectSecureStorage.remove(STATE_STORAGE_KEY);
        return null;
      }

      await _OpenIdConnectSecureStorage.remove(CODE_VERIFIER_STORAGE_KEY);
      await _OpenIdConnectSecureStorage.remove(CODE_CHALLENGE_STORAGE_KEY);
      await _OpenIdConnectSecureStorage.remove(STATE_STORAGE_KEY);
    } else {
      responseUrl = await _platform.authorizeInteractive(
        context: context,
        title: title,
        authorizationUrl: uri.toString(),
        redirectUrl: request.redirectUrl,
        popupHeight: request.popupHeight,
        popupWidth: request.popupWidth,
      );
    }

    if (responseUrl == null) return null;

    return await _completeCodeExchange(request: request, url: responseUrl);
  }

  /// Starts RP-initiated logout against the provider's end-session endpoint.
  ///
  /// Returns the post-logout redirect URL when one is received, or `null` when
  /// the provider does not support interactive logout or the user closes the
  /// flow.
  static Future<String?> logoutInteractive({
    required BuildContext context,
    required String title,
    required InteractiveLogoutRequest request,
  }) async {
    if (request.configuration.endSessionEndpoint == null) return null;

    late String? responseUrl;

    final authEndpoint = Uri.parse(request.configuration.endSessionEndpoint!);
    final uri = authEndpoint.replace(
      queryParameters: <String, String>{
        ...authEndpoint.queryParameters,
        ...request.toMap(),
      },
    );

    if (kIsWeb) {
      responseUrl = await _platform.authorizeInteractive(
        context: context,
        title: title,
        authorizationUrl: uri.toString(),
        redirectUrl: request.postLogoutRedirectUrl,
        popupHeight: request.popupHeight,
        popupWidth: request.popupWidth,
        useWebRedirectLoop: !request.useWebPopup,
      );
    } else {
      responseUrl = await _platform.authorizeInteractive(
        context: context,
        title: title,
        authorizationUrl: uri.toString(),
        redirectUrl: request.postLogoutRedirectUrl,
        popupHeight: request.popupHeight,
        popupWidth: request.popupWidth,
      );
    }

    return responseUrl;
  }

  static Future<AuthorizationResponse> _completeCodeExchange({
    required InteractiveAuthorizationRequest request,
    required String url,
  }) async {
    final resultUri = Uri.parse(url);

    final error = resultUri.queryParameters['error'];

    if (error != null && error.isNotEmpty)
      throw ArgumentError(
        AUTHORIZE_ERROR_MESSAGE_FORMAT
            .replaceAll("%1", AUTHORIZE_ERROR_CODE)
            .replaceAll("%2", error),
      );

    var authCode = resultUri.queryParameters['code'];
    if (authCode == null || authCode.isEmpty)
      throw AuthenticationException(ERROR_INVALID_RESPONSE);

    var state =
        resultUri.queryParameters['state'] ??
        resultUri.queryParameters['session_state'];

    if (request.state.isNotEmpty) {
      if (state == null || state.isEmpty || state != request.state) {
        throw AuthenticationException(ERROR_INVALID_RESPONSE);
      }
    }

    final body = {
      "client_id": request.clientId,
      "redirect_uri": request.redirectUrl,
      "grant_type": "authorization_code",
      "code_verifier": request.codeVerifier,
      "code": authCode,
      if (request.clientSecret != null) "client_secret": request.clientSecret!,
    };

    final response = await httpRetry(
      () =>
          http.post(Uri.parse(request.configuration.tokenEndpoint), body: body),
    );

    if (response == null) throw UnsupportedError('The response was null.');

    return AuthorizationResponse.fromJson(response, state: state);
  }

  /// Starts the device authorization flow and polls until tokens are issued.
  static Future<AuthorizationResponse> authorizeDevice({
    required DeviceAuthorizationRequest request,
  }) async {
    var response = await httpRetry(
      () => http.post(
        Uri.parse(request.configuration.deviceAuthorizationEndpoint!),
        body: request.toMap(),
      ),
    );

    if (response == null) throw AuthenticationException(ERROR_INVALID_RESPONSE);

    final codeResponse = DeviceCodeResponse.fromJson(response);

    await launchUrl(
      Uri.parse(codeResponse.verificationUrlComplete).replace(
        queryParameters: <String, String>{"user_code": codeResponse.userCode},
      ),
      webViewConfiguration: WebViewConfiguration(enableJavaScript: true),
    );

    final pollingUri = Uri.parse(request.configuration.tokenEndpoint);
    var pollingBody = <String, String>{
      "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
      "device_code": codeResponse.deviceCode,
      "client_id": request.clientId,
      if (request.clientSecret != null) "client_secret": request.clientSecret!,
    };

    late AuthorizationResponse authorizationResponse;

    var pollingInterval = codeResponse.pollingInterval;

    while (true) {
      await Future<void>.delayed(Duration(seconds: pollingInterval));

      final pollingResponse = await http.post(pollingUri, body: pollingBody);

      final json = jsonDecode(pollingResponse.body) as Map<String, dynamic>;

      if (pollingResponse.statusCode >= 200 &&
          pollingResponse.statusCode < 300) {
        authorizationResponse = AuthorizationResponse.fromJson(json);
        break;
      }

      //Check the error message
      final error = json["error"]?.toString();
      if (error == null ||
          error == "invalid_token" ||
          error == "expired_token" ||
          error == "access_denied")
        throw AuthenticationException(json["error_description"].toString());

      if (error == "slow_down") pollingInterval += 2;

      if (DateTime.now().isAfter(codeResponse.expiresAt))
        throw AuthenticationException(ERROR_USER_CLOSED);
    }

    return authorizationResponse;
  }

  /// Requests a device code without completing the interactive device flow.
  static Future<DeviceCodeResponse> authorizeDeviceGetDeviceCodeResponse({
    required DeviceAuthorizationRequest request,
  }) async {
    var response = await httpRetry(
      () => http.post(
        Uri.parse(request.configuration.deviceAuthorizationEndpoint!),
        body: request.toMap(),
      ),
    );

    if (response == null) throw AuthenticationException(ERROR_INVALID_RESPONSE);

    final codeResponse = DeviceCodeResponse.fromJson(response);

    return codeResponse;
  }

  /// Completes a previously started device authorization flow by polling the
  /// token endpoint with the supplied [codeResponse].
  static Future<AuthorizationResponse>
  authorizeDeviceCompleteDeviceCodeResponseRequest({
    required DeviceAuthorizationRequest request,
    required DeviceCodeResponse codeResponse,
  }) async {
    await launchUrl(
      Uri.parse(codeResponse.verificationUrlComplete).replace(
        queryParameters:
            // ignore: unnecessary_cast
            {"user_code": codeResponse.userCode} as Map<String, dynamic>,
      ),
      webViewConfiguration: WebViewConfiguration(
        enableJavaScript: true,
        enableDomStorage: true,
      ),
      browserConfiguration: BrowserConfiguration(showTitle: false),
    );

    final pollingUri = Uri.parse(request.configuration.tokenEndpoint);
    var pollingBody = {
      "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
      "device_code": codeResponse.deviceCode,
      "client_id": request.clientId,
    };

    if (request.clientSecret != null)
      pollingBody = {"client_secret": request.clientSecret!, ...pollingBody};

    late AuthorizationResponse authorizationResponse;

    var pollingInterval = codeResponse.pollingInterval;

    while (true) {
      await Future<void>.delayed(Duration(seconds: pollingInterval));

      final pollingResponse = await http.post(pollingUri, body: pollingBody);

      final json = jsonDecode(pollingResponse.body) as Map<String, dynamic>;

      if (pollingResponse.statusCode >= 200 &&
          pollingResponse.statusCode < 300) {
        authorizationResponse = AuthorizationResponse.fromJson(json);
        break;
      }

      //Check the error message
      final error = json["error"]?.toString();
      if (error == null ||
          error == "invalid_token" ||
          error == "expired_token" ||
          error == "access_denied")
        throw AuthenticationException(json["error_description"].toString());

      if (error == "slow_down") pollingInterval += 2;

      if (DateTime.now().isAfter(codeResponse.expiresAt))
        throw AuthenticationException(ERROR_USER_CLOSED);
    }

    return authorizationResponse;
  }

  /// Exchanges a refresh token for a new access token and related metadata.
  static Future<AuthorizationResponse> refreshToken({
    required RefreshRequest request,
  }) async {
    final response = await httpRetry(
      () => http.post(
        Uri.parse(request.configuration.tokenEndpoint),
        body: request.toMap(),
      ),
    );

    if (response == null) throw AuthenticationException(ERROR_INVALID_RESPONSE);

    return AuthorizationResponse.fromJson(
      response,
      fallbackIdToken: request.currentIdToken,
    );
  }

  /// Performs non-interactive logout against the provider end-session endpoint.
  static Future<void> logout({required LogoutRequest request}) async {
    if (request.configuration.endSessionEndpoint == null) return;

    final url = Uri.parse(
      request.configuration.endSessionEndpoint!,
    ).replace(queryParameters: request.toMap());

    try {
      await httpRetry(() => http.get(url));
    } on HttpResponseException catch (e) {
      throw LogoutException(e.toString());
    }
  }

  /// Completes a web redirect-loop login flow after the application restarts.
  ///
  /// Returns `null` on platforms that do not use web redirect-loop startup
  /// processing.
  static Future<AuthorizationResponse?> processStartup({
    required String clientId,
    String? clientSecret,
    required String redirectUrl,
    required Iterable<String> scopes,
    required OpenIdConfiguration configuration,
    bool autoRefresh = true,
  }) async {
    if (!kIsWeb)
      return null; //TODO: Change this to not bypass if other platforms need these.

    final response = await _platform.processStartup();

    if (response == null) return null;

    final codeVerifier = await _OpenIdConnectSecureStorage.getString(
      CODE_VERIFIER_STORAGE_KEY,
    );
    final codeChallenge = await _OpenIdConnectSecureStorage.getString(
      CODE_CHALLENGE_STORAGE_KEY,
    );
    final state = await _OpenIdConnectSecureStorage.getString(
      STATE_STORAGE_KEY,
    );

    await _OpenIdConnectSecureStorage.remove(CODE_VERIFIER_STORAGE_KEY);
    await _OpenIdConnectSecureStorage.remove(CODE_CHALLENGE_STORAGE_KEY);
    await _OpenIdConnectSecureStorage.remove(STATE_STORAGE_KEY);

    if (codeVerifier == null || codeChallenge == null || state == null) {
      throw AuthenticationException(ERROR_INVALID_RESPONSE);
    }

    final result = await _completeCodeExchange(
      request: InteractiveAuthorizationRequest._(
        clientId: clientId,
        clientSecret: clientSecret,
        redirectUrl: redirectUrl,
        scopes: scopes,
        configuration: configuration,
        autoRefresh: autoRefresh,
        codeVerifier: codeVerifier,
        codeChallenge: codeChallenge,
        state: state,
      ),
      url: response,
    );

    return result;
  }

  /// Revokes a refresh or access token at the provider revocation endpoint.
  static Future<void> revokeToken({
    required RevokeTokenRequest request,
    bool useBasicAuth = true,
  }) async {
    if (request.configuration.revocationEndpoint == null) return;

    final uri = Uri.parse(request.configuration.revocationEndpoint!);
    final headers = <String, String>{
      "Content-Type": "application/x-www-form-urlencoded",
    };

    // Prefer client authentication via HTTP Basic when client secret is provided
    if (request.clientId != null && request.clientSecret != null) {
      final creds = base64Encode(
        utf8.encode('${request.clientId}:${request.clientSecret}'),
      );
      headers["Authorization"] = "Basic $creds";
    }

    try {
      await httpRetry(
        () => http.post(
          uri,
          body: request.toMap(useBasicAuth: useBasicAuth),
          headers: headers,
        ),
      );
    } on HttpResponseException catch (e) {
      throw RevokeException(e.toString());
    }
  }

  /// Calls the OpenID Connect UserInfo endpoint and returns the decoded JSON
  /// response.
  static Future<Map<String, dynamic>> getUserInfo({
    required UserInfoRequest request,
  }) async {
    try {
      final response = await httpRetry(
        () => http.get(
          Uri.parse(request.configuration.userInfoEndpoint),
          headers: {
            "Authorization": "${request.tokenType} ${request.accessToken}",
          },
        ),
      );

      if (response == null) throw UserInfoException(ERROR_INVALID_RESPONSE);

      return response;
    } on Exception catch (e) {
      throw UserInfoException(e.toString());
    }
  }

  /// Calls the dynamic client registration endpoint for the current provider.
  static Future<void> registerUser({
    required UserRegistrationRequest request,
  }) async {
    try {
      final response = await httpRetry(
        () => http.get(
          Uri.parse(request.configuration.registrationEndpoint!),
          headers: {
            "Authorization": "${request.tokenType} ${request.accessToken}",
          },
        ),
      );

      if (response == null) throw UserInfoException(ERROR_INVALID_RESPONSE);
    } on Exception catch (e) {
      throw UserInfoException(e.toString());
    }
  }
}
