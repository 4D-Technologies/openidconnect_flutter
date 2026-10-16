# Changelog

## 2.0.4 - October 16th 2026

- Raise the minimum supported SDK to Flutter 3.47 / Dart 3.13 ([#86](https://github.com/4D-Technologies/openidconnect_flutter/issues/86)).

## 2.0.3 - August 24th 2026

- Log Linux loopback authentication bind and browser-launch failures through the shared `openIdConnectLogger`.

## 2.0.2 - May 21st 2026

- Remove the external `native_authentication` dependency and replace it with an in-repo loopback-browser implementation for Linux interactive authentication.
- Add direct tests for the Linux redirect parsing and loopback flow support helpers.

## 2.0.1 - May 5th 2026

- Remove the package-local `pubspec_overrides.yaml` so publish and consumer resolution use hosted dependencies.
- Update the platform-interface dependency to the `2.0.1` patch line for the federated publish flow.

## 2.0.0 - April 30th 2026

- Breaking change: first stable Linux release for the 2.x federated package line using `native_authentication` loopback flows.
- Document the required loopback redirect configuration for Linux interactive authentication.

## 0.0.1

- Initial Linux implementation for OpenIdConnect using native_authentication.
