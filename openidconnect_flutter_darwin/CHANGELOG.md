# Changelog

## 3.1.0 - October 16th 2026

- Align package version with `openidconnect` 3.1.x.

## 2.0.3 - October 16th 2026

- Publish this implementation as `openidconnect_flutter_darwin`. The previous pub.dev name is not owned by this publisher.
- Raise the minimum supported SDK to Flutter 3.47 / Dart 3.13 ([#86](https://github.com/4D-Technologies/openidconnect_flutter/issues/86)).

## 2.0.2 - August 24th 2026

- Log Darwin interactive authentication failures through the shared `openIdConnectLogger`.

## 2.0.1 - May 5th 2026

- Remove the `native_authentication` dependency from `openidconnect_flutter_darwin` and replace it with an in-repo Apple interactive-auth bridge.
- Keep macOS loopback (`http://localhost`) redirects working through an in-package localhost flow while continuing to support custom-scheme and HTTPS callbacks for Darwin interactive auth.
- Remove the package-local `pubspec_overrides.yaml` so publish and consumer resolution use hosted dependencies.
- Update the platform-interface dependency to the `2.0.1` patch line for the federated publish flow.

## 2.0.0 - April 30th 2026

- Breaking change: first stable Darwin release for the 2.x federated package line using `native_authentication` system auth flows.
- Add shared Darwin Swift Package Manager/CocoaPods packaging metadata and source layout for Flutter Apple dependency management compatibility. (#63)
- Document iOS/macOS deployment targets and `Info.plist` callback configuration requirements.
- Clarify in the README that Flutter manages the Darwin plugin through the bundled CocoaPods and Swift Package Manager metadata.

## 0.0.1

- Initial Darwin implementation for OpenIdConnect using native_authentication.
