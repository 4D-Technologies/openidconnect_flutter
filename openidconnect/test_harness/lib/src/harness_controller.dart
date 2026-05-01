import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:openidconnect/openidconnect.dart';

import 'harness_adapter.dart';
import 'harness_models.dart';

class HarnessController extends ChangeNotifier {
  HarnessController({required HarnessAdapter adapter}) : _adapter = adapter;

  final HarnessAdapter _adapter;

  HarnessSnapshot _snapshot = const HarnessSnapshot();
  HarnessConfig? _activeConfig;
  HarnessSession? _session;
  StreamSubscription<AuthEvent>? _changesSubscription;

  HarnessSnapshot get snapshot => _snapshot;

  bool get busy => _snapshot.busy;

  Future<void> loadDiscovery(HarnessConfig config) async {
    if (!_validateDiscovery(config)) return;

    await _runBusy(() async {
      final configuration = await _adapter.loadConfiguration(
        config.trimmedDiscoveryDocumentUrl,
      );

      _snapshot = _snapshot.copyWith(
        configuration: configuration,
        statusMessage:
            'Loaded discovery metadata from ${configuration.issuer}.',
      );
    });
  }

  Future<void> initializeClient(HarnessConfig config) async {
    if (!_validateSessionConfig(config)) return;

    await _runBusy(() async {
      await _replaceSession(config);
      _snapshot = _snapshot.copyWith(
        identity: _session?.identity,
        lastEvent: _session?.currentEvent,
        statusMessage: _session?.identity == null
            ? 'Client initialized. Ready to start the authorization flow.'
            : 'Client initialized with a persisted identity for ${_session!.identity!.sub}.',
        clearIdentity: _session?.identity == null,
      );
    });
  }

  Future<void> loginInteractive(
    HarnessConfig config,
    BuildContext context,
  ) async {
    if (!_validateInteractiveConfig(config)) return;

    await _runBusy(() async {
      final session = await _ensureSession(config);
      final identity = await session.loginInteractive(
        context: context,
        title: config.effectiveLoginTitle,
        useWebPopup: config.useWebPopup,
      );

      _snapshot = _snapshot.copyWith(
        identity: identity,
        lastRedirect: null,
        statusMessage:
            'Interactive login completed for subject ${identity.sub}.',
      );
    });
  }

  Future<void> logoutInteractive(
    HarnessConfig config,
    BuildContext context,
  ) async {
    if (!_validateInteractiveConfig(config, requireLogoutRedirect: true))
      return;

    await _runBusy(() async {
      final session = await _ensureSession(config);
      final redirect = await session.logoutInteractive(
        context: context,
        title: config.effectiveLoginTitle,
        postLogoutRedirectUri: config.effectivePostLogoutRedirectUrl,
        useWebPopup: config.useWebPopup,
      );

      _snapshot = _snapshot.copyWith(
        identity: session.identity,
        lastRedirect: redirect,
        statusMessage: redirect == null
            ? 'RP-initiated logout completed without a redirect response.'
            : 'RP-initiated logout completed with redirect: $redirect',
        clearIdentity: session.identity == null,
      );
    });
  }

  Future<void> logout() async {
    if (_session == null) {
      _updateStatus('Initialize the client before attempting logout.');
      return;
    }

    await _runBusy(() async {
      await _session!.logout();
      _snapshot = _snapshot.copyWith(
        identity: _session!.identity,
        statusMessage: 'Local logout completed.',
        clearIdentity: _session!.identity == null,
      );
    });
  }

  Future<void> clearIdentity() async {
    if (_session == null) {
      await OpenIdIdentity.clear();
      _snapshot = _snapshot.copyWith(
        clearIdentity: true,
        clearLastRedirect: true,
        statusMessage: 'Cleared persisted identity.',
      );
      notifyListeners();
      return;
    }

    await _runBusy(() async {
      await _session!.clearIdentity();
      _snapshot = _snapshot.copyWith(
        clearIdentity: true,
        clearLastRedirect: true,
        statusMessage: 'Cleared persisted identity.',
      );
    });
  }

  Future<HarnessSession> _ensureSession(HarnessConfig config) async {
    if (_session != null && _activeConfig == config) {
      return _session!;
    }

    await _replaceSession(config);
    return _session!;
  }

  Future<void> _replaceSession(HarnessConfig config) async {
    await _changesSubscription?.cancel();
    _session?.dispose();

    _session = await _adapter.createSession(config: config);
    _activeConfig = config;

    _changesSubscription = _session!.changes.listen(_handleAuthEvent);

    _snapshot = _snapshot.copyWith(
      configuration: _snapshot.configuration,
      identity: _session!.identity,
      lastEvent: _session!.currentEvent,
      clientReady: _session!.initializationComplete,
      clearIdentity: _session!.identity == null,
    );
  }

  void _handleAuthEvent(AuthEvent event) {
    _snapshot = _snapshot.copyWith(
      lastEvent: event,
      identity: _session?.identity,
      clientReady: _session?.initializationComplete ?? _snapshot.clientReady,
      statusMessage: event.message?.isNotEmpty == true
          ? event.message!
          : switch (event.type) {
              AuthEventTypes.Success => 'Authentication succeeded.',
              AuthEventTypes.LoggingOut => 'Logout in progress...',
              AuthEventTypes.NotLoggedIn => 'No active identity is stored.',
              AuthEventTypes.Refresh => 'Tokens refreshed successfully.',
              AuthEventTypes.Error =>
                'The authentication flow reported an error.',
            },
      clearIdentity: _session?.identity == null,
    );
    notifyListeners();
  }

  bool _validateDiscovery(HarnessConfig config) {
    if (config.trimmedDiscoveryDocumentUrl.isNotEmpty) return true;
    _updateStatus('Enter the issuer discovery document URL first.');
    return false;
  }

  bool _validateSessionConfig(HarnessConfig config) {
    if (!_validateDiscovery(config)) return false;
    if (config.trimmedClientId.isNotEmpty) return true;
    _updateStatus('Enter the client identifier from the conformance suite.');
    return false;
  }

  bool _validateInteractiveConfig(
    HarnessConfig config, {
    bool requireLogoutRedirect = false,
  }) {
    if (!_validateSessionConfig(config)) return false;
    if (config.trimmedRedirectUrl != null) {
      if (!requireLogoutRedirect ||
          config.effectivePostLogoutRedirectUrl != null) {
        return true;
      }
    }

    _updateStatus(
      requireLogoutRedirect
          ? 'Provide a redirect URI and a post-logout redirect URI.'
          : 'Provide the redirect URI that is registered for this client.',
    );
    return false;
  }

  void _updateStatus(String message) {
    _snapshot = _snapshot.copyWith(statusMessage: message);
    notifyListeners();
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    _snapshot = _snapshot.copyWith(busy: true);
    notifyListeners();

    try {
      await action();
    } catch (error) {
      _snapshot = _snapshot.copyWith(statusMessage: error.toString());
    } finally {
      _snapshot = _snapshot.copyWith(
        busy: false,
        clientReady: _session?.initializationComplete ?? _snapshot.clientReady,
      );
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _changesSubscription?.cancel();
    _session?.dispose();
    super.dispose();
  }
}
