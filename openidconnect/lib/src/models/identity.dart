part of openidconnect;

/// Represents a persisted OpenID Connect identity and its decoded ID token
/// claims.
class OpenIdIdentity extends AuthorizationResponse {
  static const String _AUTHENTICATION_TOKEN_KEY = "ACCESS_TOKEN";
  static const String _ID_TOKEN_KEY = "ID_TOKEN";
  static const String _REFRESH_TOKEN_KEY = "REFRESH_TOKEN";
  static const String _TOKEN_TYPE_KEY = "TOKEN_TYPE";
  static const String _EXPIRES_ON_KEY = "EXPIRES_ON";
  static const String _STATE_KEY = "STATE";

  late Map<String, dynamic> claims;
  late String sub;

  /// Creates an identity from tokens returned by the provider.
  OpenIdIdentity({
    required String accessToken,
    required DateTime expiresAt,
    required String idToken,
    required String tokenType,
    String? refreshToken,
    String? state,
  }) : super(
         expiresAt: expiresAt,
         tokenType: tokenType,
         accessToken: accessToken,
         idToken: idToken,
         refreshToken: refreshToken,
         state: state,
       ) {
    this.claims = _decodeJwtPayload(idToken);
    final subject = claims["sub"]?.toString();
    if (subject == null || subject.isEmpty) {
      throw const FormatException('Missing sub claim');
    }

    this.sub = subject;
  }

  /// Creates an identity from an [AuthorizationResponse].
  factory OpenIdIdentity.fromAuthorizationResponse(
    AuthorizationResponse response,
  ) => OpenIdIdentity(
    accessToken: response.accessToken,
    expiresAt: response.expiresAt,
    idToken: response.idToken,
    tokenType: response.tokenType,
    refreshToken: response.refreshToken,
    state: response.state,
  );

  /// Loads a previously persisted identity from secure storage.
  static Future<OpenIdIdentity?> load({String? tenantId}) async {
    try {
      late String? accessToken;
      late String? refreshToken;
      late int expiresOn;
      late String tokenType;
      late String? idToken;
      late String? state;

      accessToken = await _OpenIdConnectSecureStorage.getString(
        _storageKey(_AUTHENTICATION_TOKEN_KEY, tenantId),
      );
      idToken = await _OpenIdConnectSecureStorage.getString(
        _storageKey(_ID_TOKEN_KEY, tenantId),
      );
      expiresOn =
          await _OpenIdConnectSecureStorage.getInt(
            _storageKey(_EXPIRES_ON_KEY, tenantId),
          ) ??
          0;
      tokenType =
          await _OpenIdConnectSecureStorage.getString(
            _storageKey(_TOKEN_TYPE_KEY, tenantId),
          ) ??
          "bearer";
      state = await _OpenIdConnectSecureStorage.getString(
        _storageKey(_STATE_KEY, tenantId),
      );
      refreshToken = await _OpenIdConnectSecureStorage.getString(
        _storageKey(_REFRESH_TOKEN_KEY, tenantId),
      );

      if (accessToken == null || idToken == null) return null;

      return OpenIdIdentity(
        accessToken: accessToken,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresOn),
        idToken: idToken,
        tokenType: tokenType,
        refreshToken: refreshToken,
        state: state,
      );
    } on Exception {
      try {
        await clear(tenantId: tenantId);
      } on Exception {}
      return null; //Invalid values, flush.
    }
  }

  /// Persists this identity to secure storage.
  Future<void> save({String? tenantId}) async {
    await Future.wait([
      _OpenIdConnectSecureStorage.setString(
        _storageKey(_AUTHENTICATION_TOKEN_KEY, tenantId),
        this.accessToken,
      ),
      _OpenIdConnectSecureStorage.setString(
        _storageKey(_ID_TOKEN_KEY, tenantId),
        this.idToken,
      ),
      _OpenIdConnectSecureStorage.setString(
        _storageKey(_TOKEN_TYPE_KEY, tenantId),
        this.tokenType,
      ),
      _OpenIdConnectSecureStorage.setInt(
        _storageKey(_EXPIRES_ON_KEY, tenantId),
        this.expiresAt.millisecondsSinceEpoch,
      ),
    ]);

    this.refreshToken == null
        ? await _OpenIdConnectSecureStorage.remove(
            _storageKey(_REFRESH_TOKEN_KEY, tenantId),
          )
        : await _OpenIdConnectSecureStorage.setString(
            _storageKey(_REFRESH_TOKEN_KEY, tenantId),
            this.refreshToken!,
          );

    this.state == null
        ? await _OpenIdConnectSecureStorage.remove(
            _storageKey(_STATE_KEY, tenantId),
          )
        : await _OpenIdConnectSecureStorage.setString(
            _storageKey(_STATE_KEY, tenantId),
            this.state!,
          );
  }

  /// Removes any persisted identity from secure storage.
  static Future<void> clear({String? tenantId}) async {
    await Future.wait([
      _OpenIdConnectSecureStorage.remove(
        _storageKey(_AUTHENTICATION_TOKEN_KEY, tenantId),
      ),
      _OpenIdConnectSecureStorage.remove(_storageKey(_ID_TOKEN_KEY, tenantId)),
      _OpenIdConnectSecureStorage.remove(
        _storageKey(_REFRESH_TOKEN_KEY, tenantId),
      ),
      _OpenIdConnectSecureStorage.remove(
        _storageKey(_TOKEN_TYPE_KEY, tenantId),
      ),
      _OpenIdConnectSecureStorage.remove(
        _storageKey(_EXPIRES_ON_KEY, tenantId),
      ),
      _OpenIdConnectSecureStorage.remove(_storageKey(_STATE_KEY, tenantId)),
    ]);
  }

  static String _storageKey(String key, String? tenantId) {
    if (tenantId == null || tenantId.isEmpty) return key;
    return '$key-$tenantId';
  }

  /// The `family_name` claim from the ID token, if present.
  String? get familyName => claims["family_name"]?.toString();

  /// The `given_name` claim from the ID token, if present.
  String? get givenName => claims["given_name"]?.toString();

  /// A display-friendly full name derived from the available name claims.
  String? get fullName =>
      claims["name"]?.toString() ??
      (givenName == null ? familyName : "${givenName} ${familyName}");

  /// The preferred user name derived from common username-related claims.
  String? get userName =>
      claims["username"]?.toString() ??
      claims["preferred_username"]?.toString() ??
      claims["sub"]?.toString();

  /// The `email` claim from the ID token, if present.
  String? get email => claims["email"]?.toString();

  /// The `act` claim from the ID token, if present.
  String? get act => claims["act"]?.toString();

  /// Role values extracted from the `role` claim.
  List<String> get roles => claims["role"] == null
      ? List<String>.empty()
      : claims["role"] is String
      ? <String>[claims["role"].toString()]
      : List<String>.from(claims["role"] as Iterable<dynamic>);

  /// The `picture` claim from the ID token, if present.
  String? get picture => claims["picture"]?.toString();

  @override
  operator ==(Object o) {
    if (identical(this, o)) return true;

    return o is OpenIdIdentity &&
        o.accessToken == accessToken &&
        o.idToken == idToken &&
        o.refreshToken == refreshToken &&
        o.state == state &&
        o.tokenType == tokenType &&
        o.claims == claims;
  }

  @override
  int get hashCode =>
      accessToken.hashCode ^
      idToken.hashCode ^
      (refreshToken?.hashCode ?? 0) ^
      (state?.hashCode ?? 0) ^
      tokenType.hashCode ^
      claims.hashCode;
}
