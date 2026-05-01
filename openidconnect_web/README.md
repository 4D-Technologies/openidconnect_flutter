# openidconnect_web

Web implementation for the Flutter OpenIdConnect package. For usage instructions please see <https://pub.dev/packages/openidconnect>.

Because this project is endorsed by the openidconnect project, you need not add it to your pubspec.yaml, only the root openidconnect dependancy.

## Requirements

- Dart SDK: `>=3.5.3 <4.0.0`
- Flutter SDK: `>=3.4.0`
- A secure browser context (`https:` or `http://localhost`) for secure storage support

## Web configuration

1. Copy `callback.html` from this package into the `web/` folder of your app.
2. Register the exact callback URL with your identity provider.
3. Use the popup flow when authentication begins from a direct user gesture.
4. Use the redirect-loop flow when the popup would be blocked, and complete the result via `OpenIdConnect.processStartup(...)` or `OpenIdConnectClient.create(...)` after the app reloads.

There are no Android/iOS-style permission prompts or plist settings for the web package, but browsers do require a secure context for the storage APIs used by the package.
