library openidconnect;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:openidconnect/src/models/responses/device_code_response.dart';
import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:retry/retry.dart';
import 'package:webview_flutter/webview_flutter.dart' as flutterWebView;
import 'package:webview_windows/webview_windows.dart' as windowsWebView;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

part './src/openidconnect_client.dart';
part './src/android_ios.dart';
part './src/windows.dart';
part './src/helpers.dart';

part './src/models/identity.dart';
part './src/models/event.dart';

part 'src/models/requests/interactive_authorization_request.dart';
part 'src/models/requests/password_authorization_request.dart';
part 'src/models/requests/refresh_request.dart';
part 'src/models/requests/logout_request.dart';
part 'src/models/requests/revoke_token_request.dart';
part 'src/models/requests/device_authorization_request.dart';

final _platform = OpenIdConnectPlatform.instance;

class OpenIdConnect {
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

  static Future<AuthorizationResponse> authorizeInteractive({
    required BuildContext context,
    required String title,
    required InteractiveAuthorizationRequest request,
  }) async {
    late String responseUrl;

    final uri = Uri.parse(request.configuration.authorizationEndpoint).replace(
      queryParameters: {
        "client_id": request.clientId,
        "redirect_uri": request.redirectUrl,
        "response_type": "code",
        "scope": request.scopes.join(" "),
        "code_challenge_method": "S256",
        "code_challenge": request.codeChallenge,
      },
    );

    //These are special cases for the various different platforms because of limitations in pubspec.yaml
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      responseUrl = await OpenIdConnectAndroidiOS.authorizeInteractive(
        context: context,
        title: title,
        authorizationUrl: uri.toString(),
        redirectUrl: request.redirectUrl!,
        popupHeight: request.popupHeight,
        popupWidth: request.popupWidth,
      );
    } else if (!kIsWeb && Platform.isWindows) {
      responseUrl = await OpenIdConnectWindows.authorizeInteractive(
        context: context,
        title: title,
        authorizationUrl: uri.toString(),
        redirectUrl: request.redirectUrl!,
        popupHeight: request.popupHeight,
        popupWidth: request.popupWidth,
      );
    } else {
      responseUrl = await _platform.authorizeInteractive(
        title: title,
        authorizationUrl: uri.toString(),
        redirectUrl: request.redirectUrl!,
        popupHeight: request.popupHeight,
        popupWidth: request.popupWidth,
      );
    }

    return await _completeCodeExchange(request: request, url: responseUrl);
  }

  static Future<AuthorizationResponse> _completeCodeExchange({
    required InteractiveAuthorizationPlatformRequest request,
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
      throw AuthenticationFailedException(ERROR_INVALID_RESPONSE);

    var state = resultUri.queryParameters['state'] ??
        resultUri.queryParameters['session_state'];

    final body = {
      "client_id": request.clientId,
      "redirect_uri": request.redirectUrl,
      "grant_type": "authorization_code",
      "code_verifier": request.codeVerifier,
      "code": authCode,
    };

    if (request.clientSecret != null)
      body.addAll({"client_secret": request.clientSecret!});

    if (state != null && state.isNotEmpty) body.addAll({"state": state});

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

    if (response == null)
      throw AuthenticationFailedException(ERROR_INVALID_RESPONSE);

    final codeResponse = DeviceCodeResponse.fromJson(response);

    await launch(
      Uri.parse(codeResponse.verificationUrlComplete).replace(
        queryParameters: {"user_code": codeResponse.userCode},
      ).toString(),
      enableJavaScript: true,
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
      await Future.delayed(Duration(seconds: pollingInterval));

      final pollingResponse = await http.post(pollingUri, body: pollingBody);

      final json = jsonDecode(pollingResponse.body);

      if (pollingResponse.statusCode >= 200 &&
          pollingResponse.statusCode < 300) {
        authorizationResponse = AuthorizationResponse.fromJson(json);
        break;
      }

      //Check the error message
      final error = json["error"]?.toString();
      if (error == null || error == "expired_token" || error == "access_denied")
        throw AuthenticationFailedException(
            json["error_description"].toString());

      if (error == "slow_down") pollingInterval += 2;

      if (DateTime.now().isAfter(codeResponse.expiresAt))
        throw AuthenticationFailedException(ERROR_USER_CLOSED);
    }

    return authorizationResponse;
  }

  static Future<AuthorizationResponse> completeAuthorizeInteractive({
    required InteractiveAuthorizationRequest request,
    required String resultUrl,
  }) async {
    final resultUri = Uri.parse(resultUrl);

    final error = resultUri.queryParameters['error'];

    if (error != null && error.isNotEmpty)
      throw ArgumentError(
        AUTHORIZE_ERROR_MESSAGE_FORMAT
            .replaceAll("%1", AUTHORIZE_ERROR_CODE)
            .replaceAll("%2", error),
      );

    var authCode = resultUri.queryParameters['code'];
    if (authCode == null || authCode.isEmpty)
      throw AuthenticationFailedException(ERROR_INVALID_RESPONSE);

    final body = {
      "client_id": request.clientId,
      "redirect_uri": request.redirectUrl,
      "grant_type": "authorization_code",
      "code_verifier": request.codeVerifier,
      "code": authCode
    };

    if (request.clientSecret != null)
      body.addAll({"client_secret": request.clientSecret!});

    final response = await httpRetry(
      () => http.post(
        Uri.parse(request.configuration.tokenEndpoint),
        body: body,
      ),
    );

    if (response == null) if (response == null)
      throw AuthenticationFailedException(ERROR_INVALID_RESPONSE);

    return AuthorizationResponse.fromJson(response);
  }

  static Future<AuthorizationResponse> refreshToken(
      {required RefreshRequest request}) async {
    final response = await httpRetry(
      () => http.post(
        Uri.parse(request.configuration.tokenEndpoint),
        body: request.toMap(),
      ),
    );

    if (response == null)
      throw AuthenticationFailedException(ERROR_INVALID_RESPONSE);

    return AuthorizationResponse.fromJson(response);
  }

  static Future<bool> logout({required LogoutRequest request}) async {
    if (request.configuration.endSessionEndpoint == null) return true;

    final url = Uri.parse(request.configuration.endSessionEndpoint!)
        .replace(queryParameters: request.toMap());

    try {
      await httpRetry(
        () => http.get(url),
      );

      return true;
    } on HttpResponseException catch (e) {
      print(e.toString());
      return false;
    }
  }

  static Future<bool> revokeToken({required RevokeTokenRequest request}) async {
    if (request.configuration.endSessionEndpoint == null) return false;

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
      return true;
    } on HttpResponseException catch (e) {
      print(e.toString());
      return false;
    }
  }
}
