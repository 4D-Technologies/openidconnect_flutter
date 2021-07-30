part of openidconnect;

class OpenIdIdentity extends AuthorizationResponse {
  static const String _AUTHENTICATION_TOKEN_KEY = "ACCESS_TOKEN";
  static const String _ID_TOKEN_KEY = "ID_TOKEN";
  static const String _REFRESH_TOKEN_KEY = "REFRESH_TOKEN";
  static const String _TOKEN_TYPE_KEY = "TOKEN_TYPE";
  static const String _EXPIRES_ON_KEY = "EXPIRES_ON";
  static const String _STATE_KEY = "STATE";

  final String? state;
  late Map<String, dynamic> claims;
  late String sub;

  OpenIdIdentity({
    required String accessToken,
    required DateTime expiresAt,
    required String idToken,
    required String tokenType,
    String? refreshToken,
    this.state,
  }) : super(
          expiresAt: expiresAt,
          tokenType: tokenType,
          accessToken: accessToken,
          idToken: idToken,
          refreshToken: refreshToken,
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

  static Future<OpenIdIdentity?> load() async {
    try {
      final storage = FlutterSecureStorage();

      late String? accessToken;
      late String? refreshToken;
      late String expiresOn;
      late String tokenType;
      late String? idToken;
      late String? state;

      await Future.wait([
        storage
            .read(key: _AUTHENTICATION_TOKEN_KEY)
            .then((value) => accessToken = value),
        storage
            .read(key: _EXPIRES_ON_KEY)
            .then((value) => expiresOn = value ?? "0"),
        storage.read(key: _ID_TOKEN_KEY).then((value) => idToken = value),
        storage
            .read(key: _TOKEN_TYPE_KEY)
            .then((value) => tokenType = value ?? "bearer"),
        storage
            .read(key: _REFRESH_TOKEN_KEY)
            .then((value) => refreshToken = value),
        storage.read(key: _STATE_KEY).then((value) => state = value),
      ]);

      if (accessToken == null || idToken == null) return null;

      return OpenIdIdentity(
        accessToken: accessToken!,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(
          int.parse(expiresOn),
        ),
        idToken: idToken!,
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
    final storage = FlutterSecureStorage();
    await storage.write(
        key: _AUTHENTICATION_TOKEN_KEY, value: this.accessToken);

    await storage.write(key: _ID_TOKEN_KEY, value: this.idToken);
    await this.refreshToken == null
        ? storage.delete(key: _REFRESH_TOKEN_KEY)
        : storage.write(key: _REFRESH_TOKEN_KEY, value: this.refreshToken);

    await storage.write(key: _TOKEN_TYPE_KEY, value: this.tokenType);
    await storage.write(
        key: _EXPIRES_ON_KEY,
        value: this.expiresAt.millisecondsSinceEpoch.toString());
    await this.state == null
        ? storage.delete(key: _STATE_KEY)
        : storage.write(key: _STATE_KEY, value: this.state);
  }

  static Future<void> clear() async {
    final storage = FlutterSecureStorage();
    await Future.wait([
      storage.delete(key: _AUTHENTICATION_TOKEN_KEY),
      storage.delete(key: _ID_TOKEN_KEY),
      storage.delete(key: _REFRESH_TOKEN_KEY),
      storage.delete(key: _TOKEN_TYPE_KEY),
      storage.delete(key: _EXPIRES_ON_KEY),
      storage.delete(key: _STATE_KEY)
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
