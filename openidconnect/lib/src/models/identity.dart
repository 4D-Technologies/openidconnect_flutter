part of openidconnect;

class OpenIdIdentity extends AuthorizationResponse {
  static const String _AUTHENTICATION_TOKEN_KEY = "ACCESS_TOKEN";
  static const String _ID_TOKEN_KEY = "ID_TOKEN";
  static const String _REFRESH_TOKEN_KEY = "REFRESH_TOKEN";
  static const String _TOKEN_TYPE_KEY = "TOKEN_TYPE";
  static const String _EXPIRES_ON_KEY = "EXPIRES_ON";
  static const String _STATE_KEY = "STATE";

  late Map<String, dynamic> claims;
  late String sub;

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
    this.claims = JwtDecoder.decode(idToken);

    this.sub = claims["sub"].toString();
  }

  factory OpenIdIdentity.fromAuthorizationResponse(
          AuthorizationResponse response) =>
      OpenIdIdentity(
        accessToken: response.accessToken,
        expiresAt: response.expiresAt,
        idToken: response.idToken,
        tokenType: response.tokenType,
        refreshToken: response.refreshToken,
        state: response.state,
      );

  static final _storage = EncryptedSharedPreferences.getInstance();

  static Future<OpenIdIdentity?> load() async {
    try {
      late String? accessToken;
      late String? refreshToken;
      late int expiresOn;
      late String tokenType;
      late String? idToken;
      late String? state;

      accessToken = _storage.getString(_AUTHENTICATION_TOKEN_KEY);
      idToken = _storage.getString(_ID_TOKEN_KEY);
      expiresOn = _storage.getInt(_EXPIRES_ON_KEY) ?? 0;
      tokenType = _storage.getString(_TOKEN_TYPE_KEY) ?? "bearer";
      state = _storage.getString(_STATE_KEY);
      refreshToken = _storage.getString(_REFRESH_TOKEN_KEY);

      if (accessToken == null || idToken == null) return null;

      return OpenIdIdentity(
        accessToken: accessToken,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresOn),
        idToken: idToken,
        tokenType: tokenType,
        refreshToken: refreshToken,
        state: state,
      );
    } on Exception catch (e) {
      print(e.toString());
      try {
        clear();
      } on Exception {}
      return null; //Invalid values, flush.
    }
  }

  Future<void> save() async {
    _storage.setString(_AUTHENTICATION_TOKEN_KEY, this.accessToken);

    _storage.setString(_ID_TOKEN_KEY, this.idToken);
    this.refreshToken == null
        ? _storage.remove(_REFRESH_TOKEN_KEY)
        : _storage.setString(_REFRESH_TOKEN_KEY, this.refreshToken);

    _storage.setString(_TOKEN_TYPE_KEY, this.tokenType);
    _storage.setInt(_EXPIRES_ON_KEY, this.expiresAt.millisecondsSinceEpoch);
    this.state == null
        ? _storage.remove(_STATE_KEY)
        : _storage.setString(_STATE_KEY, this.state);
  }

  static Future<void> clear() async {
    await Future.wait([
      _storage.remove(_AUTHENTICATION_TOKEN_KEY),
      _storage.remove(_ID_TOKEN_KEY),
      _storage.remove(_REFRESH_TOKEN_KEY),
      _storage.remove(_TOKEN_TYPE_KEY),
      _storage.remove(_EXPIRES_ON_KEY),
      _storage.remove(_STATE_KEY)
    ]);
  }

  String? get familyName => claims["family_name"]?.toString();
  String? get givenName => claims["given_name"]?.toString();
  String? get fullName =>
      claims["name"]?.toString() ??
      (givenName == null ? familyName : "${givenName} ${familyName}");
  String? get userName =>
      claims["preferred_username"]?.toString() ?? claims["sub"]?.toString();
  String? get email => claims["email"]?.toString();
  String? get act => claims["act"]?.toString();
  List<String> get roles => claims["role"] == null
      ? List<String>.empty()
      : claims["role"] is String
          ? <String>[claims["role"].toString()]
          : List<String>.from(claims["role"] as Iterable<dynamic>);

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
