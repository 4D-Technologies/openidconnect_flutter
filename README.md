# OpenIdConnect for Flutter

Standards compliant OpenIdConnect library for flutter that supports:

1. Code flow with PKCE (the evolution of implicit flow). This allows poping a web browser (included) for authentication to any open id connect compliant IdP.
2. Password flow. For use when you control the client and server and you wish to have your users login directly to your IdP.
3. Device flow. For use typically with console applications and similar. Used currently for Windows, Linux and MacOs until WebView is supported on those platforms.
4. Full OpenIdConnect Client library that encapsulates the entire process including refresh tokens, refreshing and publishes an event stream for your application.

The base library supports most of the basic OpenIdConnect functionality:

1. Authorize/Login (for all 3 code flows)
2. Logout
3. Revoke Token
4. Refresh Token
5. User Info

In addition there is a complete OpenIdConnectClient which supports all 3 authorization flows AND automatically maintains login information in secure (ish, web is always the problem with this) storage and automatically refreshes tokens as needed.

Currently supports:

1. iOS
2. Android
3. Web
4. Windows
5. MacOs
6. Linux

**Important**

For Linux, Windows and macOS currently your IdP MUST support device code flow to function properly with interactive login. Otherwise you must use password flow. This is because webView is not yet supported on these environments.

## Getting Started

1. Add openidconnect to your pubspec.yaml file
2. Import openidconnect: import 'package:openidconnect/openidconnect.dart';
3. Call the various methods: on OpenIdConnect OR use OpenIdConnectClient and subscribe to the events
4. Review the example project for details.

**(more detailed instructions coming soon)**

## Web

1. Copy the callback.html file from openidconnect_web (in this repo) into the web folder of your app. Make sure that your Idp has the proper redirect path https://{your_url_to_app/callback.html} as one of the accepted urls.

2. OpenIdConnect web has 2 separate interactive login flows as a result of security restrictions in the browser. (Password and device flows are identical for all platforms) In most cases you'll want to use the default popup window to handle authentication as this keeps everything in process and doesn't require a reload of your flutter application. However, if you have to initiate interactive login outside of clicking a button on the page, your browser will block the popup and put a prompt up asking the user to allow it. This is a bad thing of course. Thus you can set useWebPopup = false on interactiveAuthorization when you need to initialize your authorization outside of a button click. This will result in a redirect in the same page and then the login page on your IdP will redirect back to /callback.html (see notes). This will then be processed using the OpenIdConnect.processStartup or by the OpenIdConnectClient on .create() and then your app will resume as normal including the url that it left off.

**Note:** It is VERY important to make sure you test on Firefox with the web, as it's behavior for blocking popups is _significantly_ more restrictive than Chromium browsers.

## TODO

Because of the ever changing nature of desktop support on flutter and incomplete plugin implementations the following are outstanding and will be updated when the functionality exists to do so:

1. Use custom tabs and secure authentication popup on Android and IOS instead of WebView
2. Use Secure authentication popup on windows (requires work from Tim Sneath on integration with Project Reunion on Windows and Dart)
3. Switch macOs, and Linux to WebView and/or use secure authentication popup at least on macOs.
4. More documentation!

## Contributing

Pull requests most welcome to fix any bugs found or address any of the above TODOs. I'm not a C++, Kotlin or Swift developer, so custom implementations for various environments would be greatly appreciated.

If adding a custom environment other than android and iOS please follow the flutter best practices and add a separate implementation project with: flutter create --template=plugin --platforms={YourPlatformHere} openidconnect\_{YourPlatformHere} and add your code as appropriate there and then update the example project to use the new implementation.

Your new implementation needs to import the platform interface which is exactly one entry. That entry passes in the url to display in the secure browser and the redirect url that you should watch for to respond accordingly. (You can ignore the redirect url on most platforms that support custom URLs such as Android, iOS etc.) You should return the entire redirected URL which should include the ?code= (and perhaps state) when complete.

Everything else is handled in native dart code so the implementation is very straight forward.
