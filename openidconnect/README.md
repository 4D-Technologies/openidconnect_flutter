# OpenIdConnect for Flutter

Standards compliant OpenIdConnect library for flutter that supports:

1. Code flow with PKCE (the evolution of implicit flow). This allows poping a web browser (included) for authentication to any open id connect compliant IdP.
2. Password flow. For use when you control the client and you wish to have your users login directly to your IdP.
3. Device flow. For use typically with console applications and similar.

The base library supports most of the basic functionality:

1. Authorize/Login (for all 3 code flows)
2. Logout
3. Revoke Token
4. Refresh Token

In addition there is a complete OpenIdConnectClient which supports all 3 authorization flows AND automatically maintains login information in secure (ish, web is always the problem with this) storage and automatically refreshes tokens as needed.

Currently supports:

1. iOS
2. Android
3. Web

Almost Ready:

1. Windows - Requires Secure Storage (pull request is awaiting approval - https://github.com/mogol/flutter_secure_storage/pull/247) and fixes to 3rd party WebView (https://github.com/flutter/flutter/issues/37597)
2. MacOs - Requires Secure Storage (pull request is awaiting aproval - https://github.com/mogol/flutter_secure_storage/pull/181) and WebView support (https://github.com/flutter/flutter/issues/41725)
3. Linux - Requires WebView support (https://github.com/flutter/flutter/issues/41726)

## Getting Started

1. Add openidconnect to your pubspec.yaml file
2. Import openidconnect: import 'package:openidconnect/openidconnect.dart';
3. Call the various methods: on OpenIdConnect OR use OpenIdConnectClient and subscribe to the events
4. Review the example project for details.

(more detailed instructions coming soon)
