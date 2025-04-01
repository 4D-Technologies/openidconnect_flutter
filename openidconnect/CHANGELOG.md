# Change Log

## [1.0.37] = April 1st, 2025

- Update dependencies

## [1.0.36] = Deceimber 9th, 2024

- Refactor client library location

## [1.0.34] = Deceimber 9th, 2024

- Switch to async for shared preferences

## [1.0.33] = Deceimber 9th, 2024

- Require the encryption string in client.

## [1.0.32] = Deceimber 9th, 2024

- Added static initalizeEncryption function on OpenIdConnect if not using the client to setup EncryptedSharedPreferences. You should set this to your app key if you use EncryptedSharedPreferences or generate a new 16 character key for OpenIdConnect.
- Added a parameter to the OpenIdConnectClient to set the encryption key so that there is no conflict for your apps. You should set this and not use the default.
- Cleaned up the example app to use the OpenIdConnectClient and make it more explicit what's going on.

## [1.0.31] - December 4th, 2024

- Add back the picture property on the identity

## [1.0.30] - December 4th, 2024

- Remove Flutter Secure Storage
- Update web support to not use dart:html for wasm support
- Updated crypto library to cryptography_plus as the old package was abandoned
- Enable Device Authorization code flow with code prompt for verification if you so desire. (#17)
- Fixed tokens not being saved when doing interactive without a popup (#30)

## [1.0.27] - February 7th, 2024

- Update dependencies

## [1.0.26] - October 29th, 2023

- Update dependencies

## [1.0.25] - November 16th, 2022

- Revert platform indicator as it was causing problems with windows

## [1.0.24] - November 10th, 2022

- Update example dependencies

## [1.0.23] - November 10th, 2022

- Update dependencies
- Explictly tell pub.dev that this library supports all platforms.

## [1.0.21] - December 10, 2021

- Update to Dart 2.15
- Attempt to use updated Dart functionality for pure dart plugins.

## [1.18-Beta.7] - September 10, 2021

- Update to Dart 2.14
- Add linting
- Fix various issues surfaced by linting

## [1.18-Beta.6] - September 1, 2021

- Update to Flutter Secure Storage Beta 5 which fixes various issues in linux.

## [1.0.18-Beta.5] - August 30, 2021

- Fix issue with retry logic in the case of time outs of 502,503,504 errors.
- Additional Handlers for device code flow.
- Handle parsing open id connect metadata in cases where no code flow is accepted by the server.

## [1.0.17-Beta.3] - August 24, 2021

- Fix issue with refresh() on OpenIdConnectClient.

## [1.0.17-Beta.2] - August 23, 2021

- Update Flutter Storage to 5.0.0 Beta-4 bug fixes.

## [1.0.17-Beta.1] - August 16, 2021

- Update Flutter Storage to 5.0.0 Beta-3 and enable shared defaults with Android using Secure File Storage on platform.

## [1.0.16-beta.4] - July 30 2021

- Update to use flutter_secure_storage 5.0.0-beta1 which removes all of the custom crypto functionality ensuring security and implementation for all platforms.

## [1.0.15] - July 30 2021

- Update the web endorsement to correct an issue with web cross compability.

## [1.0.14]

- Make plugin federated so that the sub implementations don't need to be referenced in a project's pubspec.yaml

## [1.0.13]

- Fix client logout() didn ot raise the NotLoggedInEvent
- chnaged getRefreshToken to verifyToken and made it return a bool if the token is valid. This will automatically refresh if the access token is expired and it can refresh, otherwise will return true if the token is valid and false if it isn't. This allows you to create a guard easily for all calls to your api for instance.

## [1.0.12]

- Add Web popup option to control if it uses redirect flow or popup on loginInteractive in client
- Add popup sizing override options on loginInteractive in client

## [1.0.11]

- Fix bug on authorizeInteractive where additionalProperties were ignored.
- Removes duplicate static method for completing code exchange.

## [1.0.10+1]

- Added testing for OpenIdentity save/load with encryption
- Fixed bugs in save/load for OpenIdentity
- Fix bug on processStartup on platforms other than web.

## [1.0.9+3]

- Fixed bug in client on process startup
- Fixed bug in save/load encrypted values in OpenIdConnectIdentity

### [1.0.8]

- Change how the client library is instantiated using the static future: OpenIdConnectClient.create to ensure that everything is initialized. This will prepare for handling web logins that use a redirect loop instead of a popup window and any other platform specific initialization code as necessary.
- Enables interactive login processStartup call for the interface.

### [1.0.7+1]

- Bug fix

### [1.0.7]

- Add currentEvent Property to the client

### [1.0.6]

- Initial release of OpenIdConnect for Flutter
