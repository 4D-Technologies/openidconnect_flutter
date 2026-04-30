# OpenIdConnect for Flutter

Standards compliant OpenIdConnect library for flutter that supports:

1. Code flow with PKCE (the evolution of implicit flow). This launches the platform-native authentication surface for authentication to any open id connect compliant IdP.
2. Password flow. For use when you control the client and server and you wish to have your users login directly to your IdP.
3. Device flow. For use typically with console applications and similar.
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

## **Important**

1. Interactive login now uses `native_authentication`, which means it follows the platform-native browser/session rules instead of embedding the IdP inside a WebView.

2. Your `redirectUrl` must be compatible with the target platform:
   - `http://localhost[:port]/path` for Linux / Windows (and optionally macOS)
   - a custom scheme such as `my.app://callback` for Android / iOS / macOS
   - an HTTPS callback you own and have configured for App Links / Universal Links where supported

3. On Android, if you use a custom scheme or HTTPS callback, add the `native_authentication` callback receiver entries shown in that package's documentation.

4. Token persistence now uses `flutter_secure_storage`, so you no longer need to manage a custom 16 character encryption key. `OpenIdConnect.initalizeEncryption(...)` and the `encryptionKey` parameter on `OpenIdConnectClient.create(...)` remain available for backward compatibility, but are no longer used to derive storage encryption.

## Getting Started

1. Add openidconnect to your pubspec.yaml file
2. Import openidconnect: import 'package:openidconnect/openidconnect.dart';
3. Call the various methods: on OpenIdConnect OR use OpenIdConnectClient and subscribe to the events
4. If you already call `initalizeEncryption(...)` or pass an `encryptionKey` into `OpenIdConnectClient.create(...)`, you can keep doing so while upgrading. Those APIs are now compatibility no-ops because secure storage is handled by `flutter_secure_storage`.

5. On the web, `flutter_secure_storage` requires HTTPS (or `localhost`) to function correctly.
6. Review the example project for details.

(more detailed instructions coming soon)

## Web

1. Copy the callback.html file from openidconnect_web (in this repo) into the web folder of your app. Make sure that your Idp has the proper redirect path https://{your_url_to_app/callback.html} as one of the accepted urls.

2. OpenIdConnect web has 2 separate interactive login flows as a result of security restrictions in the browser. (Password and device flows are identical for all platforms) In most cases you'll want to use the default popup window to handle authentication as this keeps everything in process and doesn't require a reload of your flutter application. However, if you have to initiate interactive login outside of clicking a button on the page, your browser will block the popup and put a prompt up asking the user to allow it. This is a bad thing of course. Thus you can set useWebPopup = false on interactiveAuthorization when you need to initialize your authorization outside of a button click. This will result in a redirect in the same page and then the login page on your IdP will redirect back to /callback.html (see notes). This will then be processed using the OpenIdConnect.processStartup or by the OpenIdConnectClient on .create() and then your app will resume as normal including the url that it left off.

**Note:** It is VERY important to make sure you test on Firefox with the web, as it's behavior for blocking popups is _significantly_ more restrictive than Chromium browsers.

## TODO

1. Expand callback configuration examples for each platform.
2. Add more end-to-end coverage around interactive login/logout flows.
3. More documentation!

## Contributing

Pull requests most welcome to fix any bugs found or address any of the above TODOs.

If adding a custom environment other than android and iOS please follow the flutter best practices and add a separate implementation project with: flutter create --template=plugin --platforms={YourPlatformHere} openidconnect\_{YourPlatformHere} and add your code as appropriate there and then update the example project to use the new implementation.

If you are integrating with another native-auth package or platform surface, the implementation still needs to return the final redirected URL (including `code` and optional `state`) back to the Dart layer so token exchange and validation continue to happen centrally.

Everything else is handled in native dart code so the implementation is very straight forward.
