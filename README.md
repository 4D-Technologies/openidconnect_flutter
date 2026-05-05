# OpenIdConnect for Flutter

Standards compliant OpenIdConnect library for flutter that supports:

1. Code flow with PKCE (the evolution of implicit flow). This allows poping a web browser (included) for authentication to any open id connect compliant IdP.
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

## Important

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
- Linux / Windows / Web: no additional package-enforced OS floor beyond the Flutter toolchain you build with

## Getting Started

1. Add `openidconnect` to your `pubspec.yaml` file.
2. Import `package:openidconnect/openidconnect.dart`.
3. Call the various methods on `OpenIdConnect`, or use `OpenIdConnectClient` and subscribe to its events.
4. If you still call `initalizeEncryption(...)` or pass `encryptionKey` into `OpenIdConnectClient.create(...)`, you may keep doing so while upgrading. In `2.x` those APIs are compatibility no-ops because endorsed secure storage handles persistence internally.
5. Review the platform configuration notes below before testing interactive sign-in.

## Platform configuration

### Redirect URI rules

- Android / iOS: usually a custom scheme such as `my.app://callback`
- macOS: either a custom scheme or a loopback URL such as `http://localhost:14100/callback`
- Linux / Windows: a loopback URL such as `http://localhost:14100/callback`
- Web: an HTTPS callback page you host, typically `/callback.html`

### Android

- Requires Android `minSdkVersion 23`
- Add the `native_authentication` callback receiver activity/intent filter for your redirect URI
- Add `INTERNET` permission if your app does not already declare it
- Configure Android App Links as well if you use HTTPS callbacks instead of a custom scheme

Helpful references:

- [Android: Create deep links](https://developer.android.com/training/app-links/deep-linking)
- [Android: Verify App Links](https://developer.android.com/training/app-links/verify-android-applinks)

The example Android manifest in this repository shows the callback activity wiring for `CallbackReceiverActivity`.

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

### iOS

- Requires iOS `13.0+`
- Add your custom callback scheme under `CFBundleURLTypes` in `Info.plist`, or configure Associated Domains for universal links
- No OIDC-specific camera/microphone/photo/location permission strings are required by this package

Helpful references:

- [Apple: Defining a custom URL scheme for your app](https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app)
- [Apple: Supporting associated domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains)

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

### macOS

- Requires macOS `10.15+`
- Add your custom callback scheme under `CFBundleURLTypes` in `Info.plist`, or configure Associated Domains for HTTPS callbacks
- Add the **Keychain Sharing** capability for apps that use `OpenIdConnectClient`, or declare `keychain-access-groups` manually. The macOS secure-storage implementation uses the data-protection keychain and will throw `errSecMissingEntitlement` / `-34018` without a keychain access group.
- Make sure the macOS target is code signed, because the `keychain-access-groups` entitlement is applied during code signing.
- For sandboxed apps, enable the network entitlements you need, especially outbound client access and loopback/server access if you use localhost callbacks
- No OIDC-specific privacy usage strings are required by this package

Helpful references:

- [Apple: Defining a custom URL scheme for your app](https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app)
- [Apple: Supporting associated domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains)
- [Apple: Entitlements](https://developer.apple.com/documentation/bundleresources/entitlements)

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

Add the same keychain access group to `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements`, and make sure the `Runner` macOS target has code signing enabled:

```xml
<key>keychain-access-groups</key>
<array>
    <string>$(AppIdentifierPrefix)$(CFBundleIdentifier)</string>
</array>
```

In Xcode, open `macos/Runner.xcworkspace`, select the `Runner` project, select the `Runner` target, then open **Signing & Capabilities** and either enable **Automatically manage signing** with your development team or configure manual signing for your certificate/profile.

If you need a command-line build with signing enabled, pass the signing settings directly to `xcodebuild`:

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

For a signed Release build, use the Release configuration instead:

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

That command signs the build invocation, but you should still set the persistent project configuration in Xcode so normal Flutter/Xcode builds keep working.

If you build through Flutter instead of invoking `xcodebuild` directly, `flutter build macos --codesign` uses the signing/team configuration already saved in the Xcode project. In practice:

- set the durable signing configuration in **Signing & Capabilities**
- use `flutter build macos --codesign` for normal signed Flutter macOS builds
- use raw `xcodebuild` when you need per-invocation signing overrides, such as in CI

If `flutter build macos --codesign` still fails, the most common cause is that the `Runner` macOS target does not have a **Development Team** selected yet, or signing is disabled for the active build configuration. Open `macos/Runner.xcworkspace` and confirm the `Runner` target shows a valid team/signing identity under **Signing & Capabilities** for both Debug and Release.

Sandboxed macOS apps that use localhost callbacks should typically enable:

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

### Linux / Windows

- Use a loopback redirect URI such as `http://localhost:14100/callback`
- Register that exact redirect URI with your identity provider
- No plist/manifest permission prompts are required by this package itself on these platforms

## Web

1. Copy `callback.html` from `openidconnect_web` into the `web` folder of your app.
2. Register the exact callback URL, typically `https://your-app.example.com/callback.html`, with your IdP.
3. Serve the app from `https:` or `http://localhost` so browser secure storage works.

4. OpenIdConnect web supports both popup and same-tab redirect-loop interactive login. Use the popup flow when authentication starts from a direct user gesture. Use `useWebPopup = false` when a popup would be blocked, and complete the result via `OpenIdConnect.processStartup(...)` or `OpenIdConnectClient.create(...)` after the app reloads.

**Note:** It is VERY important to make sure you test on Firefox with the web, as it's behavior for blocking popups is _significantly_ more restrictive than Chromium browsers.

## TODO

Because of the ever changing nature of desktop support on flutter and incomplete plugin implementations the following are outstanding and will be updated when the functionality exists to do so:

1. Add more end-to-end coverage around interactive login/logout flows.
2. More documentation!

## Contributing

Pull requests most welcome to fix any bugs found or address any of the above TODOs. I'm not a C++, Kotlin or Swift developer, so custom implementations for various environments would be greatly appreciated.

If adding a custom environment other than android and iOS please follow the flutter best practices and add a separate implementation project with: flutter create --template=plugin --platforms={YourPlatformHere} openidconnect\_{YourPlatformHere} and add your code as appropriate there and then update the example project to use the new implementation.

Your new implementation needs to import the platform interface which is exactly one entry. That entry passes in the url to display in the secure browser and the redirect url that you should watch for to respond accordingly. (You can ignore the redirect url on most platforms that support custom URLs such as Android, iOS etc.) You should return the entire redirected URL which should include the ?code= (and perhaps state) when complete.

Everything else is handled in native dart code so the implementation is very straight forward.
