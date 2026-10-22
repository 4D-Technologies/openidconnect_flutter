# Change Log

## [3.1.1] - October 21st 2026

- Fixes [#91](https://github.com/4D-Technologies/openidconnect_flutter/issues/91): recover from WebCrypto `DOMException` (`OperationError`/`DataError`) when importing the secure-storage master key or decrypting ciphertext. Unreadable `localStorage` entries under `openidconnect_secure_storage.` are cleared and a new master key is generated. Use a legal AES-GCM algorithm dictionary per operation.
- Share in-flight master-key recovery so concurrent writes after a corrupt key encrypt with the same replacement key.

## [3.1.0] - October 16th 2026

- Align package version with `openidconnect` 3.1.x.

## [2.0.3] - October 16th 2026

- Raise the minimum supported SDK to Flutter 3.47 / Dart 3.13 ([#86](https://github.com/4D-Technologies/openidconnect_flutter/issues/86)).

## [2.0.2] - August 24th 2026

- Replace `debugPrint` secure-storage failure logging with the shared `openIdConnectLogger`.

## [2.0.1] - May 5th 2026

- Remove the package-local `pubspec_overrides.yaml` so publish and consumer resolution use hosted dependencies.
- Update the platform-interface dependency to the `2.0.1` patch line for the federated publish flow.

## [2.0.0] - April 30th 2026

- Breaking change: align the web implementation with the 2.x federated release line.
- Preserve same-tab redirect-loop authentication handoff and add coverage for web implementation registration behavior.
- Document secure-context and callback-page requirements for web authentication.

## [1.0.26] - April 1st 2025

- Dependency Update

## [1.0.25] - December 4th 2024

- Remove dart:html for wasm support

## [1.0.24] - December 4th 2024

- Update dependencies

## [1.0.23] - February 7th 2024

- Update dependencies

## [1.0.22] - October 29th, 2023

- Update dependencies

## [1.0.21] - November 10th, 2022

- Update dependencies

## [1.0.19] - December 9th, 2021

- Update to new interface and fix errors.

## [1.0.12] - November 29th, 2021

- Update dependencies

## [1.0.11] - September 10, 2021

- Updated to Dart 2.14
- Added linting

## [1.0.10]

- Add the endorsement directive in the pubspec.yaml

## 1.0.9

- Implement redirect loop functionality in addition to the default web popup.

## 1.0.7

- Fix readme instructions

## 1.0.6

- Initial Release
