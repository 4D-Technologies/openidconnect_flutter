import 'package:flutter/widgets.dart';
import 'package:openidconnect/openidconnect.dart';

import 'harness_models.dart';

abstract class HarnessSession {
  Stream<AuthEvent> get changes;
  AuthEvent? get currentEvent;
  OpenIdIdentity? get identity;
  bool get initializationComplete;

  Future<OpenIdIdentity> loginInteractive({
    required BuildContext context,
    required String title,
    required bool useWebPopup,
  });

  Future<String?> logoutInteractive({
    required BuildContext context,
    required String title,
    required String? postLogoutRedirectUri,
    required bool useWebPopup,
  });

  Future<void> logout();
  Future<void> clearIdentity();
  void dispose();
}

abstract class HarnessAdapter {
  Future<OpenIdConfiguration> loadConfiguration(String discoveryDocumentUrl);

  Future<HarnessSession> createSession({required HarnessConfig config});
}

class OpenIdConnectHarnessAdapter implements HarnessAdapter {
  static const _storageCompatibilityKey = 'openidconnect_test_harness';

  @override
  Future<OpenIdConfiguration> loadConfiguration(String discoveryDocumentUrl) {
    return OpenIdConnect.getConfiguration(discoveryDocumentUrl);
  }

  @override
  Future<HarnessSession> createSession({required HarnessConfig config}) async {
    final client = await OpenIdConnectClient.create(
      discoveryDocumentUrl: config.trimmedDiscoveryDocumentUrl,
      clientId: config.trimmedClientId,
      clientSecret: config.trimmedClientSecret,
      redirectUrl: config.trimmedRedirectUrl,
      encryptionKey: _storageCompatibilityKey,
      autoRefresh: config.autoRefresh,
      scopes: config.scopes,
    );

    return _OpenIdConnectHarnessSession(client);
  }
}

class _OpenIdConnectHarnessSession implements HarnessSession {
  _OpenIdConnectHarnessSession(this._client);

  final OpenIdConnectClient _client;

  @override
  Stream<AuthEvent> get changes => _client.changes;

  @override
  AuthEvent? get currentEvent => _client.currentEvent;

  @override
  OpenIdIdentity? get identity => _client.identity;

  @override
  bool get initializationComplete => _client.initializationComplete;

  @override
  Future<OpenIdIdentity> loginInteractive({
    required BuildContext context,
    required String title,
    required bool useWebPopup,
  }) {
    return _client.loginInteractive(
      context: context,
      title: title,
      useWebPopup: useWebPopup,
    );
  }

  @override
  Future<String?> logoutInteractive({
    required BuildContext context,
    required String title,
    required String? postLogoutRedirectUri,
    required bool useWebPopup,
  }) {
    return _client.logoutInteractive(
      context: context,
      title: title,
      postLogoutRedirectUri: postLogoutRedirectUri,
      useWebPopup: useWebPopup,
    );
  }

  @override
  Future<void> logout() => _client.logout();

  @override
  Future<void> clearIdentity() => _client.clearIdentity();

  @override
  void dispose() => _client.dispose();
}
