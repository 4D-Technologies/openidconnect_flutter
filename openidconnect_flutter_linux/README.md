# openidconnect_flutter_linux

Linux implementation for the Flutter OpenIdConnect package. For usage instructions please see <https://pub.dev/packages/openidconnect>.

Because this project is endorsed by the openidconnect project, you need not add it to your pubspec.yaml, only the root openidconnect dependency.

## Requirements

- Dart SDK: `>=3.13.0 <4.0.0`
- Flutter SDK: `>=3.47.0`

## Linux configuration

Use an `http://localhost:port/path` redirect URL for Linux interactive authentication. The port is required; a URL without one is rejected.

Required host-app setup:

1. Register the exact loopback callback URL with your identity provider.
2. Ensure the app can open the system browser.
3. Ensure the local machine can receive the loopback callback on the configured port/path.
4. Install the libsecret development headers to build (for example `sudo apt install libsecret-1-dev`).

Interactive login waits up to 5 minutes for the redirect. If none arrives, it fails with `user_closed` and releases the port.

No Android/iOS-style manifest or plist changes are required by this package on Linux.
