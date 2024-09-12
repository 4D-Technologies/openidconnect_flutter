part of openidconnect;

class OpenIdConnectAndroidiOS {
  static Future<String> authorizeInteractive({
    required BuildContext context,
    required String title,
    required String authorizationUrl,
    required String redirectUrl,
    required int popupWidth,
    required int popupHeight,
    required EdgeInsets dialogPadding,
    required bool useFullScreen,
    required Color iconsColor,
  }) async {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);

    Future<String?> resultFuture;

    if (useFullScreen) {
      resultFuture = Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (dialogContext) {
            return Scaffold(
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
            );
          },
        ),
      );
    } else {
      resultFuture = showDialog<String?>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            contentPadding: dialogPadding,
            actions: [
              IconButton(
                onPressed: () => Navigator.pop(dialogContext, null),
                icon: Icon(Icons.close, color: iconsColor),
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

    final result = await resultFuture;

    if (result == null) throw AuthenticationException(ERROR_USER_CLOSED);

    return result;
  }
}
