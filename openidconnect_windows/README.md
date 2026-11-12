# openidconnect_windows

Windows implementation for the Flutter OpenIdConnect package. For usage instructions please see <https://pub.dev/packages/openidconnect>.

Because this project is endorsed by the openidconnect project, you need not add it to your pubspec.yaml, only the root openidconnect dependency.

## Requirements

- Dart SDK: `>=3.13.0 <4.0.0`
- Flutter SDK: `>=3.47.0`
- [Microsoft Edge WebView2 Runtime](https://developer.microsoft.com/microsoft-edge/webview2/) (preinstalled on Windows 11)

## Windows configuration

Interactive authentication opens a WebView2 window and intercepts the configured redirect URI. Custom schemes, HTTPS callbacks, and `http://localhost[:port]/path` are supported.

Required host-app setup:

1. Register the exact redirect URI with your identity provider.
2. Ensure the WebView2 Runtime is installed on the machine.

No plist or Android-manifest permission prompts are required by this package itself on Windows.
