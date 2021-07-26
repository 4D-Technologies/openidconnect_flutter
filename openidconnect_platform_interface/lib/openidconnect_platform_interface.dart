library openidconnect_platform_interface;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

part './src/method_channel_openidconnect.dart';

const String AUTHORIZE_ERROR_MESSAGE_FORMAT =
    "Failed to authorize: [error: %1, description: %2]";
const String AUTHORIZE_ERROR_CODE = "authorize_failed";
const String ERROR_MESSAGE_FORMAT =
    "Request Failed: [error: request_failed, description: %2]";
const ERROR_USER_CLOSED = "user_closed";
const ERROR_INVALID_RESPONSE = "invalid_response";

abstract class OpenIdConnectPlatform extends PlatformInterface {
  static final Object _token = Object();

  OpenIdConnectPlatform() : super(token: _token);

  static OpenIdConnectPlatform _instance = MethodChannelOpenIdConnect();

  static OpenIdConnectPlatform get instance => _instance;

  static set instance(OpenIdConnectPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String> authorizeInteractive({
    required String title,
    required String authorizationUrl,
    required String redirectUrl,
    required int popupWidth,
    required int popupHeight,
  });
}
