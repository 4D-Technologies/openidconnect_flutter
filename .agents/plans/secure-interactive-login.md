# Secure platform interactive login

Parent: [#79](https://github.com/4D-Technologies/openidconnect_flutter/issues/79).

## Decision (updated)

iOS already uses `ASWebAuthenticationSession` and Android already uses Auth Tab for every interactive login/logout. There is no opt-in today.

**Do not add `usePlatformSecureLogin`.** The platform secure session is the default (and only) interactive path on iOS, Android, macOS (non-localhost), and Windows. Web and Linux keep the existing browser popup / loopback because they have no analog.

Rewrite those secure sessions as in-repo Dart FFI, lifting Celest `native_authentication` (BSD-2-Clause-Patent, retain copyright). Do not take it as a pub dependency.

| Platform | Interactive default | Implementation |
| --- | --- | --- |
| iOS | `ASWebAuthenticationSession` | Dart FFI C ABI in the shared Darwin plugin |
| macOS | `ASWebAuthenticationSession`; `http://localhost` stays Dart loopback | Same Darwin FFI + existing loopback |
| Android | Auth Tab / Custom Tabs | Existing Kotlin Activity (required for `ActivityResultLauncher`) |
| Windows | WebView2 auth window intercepting the redirect | Dart FFI C ABI + WebView2 |
| Linux | System browser + loopback | Existing Dart |
| Web | Popup or redirect loop | Existing Dart |

## Out of scope

- Public `usePlatformSecureLogin` flag
- UWP `WebAuthenticationBroker`
- Re-adding `native_authentication` as a dependency
- Rewriting Keychain / EncryptedSharedPreferences / CredMan / libsecret
