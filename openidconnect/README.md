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

1. Interactive login now uses endorsed platform implementations and platform-native browser/session APIs, which means it follows the platform-native browser/session rules instead of embedding the IdP inside a WebView.

   This aligns the mobile/desktop interactive flow with the current OAuth 2.0 for Native Apps guidance in RFC 8252 by avoiding embedded user-agents for native platforms.

2. Your `redirectUrl` must be compatible with the target platform:
   - `http://localhost[:port]/path` for Linux / Windows (and optionally macOS)
   - a custom scheme such as `my.app://callback` for Android / iOS / macOS
   - an HTTPS callback you own and have configured for App Links / Universal Links where supported

3. On Android, if you use a custom scheme or HTTPS callback, add the `native_authentication` callback receiver entries shown in that package's documentation.

4. Token persistence now uses the in-repo endorsed platform implementations instead of `flutter_secure_storage`. On native platforms this uses the platform secure store directly (Android Keystore-backed AES-GCM, Apple Keychain, libsecret, and Windows Credential Manager). `OpenIdConnect.initalizeEncryption(...)` and the `encryptionKey` parameter on `OpenIdConnectClient.create(...)` remain available for backward compatibility, but are no longer used to derive storage encryption.

## Requirements

### Package requirements

- Dart SDK: `>=3.8.0 <4.0.0`
- Flutter SDK: `>=3.27.0`

### Platform minimums used by the endorsed implementations

- Android: `minSdkVersion 23`
- iOS: `13.0`
- macOS: `10.15`
- Linux / Windows / Web: no additional package-enforced OS floor beyond the Flutter toolchain you build with, but the plugin assumes the current browser/system-auth flow support provided by the platform implementation in use.

## Getting Started

1. Add `openidconnect` to your `pubspec.yaml`.
2. Import `package:openidconnect/openidconnect.dart`.
3. Choose the flow you need:
   - `loginInteractive` / `authorizeInteractive` for authorization code + PKCE
   - `loginWithPassword` / `authorizePassword` for password flow
   - `loginWithDeviceCode` / device-code helpers for device flow
4. If you already call `initalizeEncryption(...)` or pass an `encryptionKey` into `OpenIdConnectClient.create(...)`, you can keep doing so while upgrading. Those APIs are compatibility no-ops in `2.x` because secure storage is handled internally by the endorsed platform implementations.
5. Review the platform configuration notes below before testing interactive login.
6. If you need multiple `OpenIdConnectClient` instances to keep separate persisted credentials, provide a distinct `tenantId` to each client. When `tenantId` is null, the library uses the legacy global storage keys.

## Platform configuration

### Redirect URI rules

Use a redirect URI that matches the platform authentication model:

- Android / iOS: usually a custom scheme such as `my.app://callback`
- macOS: either a custom scheme such as `my.app://callback` or a loopback URL such as `http://localhost:14100/callback`
- Linux / Windows: a loopback URL such as `http://localhost:14100/callback`
- Web: an HTTPS callback page you host, usually `/callback.html`

If you use HTTPS deep links / universal links instead of a custom scheme, you must also configure the platform link-association files for your app and domain.

### Android

Interactive Android authentication uses the endorsed `openidconnect_android` package backed by `native_authentication`.

Required setup:

1. Make sure your app supports at least Android SDK 23.
2. Add the callback receiver activity and an intent filter for your redirect URI.
3. If your app does not already declare it, include the `INTERNET` permission because the library performs discovery, token, revocation, and user-info HTTP requests.

Helpful references:

- [Android: Create deep links](https://developer.android.com/training/app-links/deep-linking)
- [Android: Verify App Links](https://developer.android.com/training/app-links/verify-android-applinks)

For a custom-scheme callback such as `openidconnect.example://callback`, the manifest entry should match the scheme/host you registered with your identity provider. The example app in this repository shows the required `CallbackReceiverActivity` wiring.

Custom-scheme manifest snippet:

```xml
<uses-permission android:name="android.permission.INTERNET" />

<application ...>
   <activity
      android:name="dev.celest.native_authentication.CallbackReceiverActivity"
      android:exported="true">
      <intent-filter>
         <action android:name="android.intent.action.VIEW" />
         <category android:name="android.intent.category.DEFAULT" />
         <category android:name="android.intent.category.BROWSABLE" />
         <data
            android:scheme="openidconnect.example"
            android:host="callback" />
      </intent-filter>
   </activity>
</application>
```

If you use HTTPS app links instead of a custom scheme, configure Android App Links and the corresponding `assetlinks.json` for your domain as well.

### iOS

Interactive iOS authentication uses the endorsed Darwin package backed by the system browser/session APIs.

Required setup:

1. Your iOS deployment target must be at least `13.0`.
2. If you use a custom-scheme callback, add that scheme under `CFBundleURLTypes` in `Info.plist`.
3. If you use an HTTPS universal-link callback, add the proper Associated Domains capability and configure the Apple app-site-association file for your domain.

Helpful references:

- [Apple: Defining a custom URL scheme for your app](https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app)
- [Apple: Supporting associated domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains)

Important note: this package does **not** require camera, microphone, photo-library, Bluetooth, or location privacy usage strings by itself. There are no OIDC-specific iOS permission prompts to add just for authentication.

Custom-scheme `Info.plist` snippet:

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

If you use Universal Links instead, add your associated domain in Xcode, for example `applinks:auth.example.com`, and host the matching `apple-app-site-association` file for that domain.

### macOS

macOS uses the same endorsed Darwin implementation.

Required setup:

1. Your macOS deployment target must be at least `10.15`.
2. If you use a custom-scheme callback, add it under `CFBundleURLTypes` in `Runner/Info.plist`.
3. If you use an HTTPS universal-link style callback, configure Associated Domains accordingly.
4. If you distribute a sandboxed macOS app, make sure the necessary network entitlements are enabled:
   - outbound network client access for talking to the IdP/token endpoints
   - inbound loopback/server access if you use a localhost callback listener

Helpful references:

- [Apple: Defining a custom URL scheme for your app](https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app)
- [Apple: Supporting associated domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains)
- [Apple: Entitlements](https://developer.apple.com/documentation/bundleresources/entitlements)

As with iOS, no camera/microphone/photo privacy strings are required by this package itself.

Custom-scheme `Runner/Info.plist` snippet:

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

Sandboxed macOS apps that use localhost callbacks should typically enable network entitlements like:

```xml
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.network.server</key>
<true/>
```

### Linux

Interactive Linux authentication uses a loopback redirect with the endorsed Linux implementation.

Required setup:

1. Use a loopback redirect URI such as `http://localhost:14100/callback`.
2. Register that exact redirect URI with your identity provider.
3. Make sure the runtime environment can launch the system browser and accept the loopback callback.

No extra manifest or plist-style configuration is required by this package on Linux.

### Windows

Interactive Windows authentication uses a loopback redirect with the endorsed Windows implementation.

Required setup:

1. Use a loopback redirect URI such as `http://localhost:14100/callback`.
2. Register that exact redirect URI with your identity provider.
3. Ensure the app can open the system browser and receive the loopback callback on the local machine.

No Android/iOS-style manifest permission prompts are required by this package on Windows.

## Web

1. Copy `callback.html` from `openidconnect_web` into the `web/` folder of your app.
2. Register the exact callback URL with your identity provider, typically `https://your-app.example.com/callback.html`.
3. Serve the app from a secure context (`https:` or `http://localhost`) so browser secure storage APIs are available.

4. OpenIdConnect web has 2 separate interactive login flows as a result of browser security restrictions. In most cases you'll want to use the default popup window because it keeps the current app session alive without a full reload. If you need to initiate authentication from code that is not directly tied to a user gesture, browsers may block the popup. In that case set `useWebPopup = false` to use the same-tab redirect loop instead.

   In that redirect-loop mode, the original `loginInteractive`/`authorizeInteractive` call should be treated as a navigation handoff, not as an immediately consumable authorization result. Completion happens after the app reloads and `OpenIdConnect.processStartup(...)` or `OpenIdConnectClient.create(...)` processes the callback response.

**Note:** It is VERY important to make sure you test on Firefox with the web, as it's behavior for blocking popups is _significantly_ more restrictive than Chromium browsers.

## TODO

1. Add more end-to-end coverage around interactive login/logout flows.
2. More documentation!

## Issue/PR status notes

- The historic iOS/custom-scheme redirect failures and embedded-WebView concerns are addressed by the new Darwin/native-authentication structure instead of by patching the old WebView dialog flow.
- The old full-screen WebView dialog PR is intentionally not carried forward because native platforms now use the system authentication surface rather than an in-app dialog.

## Contributing

Pull requests most welcome to fix any bugs found or address any of the above TODOs.

If adding a custom environment other than the already-endorsed Android, Darwin, Linux, Web, and Windows packages, please follow the flutter best practices and add a separate implementation project with: flutter create --template=plugin --platforms={YourPlatformHere} openidconnect\_{YourPlatformHere} and add your code as appropriate there and then update the example project to use the new implementation.

If you are integrating with another native-auth package or platform surface, the implementation still needs to return the final redirected URL (including `code` and optional `state`) back to the Dart layer so token exchange and validation continue to happen centrally.

Everything else is handled in native dart code so the implementation is very straight forward.
