# OpenID Connect test harness

This app is a second example project that sits beside `example/` and is meant
for standards-oriented and certification-style testing.

## What it does

- loads discovery metadata from a supplied issuer URL
- creates an `OpenIdConnectClient` using the entered client settings
- starts interactive authorization code + PKCE login
- performs RP-initiated logout when the provider advertises an `end_session_endpoint`
- shows the last auth event, issuer metadata, and the currently stored identity

## Intended use with the OpenID Foundation conformance suite

For RP testing, the OpenID Foundation conformance suite acts as the OpenID
Provider / Authorization Server under test. In each plan, copy the exported
`issuer` or `discoveryurl` values into this harness, together with the client id,
redirect URI, and post-logout redirect URI configured for that plan.

Useful references:

- <https://www.certification.openid.net/>
- <https://openid.net/certification/connect_rp_testing/>
- <https://openid.net/certification/connect_rp_logout_testing/>

## Platform notes

### Web

`web/callback.html` is included for same-tab redirect-loop processing.

Typical local redirect:

- `http://localhost:8080/callback.html`

### Android

The harness manifest includes:

- `android.permission.INTERNET`
- `dev.celest.native_authentication.CallbackReceiverActivity`
- custom scheme: `openidconnect.harness://callback`

### iOS / macOS

The harness plist files include a matching custom URL scheme:

- `openidconnect.harness://callback`

## Running

From this directory:

- `flutter run -d chrome`
- `flutter test`
