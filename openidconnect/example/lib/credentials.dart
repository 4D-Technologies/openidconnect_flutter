import 'package:flutter/foundation.dart';
import 'package:openidconnect/openidconnect.dart';

import 'idp_profile.dart';

export 'idp_profile.dart';

final defaultEncryptionKey = 'example123456789';

String get defaultDiscoveryUrl => duendeDemoProfile.discoveryUrl;
String get defaultClientId => duendeDemoProfile.clientId;
String? get defaultClientSecret => duendeDemoProfile.clientSecret;
String get defaultDeviceClientId => duendeDemoProfile.resolvedDeviceClientId;
List<String>? get defaultAudience => duendeDemoProfile.audiences;
List<String> get defaultscopes => duendeDemoProfile.scopes;

String get defaultRedirectUrl {
  if (kIsWeb) return 'http://localhost:15503/callback.html';

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return 'openidconnect.example://callback';
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
      return 'http://localhost:15503/callback.html';
  }
}

Future<OpenIdConnectClient> createExampleClient({
  required IdpProfile profile,
  String? clientId,
  String? clientSecret,
}) {
  return OpenIdConnectClient.create(
    discoveryDocumentUrl: profile.discoveryUrl,
    clientId: clientId ?? profile.clientId,
    clientSecret: clientSecret ?? profile.clientSecret,
    scopes: profile.scopes,
    audiences: profile.audiences,
    redirectUrl: defaultRedirectUrl,
    encryptionKey: defaultEncryptionKey,
    autoRefresh: true,
    webUseRefreshTokens: true,
  );
}
