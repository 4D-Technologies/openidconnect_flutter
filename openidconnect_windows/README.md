# openidconnect_windows

Windows implementation for the Flutter OpenIdConnect package. For usage instructions please see <https://pub.dev/packages/openidconnect>.

Because this project is endorsed by the openidconnect project, you need not add it to your pubspec.yaml, only the root openidconnect dependancy.

## Requirements

- Dart SDK: `>=3.8.0 <4.0.0`
- Flutter SDK: `>=3.27.0`

## Windows configuration

Use an `http://localhost[:port]/path` redirect URL for Windows interactive authentication.

Required host-app setup:

1. Register the exact loopback callback URL with your identity provider.
2. Ensure the app can open the system browser.
3. Ensure the local machine can receive the loopback callback on the configured port/path.

No plist or Android-manifest permission prompts are required by this package itself on Windows.
