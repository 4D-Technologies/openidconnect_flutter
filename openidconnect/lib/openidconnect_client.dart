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
  bool _refreshing = false;
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
      await _completeLogin(response);

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
      await _completeLogin(response);

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
      await _completeLogin(response);

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

  /// Revokes the current tokens, clears persisted identity state, and raises a
  /// not-logged-in event.
  ///
  /// Local identity is always cleared when one was present. Remote
  /// logout/revocation failures are logged and returned as
  /// [LogoutStatus.remoteFailure] instead of blocking local cleanup.
  Future<LogoutResult> logout() async {
    _cancelAutoRenewTimer();

    if (_identity == null) {
      const result = LogoutResult(
        status: LogoutStatus.skipped,
        message: 'Logout skipped because no identity is loaded.',
      );
      openIdConnectLogger.i(result.message);
      return result;
    }

    return _completeLogout(() async {
      await _verifyDiscoveryDocument();
      _raiseEvent(AuthEvent(AuthEventTypes.LoggingOut));
      await revokeTokens();
      return null;
    });
  }

  /// Performs RP-initiated logout when supported, while also revoking local
  /// tokens and clearing persisted identity state.
  ///
  /// Local identity is always cleared when one was present. Remote
  /// logout/revocation failures are logged and returned as
  /// [LogoutStatus.remoteFailure] instead of blocking local cleanup.
  Future<LogoutResult> logoutInteractive({
    required BuildContext context,
    required String title,
    String? userNameHint,
    Map<String, String>? additionalParameters,
    Iterable<String>? prompts,
    bool useWebPopup = true,
    int popupWidth = 640,
    int popupHeight = 600,
    String? postLogoutRedirectUri,
    bool useBasicAuth = true,
  }) async {
    if (_identity == null) {
      const result = LogoutResult(
        status: LogoutStatus.skipped,
        message: 'Interactive logout skipped because no identity is loaded.',
      );
      openIdConnectLogger.i(result.message);
      return result;
    }

    return _completeLogout(() async {
      await _verifyDiscoveryDocument();
      final endSession = configuration?.endSessionEndpoint;
      _raiseEvent(AuthEvent(AuthEventTypes.LoggingOut));

      if (endSession == null) {
        openIdConnectLogger.i(
          'Provider does not advertise an end-session endpoint; revoking tokens locally.',
        );
        await revokeTokens(useBasicAuth: useBasicAuth);
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
        idToken: _identity!.idToken,
      );

      if (!context.mounted) {
        openIdConnectLogger.w(
          'Interactive logout aborted because the calling context is no longer mounted.',
        );
        return null;
      }

      if (kIsWeb) {
        final response = await OpenIdConnect.logoutInteractive(
          context: context,
          title: title,
          request: request,
        );
        await revokeTokens(useBasicAuth: useBasicAuth);
        return response;
      }

      await revokeTokens(useBasicAuth: useBasicAuth);
      if (!context.mounted) {
        openIdConnectLogger.w(
          'Interactive logout aborted after token revocation because the calling context is no longer mounted.',
        );
        return null;
      }

      return OpenIdConnect.logoutInteractive(
        context: context,
        title: title,
        request: request,
      );
    });
  }

  Future<LogoutResult> _completeLogout(
    Future<String?> Function() remoteLogout,
  ) async {
    String? redirectUrl;
    Object? remoteError;

    try {
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
          message: 'Error during logout: ${e.toString()}',
        ),
      );
    } finally {
      await _clearIdentityIgnoringErrors();
    }

    _raiseEvent(AuthEvent(AuthEventTypes.NotLoggedIn));

    if (remoteError != null) {
      return LogoutResult(
        status: LogoutStatus.remoteFailure,
        message:
            'Local identity was cleared, but remote logout or token revocation failed: $remoteError',
        redirectUrl: redirectUrl,
      );
    }

    return LogoutResult(
      status: LogoutStatus.success,
      message: redirectUrl == null
          ? 'Logout completed and local identity was cleared.'
          : 'Logout completed and local identity was cleared with redirect: $redirectUrl',
      redirectUrl: redirectUrl,
    );
  }

  /// Revokes the current refresh token when available, otherwise the access
  /// token.
  Future<void> revokeTokens({bool useBasicAuth = true}) async {
    _cancelAutoRenewTimer();

    if (_identity == null) return;

    try {
      //Make sure we have the discovery information
      await _verifyDiscoveryDocument();

      if (_identity!.refreshToken != null &&
          _identity!.refreshToken!.isNotEmpty) {
        await OpenIdConnect.revokeToken(
          request: RevokeTokenRequest(
            clientId: clientId,
            clientSecret: clientSecret,
            configuration: configuration!,
            token: _identity!.refreshToken!,
            tokenType: TokenType.refreshToken,
          ),
          useBasicAuth: useBasicAuth,
        );
      } else {
        //Revoking access tokens happens automatically with refresh tokens.
        await OpenIdConnect.revokeToken(
          request: RevokeTokenRequest(
            clientId: clientId,
            clientSecret: clientSecret,
            configuration: configuration!,
            token: _identity!.accessToken,
            tokenType: TokenType.accessToken,
          ),
          useBasicAuth: useBasicAuth,
        );
      }
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

      if (_identity == null ||
          _identity!.refreshToken == null ||
          _identity!.refreshToken!.isEmpty) {
        return false;
      }

      await _verifyDiscoveryDocument();

      final response = await OpenIdConnect.refreshToken(
        request: RefreshRequest(
          clientId: clientId,
          clientSecret: clientSecret,
          scopes: _getScopes(scopes),
          refreshToken: _identity!.refreshToken!,
          currentIdToken: _identity!.idToken,
          configuration: configuration!,
        ),
      );

      await _completeLogin(response);

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
      _refreshing = false;
    }
  }

  /// Clears the persisted identity from storage and memory.
  Future<void> clearIdentity() async {
    if (_identity != null) {
      await OpenIdIdentity.clear(tenantId: tenantId);
      _identity = null;
    }
  }

  Future<void> _clearIdentityIgnoringErrors() async {
    try {
      await clearIdentity();
    } on Exception catch (e, stackTrace) {
      logOpenIdConnectWarning(
        'Best-effort identity cleanup failed; discarding in-memory identity',
        e,
        stackTrace,
      );
      _identity = null;
    }
  }

  void _raiseEvent(AuthEvent evt) {
    currentEvent = evt;
    _eventStreamController.sink.add(evt);
  }

  Future<void> _completeLogin(AuthorizationResponse response) async {
    _identity = OpenIdIdentity.fromAuthorizationResponse(response);

    await _identity!.save(tenantId: tenantId);
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
