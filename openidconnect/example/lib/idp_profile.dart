/// A reusable OpenID Connect client configuration for the example app.
class IdpProfile {
  const IdpProfile({
    required this.id,
    required this.name,
    required this.discoveryUrl,
    required this.clientId,
    this.clientSecret,
    this.deviceClientId,
    this.passwordClientId,
    this.passwordClientSecret,
    this.scopes = const ['openid', 'profile', 'email', 'offline_access'],
    this.audiences,
    this.usernameHint,
    this.passwordHint,
    this.notes,
    this.supportsInteractive = true,
    this.supportsDevice = false,
    this.supportsPassword = false,
  });

  final String id;
  final String name;
  final String discoveryUrl;
  final String clientId;
  final String? clientSecret;
  final String? deviceClientId;
  final String? passwordClientId;
  final String? passwordClientSecret;
  final List<String> scopes;
  final List<String>? audiences;
  final String? usernameHint;
  final String? passwordHint;
  final String? notes;
  final bool supportsInteractive;
  final bool supportsDevice;
  final bool supportsPassword;

  String get interactiveClientId => clientId;
  String get resolvedDeviceClientId => deviceClientId ?? clientId;
  String get resolvedPasswordClientId => passwordClientId ?? clientId;
  String? get resolvedPasswordClientSecret =>
      passwordClientSecret ?? clientSecret;
}

/// Public Duende IdentityServer demo used as the example default.
const duendeDemoProfile = IdpProfile(
  id: 'duende-demo',
  name: 'Duende IdentityServer demo',
  discoveryUrl:
      'https://demo.duendesoftware.com/.well-known/openid-configuration',
  clientId: 'interactive.public',
  deviceClientId: 'device',
  scopes: ['openid', 'profile', 'email', 'offline_access'],
  usernameHint: 'alice',
  passwordHint: 'alice',
  notes:
      'Sign in as alice/alice or bob/bob. Discovery lists the password grant, '
      'but no public demo client allows it.',
  supportsInteractive: true,
  supportsDevice: true,
  supportsPassword: false,
);

/// Public OIDC playground that enables the resource-owner password grant.
///
/// [oidcdebugger.com](https://oidcdebugger.com/) is a web client debugger, not
/// an identity provider: it has no discovery document or token endpoint.
const sondaHubProfile = IdpProfile(
  id: 'sondahub',
  name: 'SondaHub OIDC playground',
  discoveryUrl: 'https://api.sondahub.com/.well-known/openid-configuration',
  clientId: 'sonda',
  clientSecret: 'probe-secret',
  scopes: ['openid', 'profile', 'email'],
  usernameHint: 'sonda',
  passwordHint: 'probe',
  notes:
      'Public playground credentials (sonda/probe). Use this profile to try '
      'password grant; Duende and oidcdebugger.com do not offer a working ROPC '
      'client.',
  supportsInteractive: true,
  supportsDevice: false,
  supportsPassword: true,
);

const builtInIdpProfiles = [duendeDemoProfile, sondaHubProfile];
