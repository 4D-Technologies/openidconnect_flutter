part of openidconnect;

class OpenIdConnectAndroidiOS {
  static Future<String> authorizeInteractive({
    required BuildContext context,
    required String title,
    required String authorizationUrl,
    required String redirectUrl,
    required int popupWidth,
    required int popupHeight,
    required bool useFullScreen,
    required EdgeInsets dialogPadding,
    required Color iconsColor,
  }) async {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);

    final String? result;

    if (useFullScreen) {
      result = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (dialogContext) => Scaffold(
            appBar: AppBar(
              title: Text(
                title,
                style: TextStyle(color: iconsColor),
              ),
              leading: IconButton(
                icon: Icon(Icons.close, color: iconsColor),
                onPressed: () => Navigator.pop(dialogContext, null),
              ),
            ),
            body: flutterWebView.WebViewWidget(
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
        ),
      );
    } else {
      // Create the url
      result = await showDialog<String?>(
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
              height: min(
                  popupHeight.toDouble(), MediaQuery.of(context).size.height),
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
    }

    if (result == null) throw AuthenticationException(ERROR_USER_CLOSED);

    return result;
  }
}
