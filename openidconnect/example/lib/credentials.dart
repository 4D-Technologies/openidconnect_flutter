import 'package:flutter/foundation.dart';

final defaultDiscoveryUrl =
    "https://localhost:15112/.well-known/openid-configuration";
final defaultClientId = "Scribe";
final String defaultClientSecret = "scribe321!";
final List<String> defaultAudience = ["fieldservice"];
String get defaultRedirectUrl {
  if (kIsWeb) return "http://localhost:15503/callback.html";

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return "openidconnect.example://callback";
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
      return "http://localhost:15503/callback.html";
  }
}

final defaultscopes = ["openid", "profile", "email", "offline_access"];
final defaultEncryptionKey = "example123456789";
