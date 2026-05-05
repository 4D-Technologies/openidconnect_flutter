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
4. If you use `OpenIdConnectClient` on macOS, add the **Keychain Sharing** capability (or the equivalent entitlement manually). The endorsed Darwin implementation stores tokens in the macOS data-protection keychain, and macOS will throw `errSecMissingEntitlement` / `-34018` if the app does not declare a keychain access group.
5. Make sure the macOS target is **code signed**. macOS entitlements are applied as part of code signing, so `keychain-access-groups` will not take effect for an unsigned target.
6. If you distribute a sandboxed macOS app, make sure the necessary network entitlements are enabled:
   - outbound network client access for talking to the IdP/token endpoints
   - inbound loopback/server access if you use a localhost callback listener

Helpful references:

- [Apple: Defining a custom URL scheme for your app](https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app)
- [Apple: Supporting associated domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains)
- [Apple: Entitlements](https://developer.apple.com/documentation/bundleresources/entitlements)

As with iOS, no camera/microphone/photo privacy strings are required by this package itself.

For a typical Flutter macOS app, add the same keychain access group to both `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements`, then ensure the `Runner` macOS target has code signing enabled in Xcode's **Signing & Capabilities** settings:

```xml
<key>keychain-access-groups</key>
<array>
   <string>$(AppIdentifierPrefix)$(CFBundleIdentifier)</string>
</array>
```

If you are already using a custom shared keychain access group, include that group instead of or in addition to the default bundle-identifier-based group.

In Xcode, open `macos/Runner.xcworkspace`, select the `Runner` project, select the `Runner` target, then go to **Signing & Capabilities** and either choose **Automatically manage signing** with your development team or configure manual signing for your certificate/profile.

If you need to build from the command line with signing enabled, you can pass the signing settings directly to `xcodebuild`:

```sh
xcodebuild \
   -workspace macos/Runner.xcworkspace \
   -scheme Runner \
   -configuration Debug \
   -destination 'platform=macOS' \
   CODE_SIGN_STYLE=Automatic \
   DEVELOPMENT_TEAM=YOUR_TEAM_ID \
   CODE_SIGNING_ALLOWED=YES \
   CODE_SIGNING_REQUIRED=YES \
   build
```

For a signed Release build, use the same approach with the Release configuration:

```sh
xcodebuild \
   -workspace macos/Runner.xcworkspace \
   -scheme Runner \
   -configuration Release \
   -destination 'platform=macOS' \
   CODE_SIGN_STYLE=Automatic \
   DEVELOPMENT_TEAM=YOUR_TEAM_ID \
   CODE_SIGNING_ALLOWED=YES \
   CODE_SIGNING_REQUIRED=YES \
   build
```

That command signs the build invocation, but the persistent project configuration should still be set in Xcode so regular Flutter/Xcode builds pick it up consistently.

If you build through Flutter instead of calling `xcodebuild` directly, `flutter build macos --codesign` uses the Xcode project signing configuration already stored in `macos/Runner.xcodeproj` / `macos/Runner.xcworkspace`. In other words:

- use **Xcode Signing & Capabilities** to set the long-lived signing/team configuration
- use `flutter build macos --codesign` when you want Flutter to drive a signed macOS build
- use raw `xcodebuild` when you need to override signing settings for a specific CI or local invocation

If `flutter build macos --codesign` still fails, the most common cause is that the `Runner` macOS target does not yet have a **Development Team** selected in Xcode, or code signing is disabled for the active build configuration. Open `macos/Runner.xcworkspace` and confirm the `Runner` target shows a valid team/signing identity under **Signing & Capabilities** for both Debug and Release.

### Fixing macOS keychain access prompts

If your app shows a macOS keychain prompt that asks the user to log in and choose **Always Allow**, that usually means the app is not being recognized as the same stable, signed, entitled application identity that created the stored keychain item.

To avoid that prompt as much as possible:

1. Make sure the app is **code signed** for the configuration you are running.
2. Make sure the app has the `keychain-access-groups` entitlement described above.
3. Keep the same bundle identifier, development team, and keychain access group between runs.
4. Prefer running the app through a normal signed Xcode/Flutter build instead of ad-hoc or unsigned launches.

If prompts continue after you fix signing and entitlements, you may still have older keychain entries created by an unsigned or differently signed build. In that case, delete the existing app-specific keychain items once and let the signed build recreate them.

This package cannot suppress that prompt in code; the prompt is controlled by macOS Keychain security. The practical fix is to make sure the host app is signed consistently and uses the correct entitlement.

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
<key>keychain-access-groups</key>
<array>
   <string>$(AppIdentifierPrefix)$(CFBundleIdentifier)</string>
</array>
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
