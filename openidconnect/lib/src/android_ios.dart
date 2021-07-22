part of openidconnect;

class OpenIdConnectAndroidiOS {
  static Future<String> authorizeInteractive({
    required BuildContext context,
    required String title,
    required InteractiveAuthorizationPlatformRequest request,
  }) async {
    //Create the url
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
            width: min(request.webPopupWidth.toDouble(),
                MediaQuery.of(context).size.width),
            height: min(request.webPopupHeight.toDouble(),
                MediaQuery.of(context).size.height),
            child: flutterWebView.WebView(
              javascriptMode: flutterWebView.JavascriptMode.unrestricted,
              initialUrl: uri.toString(),
              onPageFinished: (url) {
                if (url.startsWith(request.redirectUrl!)) {
                  Navigator.pop(dialogContext, url);
                }
              },
            ),
          ),
          title: Text(title),
        );
      },
    );

    if (result == null) throw AuthenticationFailedException(ERROR_USER_CLOSED);

    return result;
  }
}
