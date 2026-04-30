part of openidconnect;

class OpenIdConnectClient {
  static const OFFLINE_ACCESS_SCOPE = "offline_access";
  static const DEFAULT_SCOPES = ["openid", "profile", "email"];

  final _eventStreamController = StreamController<AuthEvent>();

  final String discoveryDocumentUrl;
  final String clientId;
  final String? clientSecret;
  final String? redirectUrl;
  final bool autoRefresh;
  final bool webUseRefreshTokens;
  final List<String> scopes;
  final List<String>? audiences;

  OpenIdConfiguration? configuration = null;
  Timer? _autoRenewTimer = null;
  OpenIdIdentity? _identity = null;
  bool _refreshing = false;
  bool _isInitializationComplete = false;

  AuthEvent? currentEvent;

  OpenIdConnectClient._({
    required this.discoveryDocumentUrl,
    required this.clientId,
    this.redirectUrl,
    this.clientSecret,
    this.autoRefresh = true,
    this.webUseRefreshTokens = true,
    this.scopes = DEFAULT_SCOPES,
    this.audiences,
  });

  static Future<OpenIdConnectClient> create({
    required String discoveryDocumentUrl,
    required String clientId,
    required String encryptionKey,
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
        await this._identity?.save();
      }
    }

    if (_identity == null) _identity = await OpenIdIdentity.load();
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

  void dispose() {
    _eventStreamController.close();
  }

  Stream<AuthEvent> get changes =>
      _eventStreamController.stream.asBroadcastStream();

  OpenIdIdentity? get identity => _identity;

  bool get initializationComplete => _isInitializationComplete;

  bool get hasTokenExpired =>
      _identity!.expiresAt.difference(DateTime.now().toUtc()).isNegative;

  bool get isTokenAboutToExpire {
    var refreshTime = _identity!.expiresAt.difference(DateTime.now().toUtc());
    refreshTime -= Duration(minutes: 1);
    return refreshTime.isNegative;
  }

  Future<OpenIdIdentity> loginWithPassword({
    required String userName,
    required String password,
    Iterable<String>? prompts,
    Map<String, String>? additionalParameters,
  }) async {
    if (_autoRenewTimer != null) _autoRenewTimer = null;

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
    } on Exception catch (e) {
      clearIdentity();
      _raiseEvent(AuthEvent(AuthEventTypes.Error, message: e.toString()));
      throw AuthenticationException(e.toString());
    }
  }

  Future<OpenIdIdentity> loginWithDeviceCode() async {
    if (_autoRenewTimer != null) _autoRenewTimer = null;

    //Make sure we have the discovery information
    await _verifyDiscoveryDocument();

    //Get the token information and prompt for login if necessary.
    try {
      final response = await OpenIdConnect.authorizeDevice(
        request: DeviceAuthorizationRequest(
          clientId: clientId,
          scopes: _getScopes(scopes),
          audience: audiences != null ? audiences!.join(" ") : null,
          configuration: configuration!,
        ),
      );
      //Load the idToken here
      await _completeLogin(response);

      if (autoRefresh) _setupAutoRenew();

      _raiseEvent(AuthEvent(AuthEventTypes.Success));
      return _identity!;
    } on Exception catch (e) {
      clearIdentity();
      _raiseEvent(AuthEvent(AuthEventTypes.Error, message: e.toString()));
      throw AuthenticationException(e.toString());
    }
  }

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
    if (this.redirectUrl == null)
      throw StateError(
        "When using login interactive, you must create the client with a redirect url.",
      );

    if (_autoRenewTimer != null) _autoRenewTimer = null;

    //Make sure we have the discovery information
    await _verifyDiscoveryDocument();

    //Get the token information and prompt for login if necessary.
    try {
      final response = await OpenIdConnect.authorizeInteractive(
        context: context,
        title: title,
        request: await InteractiveAuthorizationRequest.create(
          configuration: configuration!,
          clientId: clientId,
          redirectUrl: this.redirectUrl!,
          clientSecret: this.clientSecret,
          loginHint: userNameHint,
          additionalParameters: additionalParameters,
          scopes: _getScopes(scopes),
          autoRefresh: autoRefresh,
          prompts: prompts,
          useWebPopup: useWebPopup,
          popupHeight: popupHeight,
          popupWidth: popupWidth,
        ),
      );

      if (response == null) throw StateError(ERROR_USER_CLOSED);

      //Load the idToken here
      await _completeLogin(response);

      if (autoRefresh) _setupAutoRenew();

      _raiseEvent(AuthEvent(AuthEventTypes.Success));

      return _identity!;
    } on Exception catch (e) {
      clearIdentity();
      _raiseEvent(AuthEvent(AuthEventTypes.Error, message: e.toString()));
      throw AuthenticationException(e.toString());
    }
  }

  Future<void> logout() async {
    if (_autoRenewTimer != null) _autoRenewTimer = null;

    if (_identity == null) return;

    try {
      //Make sure we have the discovery information
      await _verifyDiscoveryDocument();

      _raiseEvent(AuthEvent(AuthEventTypes.LoggingOut));

      await revokeTokens();

      clearIdentity();
    } on Exception catch (e) {
      _raiseEvent(
        AuthEvent(
          AuthEventTypes.Error,
          message: "Error during logout: ${e.toString()}",
        ),
      );

      rethrow;
    }

    _raiseEvent(AuthEvent(AuthEventTypes.NotLoggedIn));
  }

  // Example: add this method to OpenIdConnectClient
  Future<String?> logoutInteractive({
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
    if (_identity == null) return null;

    await _verifyDiscoveryDocument();
    final endSession = configuration?.endSessionEndpoint;
    _raiseEvent(AuthEvent(AuthEventTypes.LoggingOut));

    // If provider doesn't support end_session, just revoke and clear locally
    if (endSession == null) {
      await revokeTokens(
        useBasicAuth: useBasicAuth,
      ); // keep existing revoke logic (revokes refresh/access)
      await clearIdentity();
      _raiseEvent(AuthEvent(AuthEventTypes.NotLoggedIn));
      return null;
    }

    final request = InteractiveLogoutRequest(
      configuration: configuration!,
      postLogoutRedirectUrl: this.redirectUrl!,
      useWebPopup: useWebPopup,
      popupHeight: popupHeight,
      popupWidth: popupWidth,
      idToken: _identity!.idToken,
    );
    String? response;
    if (kIsWeb) {
      response = await OpenIdConnect.logoutInteractive(
        context: context,
        title: "Logout",
        request: request,
      );

      await revokeTokens(
        useBasicAuth: useBasicAuth,
      ); // keep existing revoke logic (revokes refresh/access)
    } else {
      await revokeTokens(
        useBasicAuth: useBasicAuth,
      ); // keep existing revoke logic (revokes refresh/access)
      response = await OpenIdConnect.logoutInteractive(
        context: context,
        title: "Logout",
        request: request,
      );
    }

    await clearIdentity();
    _raiseEvent(AuthEvent(AuthEventTypes.NotLoggedIn));

    return response;
  }

  Future<void> revokeTokens({bool useBasicAuth = true}) async {
    if (_autoRenewTimer != null) _autoRenewTimer = null;

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
    } on Exception catch (e) {
      _raiseEvent(AuthEvent(AuthEventTypes.Error, message: e.toString()));
    }
  }

  FutureOr<bool> isLoggedIn() async {
    if (!_isInitializationComplete)
      throw StateError(
        'You must call processStartupAuthentication before using this library.',
      );

    if (_identity == null) return false;

    if (!isTokenAboutToExpire) return true;

    if (this.autoRefresh) await refresh();

    return !hasTokenExpired;
  }

  void reportError(String errorMessage) {
    currentEvent = AuthEvent(AuthEventTypes.Error, message: errorMessage);

    _eventStreamController.add(currentEvent!);
  }

  Future<void> sendRequests<T>(Iterable<Future<T>> Function() requests) async {
    if ((_identity == null || isTokenAboutToExpire) &&
        (!this.autoRefresh || !await refresh(raiseEvents: true)))
      throw AuthenticationException();

    await Future.wait(requests());
  }

  FutureOr<bool> verifyToken() async {
    if (_identity == null) return false;

    if (isTokenAboutToExpire && !await refresh(raiseEvents: true)) return false;

    return true;
  }

  Future<bool> refresh({bool raiseEvents = true}) async {
    if (!webUseRefreshTokens) {
      //Web has a special case where it will use a hidden iframe. This just returns true because the iframe does it.
      //In this case we simply load from storage because the web implementation just stores the new values in storage for us.
      _identity = await OpenIdIdentity.load();
      return true;
    }

    while (_refreshing) await Future<void>.delayed(Duration(milliseconds: 200));

    try {
      _refreshing = true;
      if (_autoRenewTimer != null) {
        _autoRenewTimer?.cancel();
        _autoRenewTimer = null;
      }

      if (this._identity == null ||
          this._identity!.refreshToken == null ||
          this._identity!.refreshToken!.isEmpty)
        return false;

      await _verifyDiscoveryDocument();

      final response = await OpenIdConnect.refreshToken(
        request: RefreshRequest(
          clientId: clientId,
          clientSecret: clientSecret,
          scopes: _getScopes(scopes),
          refreshToken: _identity!.refreshToken!,
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
    } on Exception catch (e) {
      // In case when refresh request fails but we know that identity is present
      // and the token has not expired, we can keep the identity and raise an
      // error event to notify the app that there is an issue while refreshing
      // the token.
      //
      // There is no need to clear the identity in this case because it is still
      // valid.
      if (identity != null && !hasTokenExpired) {
        _raiseEvent(AuthEvent(AuthEventTypes.Error, message: e.toString()));
        return false;
      }

      // Otherwise, if the identity has already expired, then we clear it and
      // raise the AuthEventTypes.NotLoggedIn to notify the app that the user
      // should log in again.
      clearIdentity();
      _raiseEvent(AuthEvent(AuthEventTypes.NotLoggedIn, message: e.toString()));
      return false;
    } finally {
      _refreshing = false;
    }
  }

  Future<void> clearIdentity() async {
    if (this._identity != null) {
      await OpenIdIdentity.clear();
      this._identity = null;
    }
  }

  void _raiseEvent(AuthEvent evt) {
    currentEvent = evt;
    _eventStreamController.sink.add(evt);
  }

  Future<void> _completeLogin(AuthorizationResponse response) async {
    this._identity = OpenIdIdentity.fromAuthorizationResponse(response);

    await this._identity!.save();
  }

  Future<bool> _setupAutoRenew() async {
    if (_autoRenewTimer != null) {
      _autoRenewTimer?.cancel();
      _autoRenewTimer = null;
    }

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

    configuration = await OpenIdConnect.getConfiguration(
      this.discoveryDocumentUrl,
    );
  }

  ///Gets the proper scopes and adds offline access if the user has it specified in the configuration for the client.
  Iterable<String> _getScopes(Iterable<String> scopes) {
    if (autoRefresh && !scopes.contains(OFFLINE_ACCESS_SCOPE))
      return [OFFLINE_ACCESS_SCOPE, ...scopes];
    return scopes;
  }
}
