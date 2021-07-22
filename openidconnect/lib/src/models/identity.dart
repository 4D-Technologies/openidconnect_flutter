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
    final idParts = idToken.split(".");
    if (idParts.length != 3) throw Exception("invalid_token");

    this.claims = jsonDecode(
      _decodeBase64(idParts[1]),
    ) as Map<String, dynamic>;

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

  static Future<OpenIdIdentity> load() async {
    if (kIsWeb) {
      final storage = await SharedPreferences.getInstance();
      return OpenIdIdentity(
        accessToken: storage.getString(_AUTHENTICATION_TOKEN_KEY)!,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(
          storage.getInt(_EXPIRES_ON_KEY) ?? 0,
        ),
        idToken: storage.getString(_ID_TOKEN_KEY)!,
        refreshToken: storage.getString(_REFRESH_TOKEN_KEY),
        tokenType: storage.getString(_TOKEN_TYPE_KEY) ?? "Bearer",
        state: storage.getString(_STATE_KEY),
      );
    } else {
      final storage = FlutterSecureStorage();

      return OpenIdIdentity(
        accessToken: (await storage.read(key: _AUTHENTICATION_TOKEN_KEY))!,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(
          int.parse((await storage.read(key: _EXPIRES_ON_KEY)) ?? "0"),
        ),
        idToken: (await storage.read(key: _ID_TOKEN_KEY))!,
        tokenType: await storage.read(key: _TOKEN_TYPE_KEY) ?? "Bearer",
        refreshToken: await storage.read(key: _REFRESH_TOKEN_KEY),
        state: await storage.read(key: _STATE_KEY),
      );
    }
  }

  Future<void> save() async {
    if (kIsWeb) {
      final storage = await SharedPreferences.getInstance();
      await storage.setString(_AUTHENTICATION_TOKEN_KEY, this.accessToken);
      await storage.setString(_ID_TOKEN_KEY, this.idToken);
      await storage.setString(_TOKEN_TYPE_KEY, this.tokenType);
      if (this.refreshToken != null) {
        await storage.setString(_REFRESH_TOKEN_KEY, this.refreshToken!);
      } else {
        await storage.remove(_REFRESH_TOKEN_KEY);
      }
      await storage.setInt(
          _EXPIRES_ON_KEY, this.expiresAt.millisecondsSinceEpoch);
      if (this.state != null) {
        await storage.setString(_STATE_KEY, this.state!);
      } else {
        await storage.remove(_STATE_KEY);
      }
    } else {
      final storage = FlutterSecureStorage();
      await Future.wait([
        storage.write(key: _AUTHENTICATION_TOKEN_KEY, value: this.accessToken),
        storage.write(key: _ID_TOKEN_KEY, value: this.idToken),
        this.refreshToken == null
            ? storage.delete(key: _REFRESH_TOKEN_KEY)
            : storage.write(key: _REFRESH_TOKEN_KEY, value: this.refreshToken),
        storage.write(key: _TOKEN_TYPE_KEY, value: this.tokenType),
        storage.write(
            key: _EXPIRES_ON_KEY,
            value: this.expiresAt.millisecondsSinceEpoch.toString()),
        this.state == null
            ? storage.delete(key: _STATE_KEY)
            : storage.write(key: _STATE_KEY, value: this.state)
      ]);
    }
  }

  Future<void> clear() async {
    if (kIsWeb) {
      final storage = await SharedPreferences.getInstance();
      await storage.remove(_AUTHENTICATION_TOKEN_KEY);
      await storage.remove(_ID_TOKEN_KEY);
      await storage.remove(_TOKEN_TYPE_KEY);
      await storage.remove(_EXPIRES_ON_KEY);
      await storage.remove(_STATE_KEY);
    } else {
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
  }

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

  static String _decodeBase64(String str) {
    //'-', '+' 62nd char of encoding,  '_', '/' 63rd char of encoding
    String output = str.replaceAll('-', '+').replaceAll('_', '/');
    switch (output.length % 4) {
      // Pad with trailing '='
      case 0: // No pad chars in this case
        break;
      case 2: // Two pad chars
        output += '==';
        break;
      case 3: // One pad char
        output += '=';
        break;
      default:
        throw Exception('Illegal base64url string!"');
    }

    return utf8.decode(base64Url.decode(output));
  }
}
