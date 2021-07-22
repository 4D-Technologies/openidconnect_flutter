part of openidconnect;

class OpenIdConnectWindows {
  static Future<String> authorizeInteractive({
    required BuildContext context,
    required String title,
    required String authorizationUrl,
    required String redirectUrl,
    required int popupWidth,
    required int popupHeight,
  }) async {
    final _controller = windowsWebView.WebviewController();

    final result = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        _controller.url.asBroadcastStream().listen((url) {
          //Handle the URL until we get to the redirect
          if (url.startsWith(redirectUrl)) {
            Navigator.pop(dialogContext, url);
          }
        });
        _controller.loadUrl(authorizationUrl);
        return AlertDialog(
          actions: [
            IconButton(
              onPressed: () => Navigator.pop(dialogContext, null),
              icon: Icon(Icons.close),
            ),
          ],
          content: windowsWebView.Webview(
            _controller,
          ),
          title: Text(title),
        );
      },
    );

    if (result == null) throw AuthenticationFailedException(ERROR_USER_CLOSED);

    return result;
  }
}
