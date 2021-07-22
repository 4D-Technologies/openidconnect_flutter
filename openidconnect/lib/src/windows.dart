part of openidconnect;

class OpenIdConnectWindows {
  static Future<String> authorizeInteractive({
    required BuildContext context,
    required String title,
    required InteractiveAuthorizationPlatformRequest request,
  }) async {
    final _controller = windowsWebView.WebviewController();

    final result = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        _controller.url.asBroadcastStream().listen((url) {
          //Handle the URL until we get to the redirect
          if (url.startsWith(request.redirectUrl!)) {
            Navigator.pop(dialogContext, url);
          }
        });
        _controller.loadUrl(request.configuration.authorizationEndpoint);
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
