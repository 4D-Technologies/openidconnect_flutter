import 'dart:math';

import 'package:flutter/material.dart';
import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';
import 'package:webview_windows/webview_windows.dart';

class OpenIdConnectWindows extends OpenIdConnectPlatform {
  static void registerWith() {
    OpenIdConnectPlatform.instance = OpenIdConnectWindows();
  }

  @override
  Future<String?> processStartup() {
    return Future.value(null);
  }

  @override
  Future<String?> authorizeInteractive({
    required BuildContext context,
    required String title,
    required String authorizationUrl,
    required String redirectUrl,
    required int popupWidth,
    required int popupHeight,
    bool useWebRedirectLoop = false,
  }) async {
    final _controller = WebviewController();
    try {
      //Create the url
      await _controller.initialize();

      final result = await showDialog<String?>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          _controller.url.listen((url) {
            if (url.startsWith(redirectUrl)) {
              Navigator.pop(dialogContext, url);
            }
          });

          return AlertDialog(
            actions: [
              IconButton(
                onPressed: () => Navigator.pop(dialogContext, null),
                icon: const Icon(Icons.close),
              ),
            ],
            content: SizedBox(
              width:
                  min(popupWidth.toDouble(), MediaQuery.of(context).size.width),
              height: min(
                  popupHeight.toDouble(), MediaQuery.of(context).size.height),
              child: Webview(
                _controller,
                permissionRequested: (url, permissionKind, isUserInitiated) =>
                    _onPermissionRequested(
                  url,
                  permissionKind,
                  isUserInitiated,
                  dialogContext,
                ),
              ),
            ),
            title: Text(title),
          );
        },
      );

      if (result == null) throw AuthenticationException(ERROR_USER_CLOSED);

      return result;
    } finally {
      _controller.dispose();
    }
  }

  Future<WebviewPermissionDecision> _onPermissionRequested(
      String url,
      WebviewPermissionKind kind,
      bool isUserInitiated,
      BuildContext context) async {
    final decision = await showDialog<WebviewPermissionDecision>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('WebView permission requested'),
        content: Text('WebView has requested permission \'$kind\''),
        actions: <Widget>[
          TextButton(
            onPressed: () =>
                Navigator.pop(context, WebviewPermissionDecision.deny),
            child: const Text('Deny'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, WebviewPermissionDecision.allow),
            child: const Text('Allow'),
          ),
        ],
      ),
    );

    return decision ?? WebviewPermissionDecision.none;
  }
}
