library openidconnect;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cryptography/cryptography.dart' as crypto;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:retry/retry.dart';
import 'package:webview_flutter/webview_flutter.dart' as flutterWebView;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

part './src/openidconnect_client.dart';
part './src/android_ios.dart';
part './src/helpers.dart';

part './src/models/identity.dart';
part './src/models/event.dart';

part 'src/config/openidconfiguration.dart';

part 'src/models/requests/interactive_authorization_request.dart';
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

final _platform = OpenIdConnectPlatform.instance;

class OpenIdConnect {
  static const CODE_VERIFIER_STORAGE_KEY = "openidconnect_code_verifier";
  static const CODE_CHALLENGE_STORAGE_KEY = "openidconnect_code_challenge";

  static Future<OpenIdConfiguration> getConfiguration(
      String discoveryDocumentUri) async {
    final response =
        await httpRetry(() => http.get(Uri.parse(discoveryDocumentUri)));
    if (response == null) {
      throw ArgumentError(
          "The discovery document could not be found at: ${discoveryDocumentUri}");
    }

    return OpenIdConfiguration.fromJson(response);
  }

  static Future<AuthorizationResponse> authorizePassword(
      {required PasswordAuthorizationRequest request}) async {
    final response = await httpRetry(
      () => http.post(
        Uri.parse(request.configuration.tokenEndpoint),
        body: request.toMap(),
      ),
    );

    if (response == null) throw UnsupportedError('The response was null.');

    return AuthorizationResponse.fromJson(response);
  }

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

    //These are special cases for the various different platforms because of limitations in pubspec.yaml
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      responseUrl = await OpenIdConnectAndroidiOS.authorizeInteractive(
        context: context,
        title: title,
        authorizationUrl: uri.toString(),
        redirectUrl: request.redirectUrl,
        popupHeight: request.popupHeight,
        popupWidth: request.popupWidth,
      );
    } else if (kIsWeb) {
      final storage = FlutterSecureStorage();
      await storage.write(
          key: CODE_VERIFIER_STORAGE_KEY, value: request.codeVerifier);
      await storage.write(
          key: CODE_CHALLENGE_STORAGE_KEY, value: request.codeChallenge);

      responseUrl = await _platform.authorizeInteractive(
        context: context,
        title: title,
        authorizationUrl: uri.toString(),
        redirectUrl: request.redirectUrl,
        popupHeight: request.popupHeight,
        popupWidth: request.popupWidth,
        useWebRedirectLoop: !request.useWebPopup,
      );

      if (responseUrl == null) return null;

      await storage.delete(key: CODE_VERIFIER_STORAGE_KEY);
      await storage.delete(key: CODE_CHALLENGE_STORAGE_KEY);
    } else {
      //TODO add other implementations as they become available. For now, all desktop uses device code flow instead of authorization code flow
      return await OpenIdConnect.authorizeDevice(
        request: DeviceAuthorizationRequest(
          audience: null,
          clientId: request.clientId,
          clientSecret: request.clientSecret,
          configuration: request.configuration,
          scopes: request.scopes,
          additionalParameters: request.additionalParameters,
        ),
      );
    }

    return await _completeCodeExchange(request: request, url: responseUrl);
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

    var state = resultUri.queryParameters['state'] ??
        resultUri.queryParameters['session_state'];

    final body = {
      "client_id": request.clientId,
      "redirect_uri": request.redirectUrl,
      "grant_type": "authorization_code",
      "code_verifier": request.codeVerifier,
      "code": authCode,
      if (request.clientSecret != null) "client_secret": request.clientSecret!,
      if (state != null && state.isNotEmpty) "state": state
    };

    final response = await httpRetry(
      () => http.post(
        Uri.parse(request.configuration.tokenEndpoint),
        body: body,
      ),
    );

    if (response == null) if (response == null)
      throw UnsupportedError('The response was null.');

    return AuthorizationResponse.fromJson(response);
  }

  static Future<AuthorizationResponse> authorizeDevice(
      {required DeviceAuthorizationRequest request}) async {
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
        queryParameters: <String, String>{
          "user_code": codeResponse.userCode,
        },
      ),
      webViewConfiguration: WebViewConfiguration(
        enableJavaScript: true,
      ),
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

  static Future<AuthorizationResponse> refreshToken(
      {required RefreshRequest request}) async {
    final response = await httpRetry(
      () => http.post(
        Uri.parse(request.configuration.tokenEndpoint),
        body: request.toMap(),
      ),
    );

    if (response == null) throw AuthenticationException(ERROR_INVALID_RESPONSE);

    return AuthorizationResponse.fromJson(response);
  }

  static Future<void> logout({required LogoutRequest request}) async {
    if (request.configuration.endSessionEndpoint == null) return;

    final url = Uri.parse(request.configuration.endSessionEndpoint!)
        .replace(queryParameters: request.toMap());

    try {
      await httpRetry(
        () => http.get(url),
      );
    } on HttpResponseException catch (e) {
      throw LogoutException(e.toString());
    }
  }

  /// Keycloak compatible logout
  /// see https://www.keycloak.org/docs/latest/securing_apps/#logout-endpoint
  static Future<void> logoutToken({required LogoutTokenRequest request}) async {
    if (request.configuration.endSessionEndpoint == null) return;

    final url = Uri.parse(request.configuration.endSessionEndpoint!);
    try {
      await httpRetry(
        () => http.post(url, body: request.toMap()),
      );
    } on HttpResponseException catch (e) {
      throw LogoutException(e.toString());
    }
  }

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

    final storage = new FlutterSecureStorage();
    final codeVerifier = await storage.read(key: CODE_VERIFIER_STORAGE_KEY);
    final codeChallenge = await storage.read(key: CODE_CHALLENGE_STORAGE_KEY);

    await storage.delete(key: CODE_VERIFIER_STORAGE_KEY);
    await storage.delete(key: CODE_CHALLENGE_STORAGE_KEY);

    final result = await _completeCodeExchange(
      request: InteractiveAuthorizationRequest._(
        clientId: clientId,
        clientSecret: clientSecret,
        redirectUrl: redirectUrl,
        scopes: scopes,
        configuration: configuration,
        autoRefresh: autoRefresh,
        codeVerifier: codeVerifier!,
        codeChallenge: codeChallenge!,
      ),
      url: response,
    );

    return result;
  }

  static Future<void> revokeToken({required RevokeTokenRequest request}) async {
    if (request.configuration.endSessionEndpoint == null) return;

    try {
      await httpRetry(
        () => http.post(
          Uri.parse(request.configuration.revocationEndpoint!),
          body: request.toMap(),
          headers: {
            "Authorization": "Bearer ${request.token}",
          },
        ),
      );
    } on HttpResponseException catch (e) {
      throw RevokeException(e.toString());
    }
  }

  static Future<Map<String, dynamic>> getUserInfo(
      {required UserInfoRequest request}) async {
    try {
      final response = await httpRetry(
        () => http.get(
          Uri.parse(request.configuration.userInfoEndpoint),
          headers: {
            "Authorization": "${request.tokenType} ${request.accessToken}"
          },
        ),
      );

      if (response == null) throw UserInfoException(ERROR_INVALID_RESPONSE);

      return response;
    } on Exception catch (e) {
      throw UserInfoException(e.toString());
    }
  }

  static Future<void> registerUser(
      {required UserRegistrationRequest request}) async {
    try {
      final response = await httpRetry(
        () => http.get(
          Uri.parse(request.configuration.registrationEndpoint!),
          headers: {
            "Authorization": "${request.tokenType} ${request.accessToken}"
          },
        ),
      );

      if (response == null) throw UserInfoException(ERROR_INVALID_RESPONSE);
    } on Exception catch (e) {
      throw UserInfoException(e.toString());
    }
  }
}
