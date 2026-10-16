part of 'openidconnect.dart';

/// High-level client wrapper that manages discovery, persisted identity,
/// refresh handling, and auth lifecycle events.
class OpenIdConnectClient {
  /// Scope automatically added when refresh-token based renewal is enabled.
  static const OFFLINE_ACCESS_SCOPE = "offline_access";

  /// Default scopes requested when none are supplied by the caller.
  static const DEFAULT_SCOPES = ["openid", "profile", "email"];

  final _eventStreamController = StreamController<AuthEvent>();

  final String discoveryDocumentUrl;
  final String clientId;
  final String? clientSecret;
  final String? tenantId;
  final String? redirectUrl;
  final bool autoRefresh;
  final bool webUseRefreshTokens;
  final List<String> scopes;
  final List<String>? audiences;

  OpenIdConfiguration? configuration;
  Timer? _autoRenewTimer;
  OpenIdIdentity? _identity;
  int _sessionGeneration = 0;
  bool _refreshing = false;
  String? _inFlightRefreshToken;
  OpenIdIdentity? _rotatedTokensForRevocation;
  String? _rotatedFromRefreshToken;
  Future<void> _identityWriteQueue = Future<void>.value();
  bool _isInitializationComplete = false;

  /// The most recently raised authentication event, if any.
  AuthEvent? currentEvent;

  OpenIdConnectClient._({
    required this.discoveryDocumentUrl,
    required this.clientId,
    this.tenantId,
    this.redirectUrl,
    this.clientSecret,
    this.autoRefresh = true,
    this.webUseRefreshTokens = true,
    this.scopes = DEFAULT_SCOPES,
    this.audiences,
  });

  /// Creates and initializes an [OpenIdConnectClient], including any pending
  /// web startup authentication state and previously persisted identity.
  static Future<OpenIdConnectClient> create({
    required String discoveryDocumentUrl,
    required String clientId,
    required String encryptionKey,
    String? tenantId,
    String? redirectUrl,
    String? clientSecret,
    bool autoRefresh = true,
    bool webUseRefreshTokens = true,
    List<String> scopes = DEFAULT_SCOPES,
    List<String>? audiences,
  }) async {
    await OpenIdConnect.initalizeEncryption(encryptionKey);

    final client = OpenIdConnectClient._(
      discoveryDocumentUrl: discoveryDocumentUrl,
      clientId: clientId,
      tenantId: tenantId,
      clientSecret: clientSecret,
      redirectUrl: redirectUrl,
      scopes: scopes,
      webUseRefreshTokens: webUseRefreshTokens,
      autoRefresh: autoRefresh,
      audiences: audiences,
    );

    await client._processStartup();

    return client;
  }

  Future<void> _processStartup() async {
    if (redirectUrl != null) {
      await _verifyDiscoveryDocument();
      final response = await OpenIdConnect.processStartup(
        clientId: clientId,
        clientSecret: clientSecret,
        configuration: configuration!,
        redirectUrl: redirectUrl!,
        scopes: scopes,
        autoRefresh: autoRefresh,
      );

      if (response != null) {
        _identity = OpenIdIdentity.fromAuthorizationResponse(response);
        await _identity?.save(tenantId: tenantId);
      }
    }

    _identity ??= await OpenIdIdentity.load(tenantId: tenantId);
    _isInitializationComplete = true;

    if (_identity != null) {
      if (autoRefresh && !await _setupAutoRenew()) {
        _raiseEvent(AuthEvent(AuthEventTypes.NotLoggedIn));
        return;
      } else if (hasTokenExpired) {
        _raiseEvent(AuthEvent(AuthEventTypes.NotLoggedIn));
        return;
      } else {
        if (isTokenAboutToExpire) {
          try {
            final isRefreshed = await refresh(
              raiseEvents: false,
            ).timeout(Duration(seconds: 15));

            isRefreshed
                ? _raiseEvent(AuthEvent(AuthEventTypes.Success))
                : _raiseEvent(AuthEvent(AuthEventTypes.NotLoggedIn));
            return;
          } on TimeoutException {
            _raiseEvent(AuthEvent(AuthEventTypes.NotLoggedIn));
            return;
          }
        }

        _raiseEvent(AuthEvent(AuthEventTypes.Success));
      }
    } else {
      _raiseEvent(AuthEvent(AuthEventTypes.NotLoggedIn));
    }
  }

  void _cancelAutoRenewTimer() {
    _autoRenewTimer?.cancel();
    _autoRenewTimer = null;
  }

  /// Releases timers and closes the auth event stream.
  void dispose() {
    _cancelAutoRenewTimer();
    _eventStreamController.close();
  }

  /// Stream of authentication lifecycle events raised by this client.
  Stream<AuthEvent> get changes =>
      _eventStreamController.stream.asBroadcastStream();

  /// The currently loaded identity, if any.
  OpenIdIdentity? get identity => _identity;

  /// Whether startup processing has completed.
  bool get initializationComplete => _isInitializationComplete;

  /// Whether the current access token is already expired.
  bool get hasTokenExpired =>
      _identity!.expiresAt.difference(DateTime.now().toUtc()).isNegative;

  /// Whether the current access token is close enough to expiry that it should
  /// be refreshed.
  bool get isTokenAboutToExpire {
    var refreshTime = _identity!.expiresAt.difference(DateTime.now().toUtc());
    refreshTime -= Duration(minutes: 1);
    return refreshTime.isNegative;
  }

  /// Logs in with the password grant and persists the resulting identity.
  Future<OpenIdIdentity> loginWithPassword({
    required String userName,
    required String password,
    Iterable<String>? prompts,
    Map<String, String>? additionalParameters,
  }) async {
    _cancelAutoRenewTimer();

    try {
      //Make sure we have the discovery information
      await _verifyDiscoveryDocument();

      final request = PasswordAuthorizationRequest(
        configuration: configuration!,
        password: password,
        scopes: _getScopes(scopes),
        clientId: clientId,
        userName: userName,
        clientSecret: clientSecret,
        prompts: prompts,
        additionalParameters: additionalParameters,
        autoRefresh: autoRefresh,
      );

      final response = await OpenIdConnect.authorizePassword(request: request);

      //Load the idToken here
      await _completeLogin(response, beginSession: true);

      if (autoRefresh) _setupAutoRenew();

      _raiseEvent(AuthEvent(AuthEventTypes.Success));

      return _identity!;
    } on Exception catch (e, stackTrace) {
      logOpenIdConnectError('Password login failed', e, stackTrace);
      await _clearIdentityIgnoringErrors();
      _raiseEvent(AuthEvent(AuthEventTypes.Error, message: e.toString()));
      throw AuthenticationException(e.toString());
    }
  }

  /// Logs in with the device authorization flow.
  Future<OpenIdIdentity> loginWithDeviceCode() async {
    _cancelAutoRenewTimer();

    //Make sure we have the discovery information
    await _verifyDiscoveryDocument();

    //Get the token information and prompt for login if necessary.
    try {
      final response = await OpenIdConnect.authorizeDevice(
        request: DeviceAuthorizationRequest(
          clientId: clientId,
          scopes: _getScopes(scopes),
          audience: audiences?.join(" "),
          configuration: configuration!,
        ),
      );
      //Load the idToken here
      await _completeLogin(response, beginSession: true);

      if (autoRefresh) _setupAutoRenew();

      _raiseEvent(AuthEvent(AuthEventTypes.Success));
      return _identity!;
    } on Exception catch (e, stackTrace) {
      logOpenIdConnectError('Device-code login failed', e, stackTrace);
      await _clearIdentityIgnoringErrors();
      _raiseEvent(AuthEvent(AuthEventTypes.Error, message: e.toString()));
      throw AuthenticationException(e.toString());
    }
  }

  /// Starts an interactive login flow and persists the resulting identity.
  Future<OpenIdIdentity> loginInteractive({
    required BuildContext context,
    required String title,
    String? userNameHint,
    Map<String, String>? additionalParameters,
    Iterable<String>? prompts,
    bool useWebPopup = true,
    int popupWidth = 640,
    int popupHeight = 600,
  }) async {
    if (redirectUrl == null) {
      throw StateError(
        "When using login interactive, you must create the client with a redirect url.",
      );
    }

    _cancelAutoRenewTimer();

    //Make sure we have the discovery information
    await _verifyDiscoveryDocument();

    //Get the token information and prompt for login if necessary.
    try {
      final request = await InteractiveAuthorizationRequest.create(
        configuration: configuration!,
        clientId: clientId,
        redirectUrl: redirectUrl!,
        clientSecret: clientSecret,
        loginHint: userNameHint,
        additionalParameters: additionalParameters,
        scopes: _getScopes(scopes),
        autoRefresh: autoRefresh,
        prompts: prompts,
        useWebPopup: useWebPopup,
        popupHeight: popupHeight,
        popupWidth: popupWidth,
      );

      if (!context.mounted) throw StateError(ERROR_USER_CLOSED);

      final response = await OpenIdConnect.authorizeInteractive(
        context: context,
        title: title,
        request: request,
      );

      if (response == null) throw StateError(ERROR_USER_CLOSED);

      //Load the idToken here
      await _completeLogin(response, beginSession: true);

      if (autoRefresh) _setupAutoRenew();

      _raiseEvent(AuthEvent(AuthEventTypes.Success));

      return _identity!;
    } on Exception catch (e, stackTrace) {
      logOpenIdConnectError('Interactive login failed', e, stackTrace);
      await _clearIdentityIgnoringErrors();
      _raiseEvent(AuthEvent(AuthEventTypes.Error, message: e.toString()));
      throw AuthenticationException(e.toString());
    }
  }

  /// Revokes tokens for the current or supplied identity, then clears local
  /// state for that same session.
  ///
  /// Pass [identity] to revoke a previously captured snapshot after
  /// [clearIdentity], or while a newer login is in progress. When omitted, the
  /// currently loaded identity is snapshotted at call time.
  ///
  /// Local identity is cleared only when it still belongs to the session that
  /// started this logout. Remote logout/revocation failures are logged and
  /// returned as [LogoutStatus.remoteFailure] instead of blocking local
  /// cleanup. RFC 7009 `unsupported_token_type` is treated as a successful
  /// skip for that token.
  Future<LogoutResult> logout({OpenIdIdentity? identity}) async {
    final generation = _sessionGeneration;
    final snapshot = await _identitySnapshot(identity);
    if (snapshot == null) {
      const result = LogoutResult(
        status: LogoutStatus.skipped,
        message: 'Logout skipped because no identity is loaded.',
      );
      openIdConnectLogger.i(result.message);
      return result;
    }

    final shouldClearLocal = _shouldClearIdentity(snapshot);
    if (shouldClearLocal) {
      _cancelAutoRenewTimer();
    }

    return _completeLogout(
      generation: generation,
      shouldClearLocal: shouldClearLocal,
      remoteLogout: () async {
        await _verifyDiscoveryDocument();
        await revokeTokens(identity: snapshot);
        return null;
      },
    );
  }

  /// Performs RP-initiated logout when supported, while also revoking tokens
  /// and clearing persisted identity state for that session.
  ///
  /// Pass [identity] to use a previously captured snapshot. When omitted, the
  /// currently loaded identity is snapshotted at call time.
  ///
  /// Local identity is cleared only when it still belongs to the session that
  /// started this logout. Remote logout/revocation failures are logged and
  /// returned as [LogoutStatus.remoteFailure] instead of blocking local
  /// cleanup. RFC 7009 `unsupported_token_type` is treated as a successful
  /// skip for that token.
  Future<LogoutResult> logoutInteractive({
    required BuildContext context,
    required String title,
    OpenIdIdentity? identity,
    String? userNameHint,
    Map<String, String>? additionalParameters,
    Iterable<String>? prompts,
    bool useWebPopup = true,
    int popupWidth = 640,
    int popupHeight = 600,
    String? postLogoutRedirectUri,
    bool useBasicAuth = true,
  }) async {
    final generation = _sessionGeneration;
    final snapshot = await _identitySnapshot(identity);
    if (snapshot == null) {
      const result = LogoutResult(
        status: LogoutStatus.skipped,
        message: 'Interactive logout skipped because no identity is loaded.',
      );
      openIdConnectLogger.i(result.message);
      return result;
    }

    final shouldClearLocal = _shouldClearIdentity(snapshot);
    if (shouldClearLocal) {
      _cancelAutoRenewTimer();
    }

    return _completeLogout(
      generation: generation,
      shouldClearLocal: shouldClearLocal,
      remoteLogout: () async {
        await _verifyDiscoveryDocument();
        final endSession = configuration?.endSessionEndpoint;

        if (endSession == null) {
          openIdConnectLogger.i(
            'Provider does not advertise an end-session endpoint; revoking tokens locally.',
          );
          await revokeTokens(identity: snapshot, useBasicAuth: useBasicAuth);
          return null;
        }

        final request = InteractiveLogoutRequest(
          configuration: configuration!,
          postLogoutRedirectUrl:
              postLogoutRedirectUri ??
              redirectUrl ??
              (throw StateError(
                'When using logout interactive, you must provide a postLogoutRedirectUri or create the client with a redirect url.',
              )),
          useWebPopup: useWebPopup,
          popupHeight: popupHeight,
          popupWidth: popupWidth,
          idToken: snapshot.idToken,
        );

        if (!context.mounted) {
          throw StateError(
            'Interactive logout aborted because the calling context is no longer mounted.',
          );
        }

        if (kIsWeb) {
          final response = await OpenIdConnect.logoutInteractive(
            context: context,
            title: title,
            request: request,
          );
          await revokeTokens(identity: snapshot, useBasicAuth: useBasicAuth);
          return response;
        }

        await revokeTokens(identity: snapshot, useBasicAuth: useBasicAuth);
        if (!context.mounted) {
          throw StateError(
            'Interactive logout aborted after token revocation because the calling context is no longer mounted.',
          );
        }

        return OpenIdConnect.logoutInteractive(
          context: context,
          title: title,
          request: request,
        );
      },
    );
  }

  Future<LogoutResult> _completeLogout({
    required int generation,
    required bool shouldClearLocal,
    required Future<String?> Function() remoteLogout,
  }) async {
    String? redirectUrl;
    Object? remoteError;
    var didClearLocal = false;

    try {
      if (shouldClearLocal) {
        _raiseEvent(AuthEvent(AuthEventTypes.LoggingOut));
      }
      redirectUrl = await remoteLogout();
    } on Object catch (e, stackTrace) {
      remoteError = e;
      logOpenIdConnectError(
        'Remote logout or token revocation failed; continuing with local cleanup',
        e,
        stackTrace,
      );
      _raiseEvent(
        AuthEvent(
          AuthEventTypes.Error,
          message:
              'Remote logout or token revocation failed; local identity will still be cleared: ${e.toString()}',
        ),
      );
    } finally {
      if (shouldClearLocal && _sessionGeneration == generation) {
        didClearLocal = await _clearIdentityIgnoringErrors();
        if (didClearLocal) {
          _raiseEvent(AuthEvent(AuthEventTypes.NotLoggedIn));
        }
      }
    }

    if (remoteError != null) {
      return LogoutResult(
        status: LogoutStatus.remoteFailure,
        message: didClearLocal
            ? 'Local identity was cleared, but remote logout or token revocation failed: $remoteError'
            : 'Remote logout or token revocation failed: $remoteError',
        redirectUrl: redirectUrl,
      );
    }

    return LogoutResult(
      status: LogoutStatus.success,
      message: redirectUrl == null
          ? (didClearLocal
                ? 'Logout completed and local identity was cleared.'
                : 'Logout completed.')
          : (didClearLocal
                ? 'Logout completed and local identity was cleared with redirect: $redirectUrl'
                : 'Logout completed with redirect: $redirectUrl'),
      redirectUrl: redirectUrl,
    );
  }

  /// Revokes the refresh token when available, otherwise the access token,
  /// using RFC 7009 token types only.
  ///
  /// Pass [identity] to revoke a snapshot after local identity has been
  /// cleared. ID tokens are never sent to the revocation endpoint. When the
  /// authorization server returns `unsupported_token_type`, revocation of that
  /// token is treated as successful.
  Future<void> revokeTokens({
    OpenIdIdentity? identity,
    bool useBasicAuth = true,
  }) async {
    final snapshot = await _identitySnapshot(identity);
    if (snapshot == null) return;
    if (_shouldClearIdentity(snapshot)) {
      _cancelAutoRenewTimer();
    }

    try {
      await _verifyDiscoveryDocument();

      final revocable = _revocableToken(snapshot);
      if (revocable == null) {
        openIdConnectLogger.i(
          'Token revocation skipped because no refresh or access token is available.',
        );
        return;
      }

      await OpenIdConnect.revokeToken(
        request: RevokeTokenRequest(
          clientId: clientId,
          clientSecret: clientSecret,
          configuration: configuration!,
          token: revocable.token,
          tokenType: revocable.type,
        ),
        useBasicAuth: useBasicAuth,
      );
    } on Exception catch (e, stackTrace) {
      logOpenIdConnectError('Token revocation failed', e, stackTrace);
      _raiseEvent(AuthEvent(AuthEventTypes.Error, message: e.toString()));
      rethrow;
    }
  }

  /// Returns whether the client is currently logged in, refreshing first when
  /// necessary and enabled.
  FutureOr<bool> isLoggedIn() async {
    if (!_isInitializationComplete) {
      throw StateError(
        'You must call processStartupAuthentication before using this library.',
      );
    }

    if (_identity == null) return false;

    if (!isTokenAboutToExpire) return true;

    if (autoRefresh) await refresh();

    return !hasTokenExpired;
  }

  /// Raises an explicit error event on the auth event stream.
  void reportError(String errorMessage) {
    currentEvent = AuthEvent(AuthEventTypes.Error, message: errorMessage);

    _eventStreamController.add(currentEvent!);
  }

  /// Ensures authentication is valid before executing a batch of asynchronous
  /// requests.
  Future<void> sendRequests<T>(Iterable<Future<T>> Function() requests) async {
    if ((_identity == null || isTokenAboutToExpire) &&
        (!autoRefresh || !await refresh(raiseEvents: true))) {
      throw AuthenticationException();
    }

    await Future.wait(requests());
  }

  /// Verifies that the current token is still usable, refreshing when needed.
  FutureOr<bool> verifyToken() async {
    if (_identity == null) return false;

    if (isTokenAboutToExpire && !await refresh(raiseEvents: true)) return false;

    return true;
  }

  /// Refreshes the current identity using the stored refresh token.
  ///
  /// Returns `false` when refresh is not possible or fails.
  Future<bool> refresh({bool raiseEvents = true}) async {
    if (!webUseRefreshTokens) {
      //Web has a special case where it will use a hidden iframe. This just returns true because the iframe does it.
      //In this case we simply load from storage because the web implementation just stores the new values in storage for us.
      _identity = await OpenIdIdentity.load(tenantId: tenantId);
      return true;
    }

    while (_refreshing) {
      await Future<void>.delayed(Duration(milliseconds: 200));
    }

    try {
      _refreshing = true;
      _cancelAutoRenewTimer();
      final generation = _sessionGeneration;
      final refreshToken = _identity?.refreshToken;
      final idToken = _identity?.idToken;
      if (refreshToken == null || refreshToken.isEmpty || idToken == null) {
        return false;
      }
      _inFlightRefreshToken = refreshToken;

      await _verifyDiscoveryDocument();
      if (_sessionGeneration != generation) {
        return false;
      }

      final response = await OpenIdConnect.refreshToken(
        request: RefreshRequest(
          clientId: clientId,
          clientSecret: clientSecret,
          scopes: _getScopes(scopes),
          refreshToken: refreshToken,
          currentIdToken: idToken,
          configuration: configuration!,
        ),
      );

      final rotated = OpenIdIdentity.fromAuthorizationResponse(response);
      if (_sessionGeneration != generation) {
        _rotatedFromRefreshToken = refreshToken;
        _rotatedTokensForRevocation = rotated;
        return false;
      }

      await _completeLogin(response);

      if (_sessionGeneration != generation || _identity == null) {
        return false;
      }

      if (autoRefresh) {
        var refreshTime = _identity!.expiresAt.difference(
          DateTime.now().toUtc(),
        );
        refreshTime -= Duration(minutes: 1);

        _autoRenewTimer = Timer(refreshTime, refresh);
      }

      if (raiseEvents) _raiseEvent(AuthEvent(AuthEventTypes.Refresh));

      return true;
    } on Exception catch (e, stackTrace) {
      // In case when refresh request fails but we know that identity is present
      // and the token has not expired, we can keep the identity and raise an
      // error event to notify the app that there is an issue while refreshing
      // the token.
      //
      // There is no need to clear the identity in this case because it is still
      // valid.
      if (identity != null && !hasTokenExpired) {
        logOpenIdConnectWarning(
          'Token refresh failed while the current identity is still valid',
          e,
          stackTrace,
        );
        _raiseEvent(AuthEvent(AuthEventTypes.Error, message: e.toString()));
        return false;
      }

      // Otherwise, if the identity has already expired, then we clear it and
      // raise the AuthEventTypes.NotLoggedIn to notify the app that the user
      // should log in again.
      logOpenIdConnectError(
        'Token refresh failed and the identity has expired; clearing local identity',
        e,
        stackTrace,
      );
      await _clearIdentityIgnoringErrors();
      _raiseEvent(AuthEvent(AuthEventTypes.NotLoggedIn, message: e.toString()));
      return false;
    } finally {
      _inFlightRefreshToken = null;
      _refreshing = false;
    }
  }

  /// Clears the persisted identity from storage and memory.
  ///
  /// Increments the session generation so an in-flight [logout] for the
  /// previous identity will not clear a later login.
  Future<void> clearIdentity() async {
    await _clearCurrentIdentity();
  }

  Future<bool> _clearCurrentIdentity() async {
    if (_identity == null) return false;
    final generation = ++_sessionGeneration;
    try {
      await _enqueueIdentityWrite(() async {
        if (_sessionGeneration != generation) return;
        await OpenIdIdentity.clear(tenantId: tenantId);
      });
    } finally {
      if (_sessionGeneration == generation) {
        _cancelAutoRenewTimer();
        _identity = null;
      }
    }
    return _sessionGeneration == generation && _identity == null;
  }

  Future<bool> _clearIdentityIgnoringErrors() async {
    try {
      return await _clearCurrentIdentity();
    } on Exception catch (e, stackTrace) {
      logOpenIdConnectWarning(
        'Best-effort identity cleanup failed; discarding in-memory identity',
        e,
        stackTrace,
      );
      return _identity == null;
    }
  }

  void _raiseEvent(AuthEvent evt) {
    currentEvent = evt;
    _eventStreamController.sink.add(evt);
  }

  Future<void> _completeLogin(
    AuthorizationResponse response, {
    bool beginSession = false,
  }) async {
    final identity = OpenIdIdentity.fromAuthorizationResponse(response);
    if (beginSession) {
      _sessionGeneration++;
    }
    final generation = _sessionGeneration;
    _identity = identity;
    await _enqueueIdentityWrite(() async {
      if (_sessionGeneration != generation) return;
      await identity.save(tenantId: tenantId);
    });
  }

  Future<OpenIdIdentity?> _identitySnapshot(OpenIdIdentity? identity) async {
    final captured = identity ?? _identity;
    if (captured == null) return null;
    final generation = _sessionGeneration;
    await _waitForMatchingRefresh(captured);
    final rotated = _rotatedTokensFor(captured);
    if (rotated != null) return rotated;
    if (identity != null) return identity;
    if (_sessionGeneration == generation) {
      return _identity ?? captured;
    }
    return captured;
  }

  Future<void> _waitForMatchingRefresh(OpenIdIdentity snapshot) async {
    final refreshToken = snapshot.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return;
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (_refreshing &&
        _inFlightRefreshToken == refreshToken &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  OpenIdIdentity? _rotatedTokensFor(OpenIdIdentity snapshot) {
    final from = _rotatedFromRefreshToken;
    final rotated = _rotatedTokensForRevocation;
    if (from == null || rotated == null) return null;
    if (snapshot.refreshToken != from) return null;
    _rotatedFromRefreshToken = null;
    _rotatedTokensForRevocation = null;
    return rotated;
  }

  Future<T> _enqueueIdentityWrite<T>(Future<T> Function() write) {
    final previous = _identityWriteQueue;
    final gate = Completer<void>();
    _identityWriteQueue = gate.future;
    return () async {
      try {
        await previous;
      } catch (_) {}
      try {
        return await write();
      } finally {
        if (!gate.isCompleted) gate.complete();
      }
    }();
  }

  bool _shouldClearIdentity(OpenIdIdentity snapshot) {
    final current = _identity;
    if (current == null) return false;
    return _sameSessionTokens(current, snapshot);
  }

  bool _sameSessionTokens(OpenIdIdentity current, OpenIdIdentity snapshot) {
    final snapshotRefresh = snapshot.refreshToken;
    final currentRefresh = current.refreshToken;
    if (snapshotRefresh != null &&
        snapshotRefresh.isNotEmpty &&
        currentRefresh != null &&
        currentRefresh.isNotEmpty) {
      return currentRefresh == snapshotRefresh;
    }
    return current.accessToken == snapshot.accessToken;
  }

  ({String token, TokenType type})? _revocableToken(OpenIdIdentity snapshot) {
    final refreshToken = snapshot.refreshToken;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      return (token: refreshToken, type: TokenType.refreshToken);
    }
    if (snapshot.accessToken.isNotEmpty) {
      return (token: snapshot.accessToken, type: TokenType.accessToken);
    }
    return null;
  }

  Future<bool> _setupAutoRenew() async {
    _cancelAutoRenewTimer();

    if (isTokenAboutToExpire) {
      return await refresh(
        raiseEvents: false,
      ); //This will set the timer itself.
    } else {
      var refreshTime = _identity!.expiresAt.difference(DateTime.now().toUtc());

      refreshTime -= Duration(minutes: 1);

      _autoRenewTimer = Timer(refreshTime, refresh);
      return true;
    }
  }

  Future<void> _verifyDiscoveryDocument() async {
    if (configuration != null) return;

    configuration = await OpenIdConnect.getConfiguration(discoveryDocumentUrl);
  }

  ///Gets the proper scopes and adds offline access if the user has it specified in the configuration for the client.
  Iterable<String> _getScopes(Iterable<String> scopes) {
    if (autoRefresh && !scopes.contains(OFFLINE_ACCESS_SCOPE)) {
      return [OFFLINE_ACCESS_SCOPE, ...scopes];
    }
    return scopes;
  }
}
