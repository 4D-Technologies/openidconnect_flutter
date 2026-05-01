# Changelog

## Unreleased

- Remove the `native_authentication` dependency from `openidconnect_darwin` and replace it with an in-repo Apple interactive-auth bridge.
- Keep macOS loopback (`http://localhost`) redirects working through an in-package localhost flow while continuing to support custom-scheme and HTTPS callbacks for Darwin interactive auth.

## 2.0.0 - April 30th 2026

- Breaking change: first stable Darwin release for the 2.x federated package line using `native_authentication` system auth flows.
- Add shared Darwin Swift Package Manager/CocoaPods packaging metadata and source layout for Flutter Apple dependency management compatibility. (#63)
- Document iOS/macOS deployment targets and `Info.plist` callback configuration requirements.
- Clarify in the README that Flutter manages the Darwin plugin through the bundled CocoaPods and Swift Package Manager metadata.

## 0.0.1

- Initial Darwin implementation for OpenIdConnect using native_authentication.
