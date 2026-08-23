# Changelog

## 2.0.3 - August 21st 2026

- Migrates to built-in Kotlin to support AGP 9. (#75)
- Updates the minimum supported SDK version to Flutter 3.44/Dart 3.12.

## 2.0.2 - May 21st 2026

- Remove the external `native_authentication` dependency and replace it with an in-repo Android browser-session/auth-tab bridge.
- Add the in-repo `OpenIdConnectCallbackReceiverActivity` / `OpenIdConnectCallbackManagerActivity` Android callback flow and update the README/example manifest wiring accordingly.

## 2.0.1 - May 5th 2026

- Remove the package-local `pubspec_overrides.yaml` so publish and consumer resolution use hosted dependencies.
- Update the platform-interface dependency to the `2.0.1` patch line for the federated publish flow.

## 2.0.0 - April 30th 2026

- Breaking change: first stable Android release for the 2.x federated package line using `native_authentication` system auth flows.
- Modernize the Android packaging path and example Gradle configuration without pinning a Java/Kotlin language level. (#61)
- Document the Android `minSdkVersion 23` floor and required callback receiver manifest configuration.
