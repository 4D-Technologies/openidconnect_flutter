import 'dart:async';
// In order to *not* need this ignore, consider extracting the "web" version
// of your plugin as a separate package, instead of inlining it in the same
// package as the core of your plugin.
// ignore: avoid_web_libraries_in_flutter
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
    required String title,
    required String authorizationUrl,
    required String redirectUrl,
    required int popupWidth,
    required int popupHeight,
  }) async {
    final top = (html.window.outerHeight - popupHeight) / 2 +
        (html.window.screen?.available.top ?? 0);
    final left = (html.window.outerWidth - popupWidth) / 2 +
        (html.window.screen?.available.left ?? 0);

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
      child.close();
    });

    return await c.future;
  }
}
