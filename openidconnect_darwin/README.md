# openidconnect_darwin

Darwin (iOS and macOS) implementation for the Flutter OpenIdConnect package. For usage instructions please see <https://pub.dev/packages/openidconnect>.

Because this project is endorsed by the openidconnect project, you need not add it to your pubspec.yaml, only the root openidconnect dependency.

Flutter handles the Apple-side dependency integration for this plugin. The package includes both CocoaPods metadata (`darwin/openidconnect_darwin.podspec`) and a Swift Package Manager manifest (`darwin/openidconnect_darwin/Package.swift`) that point at the shared Darwin sources under `darwin/openidconnect_darwin/Sources/openidconnect_darwin`.

You should not add `openidconnect_darwin` to Xcode manually. Add the root `openidconnect` package to your Flutter app and let Flutter manage the Apple plugin linkage.

## Requirements

- Dart SDK: `>=3.8.0 <4.0.0`
- Flutter SDK: `>=3.27.0`
- iOS deployment target: `13.0`
- macOS deployment target: `10.15`

## Apple-platform configuration

Interactive authentication uses the system browser/session through the in-repo Darwin bridge included in this package.

Required host-app setup:

1. For custom-scheme callbacks, add the scheme to `CFBundleURLTypes` in your app `Info.plist`.
2. For HTTPS callbacks, configure Universal Links / Associated Domains and the matching site-association file for your domain.
3. For sandboxed macOS apps, enable the network entitlements you need for outbound requests and, if using a localhost callback, loopback/server access.

The Darwin package no longer depends on an external Apple auth plugin; both the Swift Package Manager/CocoaPods packaging and the Apple interactive-auth bridge now live in this repository.

Helpful references:

- [Apple: Defining a custom URL scheme for your app](https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app)
- [Apple: Supporting associated domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains)
- [Apple: Entitlements](https://developer.apple.com/documentation/bundleresources/entitlements)

iOS / macOS custom-scheme `Info.plist` snippet:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>openidconnect.example</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>openidconnect.example</string>
        </array>
    </dict>
</array>
```

Sandboxed macOS apps that use localhost callbacks should typically enable:

```xml
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.network.server</key>
<true/>
```

What is **not** required just for this package:

- No camera permission strings
- No microphone permission strings
- No photo-library permission strings
- No Bluetooth/location permission strings

The example iOS and macOS apps in this repository show the `CFBundleURLTypes` setup for a custom-scheme callback.
