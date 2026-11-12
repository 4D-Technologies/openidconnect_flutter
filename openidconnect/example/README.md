# openidconnect example

The example talks to the public [Duende IdentityServer demo](https://demo.duendesoftware.com) by default, a standards-compliant OpenID Connect provider. Use **Choose IdP** / **Add IdP** on the home screen to point the same flows at another issuer. A second built-in profile, [SondaHub](https://sondahub.com/oauth2-test-server/), is included so password grant can be tried against a public client that actually allows it.

Built-in default (Duende):

| Setting | Value |
| --- | --- |
| Discovery | `https://demo.duendesoftware.com/.well-known/openid-configuration` |
| Interactive client | `interactive.public` (authorization code + PKCE, no secret) |
| Device client | `device` |
| Scopes | `openid profile email offline_access` |
| Demo users | `alice` / `alice`, `bob` / `bob` |

Platform redirect URIs are already wired in the example app and accepted by the demo client:

- Android / iOS / macOS: `openidconnect.example://callback`
- Windows / Linux / web: `http://localhost:15503/callback.html`

## Interactive login (code + PKCE)

1. From this directory, run the app on the platform you want to test:

   ```sh
   flutter run -d <device>
   ```

2. Leave **Duende IdentityServer demo** selected (or **Add IdP** for your own issuer).
3. Open **Code Flow with PKCE**.
4. Lookup configuration, then **Login**.
5. Sign in as `alice` / `alice` or `bob` / `bob`, then allow the requested scopes.
6. The example should return an authorization response with `id_token`, `access_token`, and `refresh_token`.

That path is authorization code + PKCE as specified by OpenID Connect Core and RFC 8252.

## Device code

Uses client id `device` on the Duende profile. Lookup, **Login**, then complete the verification URL as `alice` or `bob`.

## Password grant

Choose **SondaHub OIDC playground**, then use the Password page as `sonda` / `probe`. That playground advertises `grant_type=password` and returns `id_token`, `access_token`, and `refresh_token`.

The Duende demo lists `password` in discovery metadata, but every public client rejects it with `unauthorized_client` or `invalid_client`. **Add IdP** if you want to point password grant at your own issuer.

[oidcdebugger.com](https://oidcdebugger.com/) was checked as a password-grant candidate: it is a **web client debugger**, not an identity provider. Discovery (`/.well-known/openid-configuration`) is 404, there is no token endpoint, and the only callback it accepts is `https://oidcdebugger.com/debug`. [openidconnect.net](https://www.openidconnect.net/) is the same class of tool (`https://openidconnect.net/api/callback`). Neither can be this example’s issuer.

## Adding another IdP

On the home screen tap **Add IdP** and enter discovery URL, client id, optional secret, optional device client id, and scopes. The profile is kept for the rest of the process so every example flow uses it.

Register this app’s platform redirect URIs on that client. For a local HTTPS issuer the Android debug network-security config trusts user CAs.

## Client wrapper

**Client Usage Example** creates an `OpenIdConnectClient` for the selected IdP and exercises interactive login, refresh, and logout.
