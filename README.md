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
4. Windows - Password and Device Code Flows only (interactive will use device code)
5. MacOs - Password and Device Code flows only (interactive will use device code)
6. Linux - Password and Device Code flows only (interactive will use device code)

**Important**

As of right now Windows, MacOs and Web use a hard coded encryption key that is in the source code. This may or may not be an issue for you. Until the below items for secure storage are complete, don't assume that your access tokens etc. are secure on these platforms.

For Linux, Windows and macOS currently your IdP MUST support device code flow to function properly with interactive login. Otherwise you must use password flow. This is because webView is not yet supported on these environments.

## Getting Started

1. Add openidconnect to your pubspec.yaml file
2. Import openidconnect: import 'package:openidconnect/openidconnect.dart';
3. Call the various methods: on OpenIdConnect OR use OpenIdConnectClient and subscribe to the events
4. Review the example project for details.
5. For web support add openidconnect_web to your project and copy the callback.html file from openidconnect_web (in this repo) into the web folder of your app.

**(more detailed instructions coming soon)**

## TODO

Because of the ever changing nature of desktop support on flutter and incomplete plugin implementations the following are outstanding and will be updated when the functionality exists to do so:

1. Use custom tabs and secure authentication popup on Android and IOS instead of WebView
2. Use Secure authentication popup on windows (requires work from Tim Sneath on integration with Project Reunion on Windows and Dart)
3. Switch macOs, and Linux to WebView and/or use secure authentication popup at least on macOs.
4. Integrate and switch entirely to flutter_secure_storage for storage of tokens etc. in the OpenIdConnect Client when available.
5. More documentation!

Secure storage is almost ready with a PR that integrates all platforms already available. Flutter WebView is under active development to add macOS, Windows and Linux support.

## Contributing

Pull requests most welcome to fix any bugs found or address any of the above TODOs. I'm not a C++, Kotlin or Swift developer, so custom implementations for various environments would be greatly appreciated.

If adding a custom environment other than android and iOS please follow the flutter best practices and add a separate implementation project with: flutter create --template=plugin --platforms={YourPlatformHere} openidconnect\_{YourPlatformHere} and add your code as appropriate there and then update the example project to use the new implementation.

Your new implementation needs to import the platform interface which is exactly one entry. That entry passes in the url to display in the secure browser and the redirect url that you should watch for to respond accordingly. (You can ignore the redirect url on most platforms that support custom URLs such as Android, iOS etc.) You should return the entire redirected URL which should include the ?code= (and perhaps state) when complete.

Everything else is handled in native dart code so the implementation is very straight forward.
