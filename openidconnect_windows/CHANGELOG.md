# Changelog

## [2.0.1] - May 5th, 2026

- Remove the package-local `pubspec_overrides.yaml` so publish and consumer resolution use hosted dependencies.
- Update the platform-interface dependency to the `2.0.1` patch line for the federated publish flow.

## [2.0.0] - April 30th, 2026

- Breaking change: replace the legacy `webview_windows`-based flow with `native_authentication` and join the 2.x federated package line.
- Document the loopback redirect requirements for Windows interactive authentication.

## [0.0.6] - December 10th, 2021

- Initial release for windows. This uses webview_windows for web view support.
