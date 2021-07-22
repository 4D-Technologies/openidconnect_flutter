import 'dart:async';
// In order to *not* need this ignore, consider extracting the "web" version
// of your plugin as a separate package, instead of inlining it in the same
// package as the core of your plugin.
// ignore: avoid_web_libraries_in_flutter
import 'package:flutter/widgets.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';
import "dart:html" as html;

/// A web implementation of the OpenidconnectWeb plugin.
class OpenIdConnectWeb extends OpenIdConnectPlatform {
  static void registerWith(Registrar registrar) {
    OpenIdConnectPlatform.instance = OpenIdConnectWeb();
  }

  @override
  Future<String> authorizeInteractive({
    required BuildContext context,
    required String title,
    required InteractiveAuthorizationPlatformRequest request,
  }) async {
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

    final top = (html.window.outerHeight - request.webPopupHeight) / 2 +
        (html.window.screen?.available.top ?? 0);
    final left = (html.window.outerWidth - request.webPopupWidth) / 2 +
        (html.window.screen?.available.left ?? 0);

    var options =
        'width=${request.webPopupWidth},height=${request.webPopupHeight},toolbar=no,location=no,directories=no,status=no,menubar=no,copyhistory=no&top=$top,left=$left';

    final child = html.window.open(
      uri.toString(),
      "open_id_connect_authentication",
      options,
    );

    final c = new Completer<String>();
    html.window.onMessage.first.then((event) {
      final url = event.data.toString();
      print(url);
      c.complete(url);
      child.close();
    });

    //This handles the user closing the window without a response
    // while (!c.isCompleted) {
    //   await Future<void>.delayed(Duration(milliseconds: 500));
    //   if ((child.closed ?? false) && !c.isCompleted)
    //     c.completeError(
    //       AuthenticationFailedException(ERROR_USER_CLOSED),
    //     );

    //   if (c.isCompleted) break;
    // }

    return await c.future;
  }
}
