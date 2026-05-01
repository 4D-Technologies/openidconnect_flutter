# openidconnect_android

Android implementation for the Flutter OpenIdConnect package. For usage instructions please see <https://pub.dev/packages/openidconnect>.

Because this project is endorsed by the openidconnect project, you need not add it to your `pubspec.yaml`, only the root `openidconnect` dependency.

## Requirements

- Dart SDK: `>=3.8.0 <4.0.0`
- Flutter SDK: `>=3.27.0`
- Android `minSdkVersion 23`

## Android configuration

Interactive authentication is handled by `native_authentication`, so your host app must configure the callback activity for the redirect URI you register with your identity provider.

Required host-app setup:

1. Add `dev.celest.native_authentication.CallbackReceiverActivity` to your Android manifest.
2. Add an intent filter matching your redirect URI.
3. Add `android.permission.INTERNET` if your app does not already declare it.
4. If you use HTTPS redirects instead of a custom scheme, configure Android App Links as well.

Helpful references:

- [Android: Create deep links](https://developer.android.com/training/app-links/deep-linking)
- [Android: Verify App Links](https://developer.android.com/training/app-links/verify-android-applinks)

For a custom scheme callback such as `openidconnect.example://callback`, the manifest `<data>` element should match the scheme/host accepted by your identity provider.

The example app in this repository includes a working manifest configuration.
