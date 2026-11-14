# openidconnect_windows

Windows implementation for the Flutter OpenIdConnect package. For usage instructions please see <https://pub.dev/packages/openidconnect>.

Because this project is endorsed by the openidconnect project, you need not add it to your pubspec.yaml, only the root openidconnect dependency.

## Requirements

- Dart SDK: `>=3.13.0 <4.0.0`
- Flutter SDK: `>=3.47.0`
- [Microsoft Edge WebView2 Runtime](https://developer.microsoft.com/microsoft-edge/webview2/) (preinstalled on Windows 11)

## Windows configuration

Interactive authentication opens a WebView2 window and intercepts the configured redirect URI. Custom schemes, HTTPS callbacks, and `http://localhost[:port]/path` are supported. The window is navigated to the authorization URL and the redirect navigation is cancelled before it is loaded, so the callback URL never reaches a listening socket or another process.

Required host-app setup:

1. Register the exact redirect URI with your identity provider.
2. Ensure the WebView2 Runtime is installed on the machine (preinstalled on Windows 11; install the Evergreen runtime on Windows 10).

No plist or Android-manifest permission prompts are required by this package itself on Windows.

### Behavior

- One interactive login at a time. A second `loginInteractive` call while a sign-in window is open fails with `An interactive authentication session is already in progress.` and does not disturb the open window. A new login can start as soon as the previous one completes or is cancelled.
- Closing the window (or the user cancelling) completes with `user_closed`. There is no built-in timeout while the window is open; the user is looking at it.
- A missing or broken WebView2 runtime fails with `The WebView2 runtime is missing or failed to start.`
- A navigation counts as the callback when it starts with the full configured redirect URI (scheme, host, port, path) and is followed by `?`, `#`, `/`, or end of string. This is a prefix match, so descendant paths such as `/callback/other` also match; a different host, port, or sibling path does not. Exact `redirect_uri` validation is the identity provider's job.
- WebView2 keeps its profile in `%TEMP%\openidconnect_webview2`, so a provider session cookie can carry over between logins in the same Windows user profile. Use `prompts: ['login']` on `loginInteractive` to force re-authentication.

### Decision record (#83)

- `WebAuthenticationBroker` is documented for UWP only and is not used. This is a Win32 plugin.
- **Chosen:** an in-repo C ABI around a WebView2 window, called through Dart FFI (`lib/src/web_auth_ffi.dart`, `windows/web_auth.cpp`). The window runs on its own thread and message loop, and completion is posted back to Dart with a `NativeCallable.listener`, so the native window lifecycle never blocks or re-enters the Dart isolate.
- **Not chosen:** the system browser plus a loopback listener (RFC 8252). It is the pattern Linux uses and `startLoopbackAuthenticationFlow` remains in the package, but it hands the authorization response to whatever process owns the port and cannot report that the user closed the browser tab.
- There is no `usePlatformSecureLogin` flag: the secure window is the only interactive path on Windows, so a request is never silently downgraded.

### Live end-to-end test

`openidconnect/example/integration_test/windows_webview2_login_test.dart` runs real logins against the public Duende demo through the real WebView2 window. `windows_webview2_driver.mjs` fills in the sign-in form over the WebView2 DevTools port, and closes the native window for the cancel cases. Needs Visual Studio's C++ workload, Node 22+, and network access:

```powershell
cd openidconnect/example
$env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS = '--remote-debugging-port=9222'
$env:OIDC_E2E_DRIVER = '1'
Start-Process node -WindowStyle Hidden -ArgumentList 'integration_test/windows_webview2_driver.mjs','9222','login,cancel,login,login-held,cancel,cancel,cancel,cancel,cancel'
flutter test integration_test/windows_webview2_login_test.dart -d windows
```
