part of openidconnect;

class OpenIdConnectClient {
  static const DEFAULT_SCOPES = [
    "openid",
    "profile",
    "email",
    "offline_access"
  ];

  final _eventStreamController = StreamController<AuthEvent>();

  final String discoveryDocumentUrl;
  final String clientId;
  final String? clientSecret;
  final String redirectUrl;
  final bool autoRefresh;
  final bool webUseRefreshTokens;
  final List<String> scopes;
  final List<String>? audiences;

  OpenIdConfiguration? configuration = null;
  Future<bool>? _autoRenewTimer = null;
  OpenIdIdentity? _identity = null;
  bool _refreshing = false;

  OpenIdConnectClient({
    required this.discoveryDocumentUrl,
    required this.clientId,
    required this.redirectUrl,
    this.clientSecret,
    this.autoRefresh = true,
    this.webUseRefreshTokens = true,
    this.scopes = DEFAULT_SCOPES,
    this.audiences,
  });

  void dispose() {
    _eventStreamController.close();
  }

  Stream<AuthEvent> get changes =>
      _eventStreamController.stream.asBroadcastStream();

  OpenIdIdentity? get identity => _identity;

  bool get hasTokenExpired =>
      _identity!.expiresAt.difference(DateTime.now().toUtc()).isNegative;

  bool get isTokenAboutToExpire {
    var refreshTime = _identity!.expiresAt.difference(DateTime.now().toUtc());
    refreshTime -= Duration(minutes: 1);
    return refreshTime.isNegative;
  }

  bool get isLoggedIn => _identity != null;

  Future<bool> loginWithPassword(
      {required String userName,
      required String password,
      Iterable<String>? prompts,
      Map<String, String>? additionalParameters}) async {
    if (_autoRenewTimer != null) _autoRenewTimer = null;

    try {
      //Make sure we have the discovery information
      await _verifyDiscoveryDocument();

      final request = PasswordAuthorizationRequest(
        configuration: configuration!,
        password: password,
        scopes: scopes,
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

      _eventStreamController.add(AuthEvent(AuthEventTypes.Success));

      return true;
    } on Exception catch (e) {
      if (this._identity != null) {
        await this._identity!.clear();
        this._identity = null;
      }
      _eventStreamController
          .add(AuthEvent(AuthEventTypes.Error, message: e.toString()));
      return false;
    }
  }

  Future<void> loginWithDeviceCode() async {
    if (_autoRenewTimer != null) _autoRenewTimer = null;

    //Make sure we have the discovery information
    await _verifyDiscoveryDocument();

    //Get the token information and prompt for login if necessary.
    try {
      final response = await OpenIdConnect.authorizeDevice(
        request: DeviceAuthorizationRequest(
          clientId: clientId,
          scopes: scopes,
          audience: audiences != null ? audiences!.join(" ") : null,
          configuration: configuration!,
        ),
      );
      //Load the idToken here
      await _completeLogin(response);

      if (autoRefresh) _setupAutoRenew();

      _eventStreamController.add(AuthEvent(AuthEventTypes.Success));
    } on Exception catch (e) {
      if (this._identity != null) {
        await this._identity!.clear();
        this._identity = null;
      }

      _eventStreamController
          .add(AuthEvent(AuthEventTypes.Error, message: e.toString()));
    }
  }

  Future<void> loginInteractive({
    required BuildContext context,
    required String title,
    String? userNameHint,
    Map<String, String>? additionalParameters,
    Iterable<String>? prompts,
  }) async {
    if (_autoRenewTimer != null) _autoRenewTimer = null;

    //Make sure we have the discovery information
    await _verifyDiscoveryDocument();

    //Get the token information and prompt for login if necessary.
    try {
      final response = await OpenIdConnect.authorizeInteractive(
        context: context,
        title: title,
        request: InteractiveAuthorizationRequest(
          configuration: configuration!,
          clientId: clientId,
          redirectUrl: this.redirectUrl,
          clientSecret: this.clientSecret,
          loginHint: userNameHint,
          additionalParameters: additionalParameters,
          scopes: scopes,
          autoRefresh: autoRefresh,
          prompts: prompts,
        ),
      );
      //Load the idToken here
      await _completeLogin(response);

      if (autoRefresh) _setupAutoRenew();

      _eventStreamController.add(AuthEvent(AuthEventTypes.Success));
    } on Exception catch (e) {
      if (this._identity != null) {
        await this._identity!.clear();
        this._identity = null;
      }

      _eventStreamController
          .add(AuthEvent(AuthEventTypes.Error, message: e.toString()));
    }
  }

  Future<bool> logout() async {
    if (_autoRenewTimer != null) _autoRenewTimer = null;

    if (_identity == null) return true;

    //Make sure we have the discovery information
    await _verifyDiscoveryDocument();

    return await OpenIdConnect.logout(
      request: LogoutRequest(
        configuration: configuration!,
        idToken: _identity!.idToken,
        state: _identity!.state,
      ),
    );
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
      if (_autoRenewTimer != null) _autoRenewTimer = null;

      if (this._identity == null ||
          this._identity!.refreshToken == null ||
          this._identity!.refreshToken!.isEmpty) return false;

      await _verifyDiscoveryDocument();

      final response = await OpenIdConnect.refreshToken(
        request: RefreshRequest(
          clientId: clientId,
          redirectUrl: redirectUrl,
          scopes: scopes,
          refreshToken: _identity!.refreshToken!,
          configuration: configuration!,
          autoRefresh: autoRefresh,
        ),
      );

      await _completeLogin(response);

      if (autoRefresh) {
        final refreshTime = _identity!.expiresAt
            .difference(DateTime.now().subtract(Duration(minutes: 1)));

        _autoRenewTimer = Future.delayed(refreshTime, refresh);
      }

      if (raiseEvents)
        _eventStreamController.add(AuthEvent(AuthEventTypes.Refresh));

      return true;
    } on Exception catch (e) {
      if (this._identity != null) {
        await this._identity!.clear();
        this._identity = null;

        _eventStreamController
            .add(AuthEvent(AuthEventTypes.Error, message: e.toString()));
      }
      return false;
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _completeLogin(AuthorizationResponse response) async {
    this._identity = OpenIdIdentity.fromAuthorizationResponse(response);

    await this._identity!.save();
  }

  Future<bool> _setupAutoRenew() async {
    if (_autoRenewTimer != null) _autoRenewTimer = null;

    if (isTokenAboutToExpire) {
      return await refresh(
          raiseEvents: false); //This will set the timer itself.
    } else {
      var refreshTime = _identity!.expiresAt.difference(DateTime.now().toUtc());

      refreshTime -= Duration(minutes: 1);

      _autoRenewTimer = Future.delayed(refreshTime, refresh);
      return true;
    }
  }

  Future<void> _verifyDiscoveryDocument() async {
    if (configuration != null) return;

    configuration = await OpenIdConnect.getConfiguration(
      this.discoveryDocumentUrl,
    );
  }
}
