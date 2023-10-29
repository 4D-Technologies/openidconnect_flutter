part of openidconnect;

class OpenIdConnectAndroidiOS {
  static Future<String> authorizeInteractive({
    required BuildContext context,
    required String title,
    required String authorizationUrl,
    required String redirectUrl,
    required int popupWidth,
    required int popupHeight,
  }) async {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);

    //Create the url
    final result = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          actions: [
            IconButton(
              onPressed: () => Navigator.pop(dialogContext, null),
              icon: Icon(Icons.close),
            ),
          ],
          content: Container(
            width:
                min(popupWidth.toDouble(), MediaQuery.of(context).size.width),
            height:
                min(popupHeight.toDouble(), MediaQuery.of(context).size.height),
            child: flutterWebView.WebViewWidget(
              controller: controller
                ..setNavigationDelegate(
                  NavigationDelegate(
                    onPageFinished: (String url) {
                      if (url.startsWith(redirectUrl)) {
                        Navigator.pop(dialogContext, url);
                      }
                    },
                  ),
                )
                ..loadRequest(Uri.parse(authorizationUrl)),
            ),
          ),
          title: Text(title),
        );
      },
    );

    if (result == null) throw AuthenticationException(ERROR_USER_CLOSED);

    return result;
  }
}
