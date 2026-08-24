# Secure platform interactive login

## Goal

Add an optional flag to interactive authorization and interactive logout so callers can choose whether the flow uses a platform-provided secure authentication session/browser surface. The default must preserve current behavior. A caller logging into its own web site can explicitly opt out and continue using the existing standard URL/browser behavior; a caller that opts in can require the platform secure login surface where the target platform supports it.

Proposed public name: `usePlatformSecureLogin` (default `false`). Keep the name about behavior rather than a vendor API. Document that this controls the interactive user-agent/session, not token storage, TLS, or server-side security.

## Research findings

- The remembered package is `flutter_web_auth` and its maintained fork `flutter_web_auth_2`, not `flutter_appauth`.
  - `flutter_web_auth` README/source describes `ASWebAuthenticationSession` on iOS 12+ and macOS 10.15+, and Chrome Custom Tabs on Android.
  - `flutter_web_auth_2` continues that project, adds Android Auth Tab, universal-link handling, and desktop alternatives. It is a Flutter port/continuation of a native plugin, not a JavaScript library.
  - We may read its source and documentation for behavior and edge cases, but must not add it as a runtime dependency or copy incompatible code/license material.
- Apple `ASWebAuthenticationSession` presents a system-mediated authentication session, returns the callback through a completion handler, binds the callback to the calling app, supports custom-scheme and HTTPS callbacks, supports cancellation, and has an optional ephemeral-session preference.
- AndroidX Browser Auth Tab/Custom Tabs is the relevant secure browser surface. Current repository code already uses `AuthTabIntent`, validates custom-scheme/HTTPS callbacks, handles activity recreation, cancellation, App Link verification, and optional ephemeral browsing.
- Windows `WebAuthenticationBroker` documentation is for UWP and requires a secure HTTPS request URL; it is not directly a Win32 Flutter plugin API. The Windows work must verify a supported Win32 option before implementation. Candidate approaches are a system browser plus loopback callback (secure native-app pattern, but not an in-app secure session) or WebView2/browser authentication APIs where their security and deployment requirements are acceptable. Do not present UWP WebAuthenticationBroker as implemented support without a Win32 proof of concept.
- Dart FFI is useful for stable C ABI calls, but it cannot by itself create Apple Objective-C/Swift or Android Activity/UI objects, own lifecycle callbacks, or receive asynchronous platform intents. Evaluate a minimal C ABI/native shim, but retain the existing MethodChannel/plugin registration boundary unless a tested FFI design is genuinely safer and maintainable. “Prefer FFI” must not result in unsafe callback pointers, leaked handles, or platform-specific UI logic forced into Dart.

## Current repository constraints

- Shared interface: `openidconnect_platform_interface/lib/openidconnect_platform_interface.dart`.
- High-level public APIs: `OpenIdConnectClient.loginInteractive` and `OpenIdConnect.authorizeInteractive`; interactive logout uses the same platform authorization entry point.
- Android package already has a method-channel bridge and `OpenIdConnectCallbackManagerActivity.kt` using `AuthTabIntent`.
- Darwin package already has a method-channel bridge and `OpenIdConnectDarwinPlugin.swift` using `ASWebAuthenticationSession`; macOS localhost redirects intentionally use a loopback browser flow.
- Windows currently uses Dart `dart:io` loopback plus a desktop URL launcher; there is no Windows native authentication session implementation.
- Linux and Web should not silently change semantics as part of this ticket set. The shared API must define their behavior explicitly (unsupported, ignored, or existing web option), with tests.

## API and behavior contract

1. Add `usePlatformSecureLogin = false` to `OpenIdConnectClient.loginInteractive` and `logoutInteractive`.
2. Thread the value through `OpenIdConnect.authorizeInteractive`, `OpenIdConnect.logoutInteractive`, the platform interface, and all endorsed implementations.
3. The default `false` preserves existing behavior. Existing callers require no migration.
4. `true` selects the secure platform session on iOS, Android, and macOS when the redirect URI and OS minimum support it.
5. `false` selects the current standard URL/browser behavior. Do not reinterpret false as “insecure”; explain that the caller is deliberately selecting ordinary browser/loopback behavior.
6. If `true` cannot be honored on a platform or for a redirect type, fail with a documented, typed authentication error rather than silently downgrading. This avoids a caller believing a secure session was used when it was not.
7. Apply the same choice to interactive logout so login/logout session-cookie behavior is predictable. Ephemeral-session settings, if retained internally, must not be conflated with secure-session selection.
8. Preserve PKCE/state validation and return the complete callback URL. Never pass access or refresh tokens through native logs or platform arguments beyond the authorization URL/callback URL.
9. Decide and document whether Web/Linux reject `true` or retain their existing flows; tests must lock the decision down.

## Work sequence

### Phase 0 — architecture and compatibility checkpoint

- Confirm package minimums and native API availability: iOS 13, macOS 10.15, Android minSdk 23, supported Windows Flutter desktop toolchain.
- Inspect `flutter_web_auth_2` native source for callback matching, cancellation, lifecycle, universal links, Auth Tab fallback, and error mapping; record only behavioral findings and links in issue/README documentation.
- Prototype the smallest possible FFI boundary for each candidate platform. Reject FFI for any UI/lifecycle path that requires unsafe callback ownership or cannot work with Flutter release builds. Keep MethodChannel as the implementation boundary if it is the robust choice.
- Decide Windows implementation and its supported redirect URI model before changing the shared API.

### Phase 1 — shared Dart/platform contract

- Add the optional flag to the high-level client methods and lower-level static methods.
- Add it to `OpenIdConnectPlatform.authorizeInteractive` and `MethodChannelOpenIdConnect` arguments.
- Thread it through login and logout without changing request URL construction, PKCE, state, token exchange, or cleanup.
- Define a stable error code/message for “secure platform login unavailable” and map native errors consistently.
- Add unit tests with a fake platform implementation proving true/false propagation, default compatibility, login/logout coverage, and no behavior change to web redirect storage.

### Phase 2 — iOS and macOS

- Keep `ASWebAuthenticationSession` as the secure path; make selection explicit rather than relying on today’s unconditional Darwin native path.
- Implement ordinary path behavior for `false` according to the existing platform contract, while preserving macOS loopback handling where applicable.
- Validate custom scheme, HTTPS/universal-link host/path, and localhost restrictions before starting a session.
- Handle `canStart`/`start()` failure, cancellation, duplicate sessions, app/window presentation anchors, app backgrounding, and callback URL validation.
- Test native error mapping and document iOS/macOS entitlements and callback registration requirements.
- Keep ephemeral browsing as a separate concern and document its relationship to SSO/session cookies.

### Phase 3 — Android

- Keep `AuthTabIntent`/AndroidX Browser Auth as the secure path and pass the public selection through the existing activity state.
- Define the ordinary false path without breaking the current callback receiver or task-affinity behavior.
- Cover custom schemes, HTTPS App Links, callback host/path/port matching, activity recreation, duplicate requests, browser unavailable, cancellation, Auth Tab verification failures, and ephemeral browsing.
- Verify AndroidX Browser dependency/API level and Chrome/provider compatibility; provide a controlled fallback only when the contract explicitly says the secure request was not required.
- Add Kotlin and Dart tests for argument propagation and result/error mapping; use device/emulator validation for Auth Tab behavior.

### Phase 4 — Windows

- Produce a proof of concept for the selected Win32-capable secure route.
- If WebView2 is selected, document runtime installation/version requirements, isolation/profile/cookie behavior, callback interception, window ownership, cancellation, and package/deployment impact.
- If system browser + loopback is the only supported route, document that it is the native-app browser pattern but not an embedded secure-session UI, and decide whether `true` should be rejected or mapped to that route.
- Prefer a narrow native ABI/FFI component only if it can safely own the asynchronous window/callback lifecycle; otherwise use the plugin’s established native registration mechanism.
- Add Windows-specific tests for callback validation, timeout/cancellation, process/window cleanup, and explicit unsupported behavior.

### Phase 5 — documentation, examples, and release

- Update package README/API docs with a platform behavior matrix, examples for opting out and opting in, redirect URI requirements, callback registration, cookie/SSO implications, and failure semantics.
- Update example and test harness controls so both paths can be exercised.
- Add changelog entries to affected packages and bump versions consistently with the federated plugin release process.
- Run formatting/analyzer/tests for all packages, plus native builds on available macOS/Android/Windows targets and manual callback tests.
- Review security properties: PKCE/state remain mandatory, callback matching is exact for configured values, no token logging, cancellation cleans all pending state, and no silent fallback when secure mode was requested.

## Acceptance criteria

- Existing callers retain current behavior because the option defaults to `false`.
- `loginInteractive` and `logoutInteractive` expose and honor the option across the shared API.
- iOS/macOS secure mode uses `ASWebAuthenticationSession`; Android secure mode uses Auth Tab/Custom Tabs; Windows behavior is supported only after a documented Win32 implementation decision.
- Unsupported redirect/platform combinations produce an actionable typed error and never silently claim secure-mode success.
- Both success and cancellation return through the existing Dart abstractions, with no leaked native session, listener, activity, window, or pending result.
- PKCE, state validation, token exchange, storage, and refresh behavior are unchanged.
- Unit, native, and integration/manual tests cover true, false, default, cancellation, malformed callbacks, lifecycle recreation, and logout.
- Documentation clearly distinguishes secure browser/session selection, ephemeral/private browsing, ordinary system-browser launch, and secure token storage.

## Related research links

- `https://pub.dev/packages/flutter_web_auth`
- `https://pub.dev/packages/flutter_web_auth_2`
- `https://github.com/LinusU/flutter_web_auth`
- `https://github.com/ThexXTURBOXx/flutter_web_auth_2`
- `https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession`
- `https://developer.android.com/reference/androidx/browser/customtabs/CustomTabsIntent`
- `https://developer.chrome.com/docs/android/custom-tabs/guide-auth-tab`
- `https://learn.microsoft.com/en-us/windows/uwp/security/web-authentication-broker`
- `https://datatracker.ietf.org/doc/html/rfc8252`
