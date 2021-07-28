# 1.0.13

- Fix client logout() didn ot raise the NotLoggedInEvent
- chnaged getRefreshToken to verifyToken and made it return a bool if the token is valid. This will automatically refresh if the access token is expired and it can refresh, otherwise will return true if the token is valid and false if it isn't. This allows you to create a guard easily for all calls to your api for instance.

# 1.0.12

- Add Web popup option to control if it uses redirect flow or popup on loginInteractive in client
- Add popup sizing override options on loginInteractive in client

# 1.0.11

- Fix bug on authorizeInteractive where additionalProperties were ignored.
- Removes duplicate static method for completing code exchange.

# 1.0.10+1

- Added testing for OpenIdentity save/load with encryption
- Fixed bugs in save/load for OpenIdentity
- Fix bug on processStartup on platforms other than web.

# 1.0.9+3

- Fixed bug in client on process startup
- Fixed bug in save/load encrypted values in OpenIdConnectIdentity

## 1.0.8

- Change how the client library is instantiated using the static future: OpenIdConnectClient.create to ensure that everything is initialized. This will prepare for handling web logins that use a redirect loop instead of a popup window and any other platform specific initialization code as necessary.
- Enables interactive login processStartup call for the interface.

## 1.0.7+1

- Bug fix

## 1.0.7

- Add currentEvent Property to the client

## 1.0.6

- TODO: Describe initial release.
