import 'dart:async';

import 'package:web/web.dart' as html;

// In order to *not* need this ignore, consider extracting the "web" version
// of your plugin as a separate package, instead of inlining it in the same
// package as the core of your plugin.
// ignore: avoid_web_libraries_in_flutter
import 'package:flutter/widgets.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';

/// A web implementation of the OpenidconnectWeb plugin.
class OpenIdConnectWeb extends OpenIdConnectPlatform {
  static void registerWith(Registrar registrar) {
    OpenIdConnectPlatform.instance = OpenIdConnectWeb();
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
    if (useWebRedirectLoop) {
      const authDestinationKey = "openidconnect_auth_destination_url";
      html.window.sessionStorage
          .setItem(authDestinationKey, html.window.location.toString());
      html.window.location.assign(authorizationUrl);

      // Same-tab redirect flows intentionally hand control to the browser and
      // resume via processStartup/OpenIdConnectClient.create() after the app is
      // loaded again on the callback page.
      return Completer<String?>().future;
    }

    final top = (html.window.outerHeight - popupHeight) / 2 +
        (html.window.screen.availHeight);
    final left = (html.window.outerWidth - popupWidth) / 2 +
        (html.window.screen.availWidth);

    var options =
        'width=${popupWidth},height=${popupHeight},toolbar=no,location=no,directories=no,status=no,menubar=no,copyhistory=no&top=$top,left=$left';

    final child = html.window.open(
      authorizationUrl,
      "open_id_connect_authentication",
      options,
    );

    final c = new Completer<String>();
    html.window.onMessage.first.then((event) {
      final url = event.data.toString();
      c.complete(url);
      child?.close();
    });

    return c.future;
  }

  @override
  Future<String?> processStartup() async {
    const authResponseKey = "openidconnect_auth_response_info";

    final url = html.window.sessionStorage.getItem(authResponseKey);
    html.window.sessionStorage.removeItem(authResponseKey);

    return url;
  }
}
