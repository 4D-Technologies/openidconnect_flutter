# Changelog

## 2.0.1 - May 5th 2026

- Remove the package-local `pubspec_overrides.yaml` so publish and consumer resolution use hosted dependencies.
- Update the platform-interface dependency to the `2.0.1` patch line for the federated publish flow.

## 2.0.0 - April 30th 2026

- Breaking change: first stable Android release for the 2.x federated package line using `native_authentication` system auth flows.
- Modernize the Android packaging path and example Gradle configuration without pinning a Java/Kotlin language level. (#61)
- Document the Android `minSdkVersion 23` floor and required callback receiver manifest configuration.
