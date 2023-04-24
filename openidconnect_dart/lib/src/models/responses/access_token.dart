import 'package:json_annotation/json_annotation.dart';

import '../json_with_original.dart';
import 'token_response.dart';
part 'access_token.g.dart';

///The OAuth 2.0 Authorization Framework: https://datatracker.ietf.org/doc/html/rfc6749#section-5.1
@JsonSerializable(createToJson: false)
class AccessTokenResponse extends TokenResponse {
  @JsonKey(name: 'access_token')
  final String accessToken;
  @JsonKey(name: 'refresh_token')
  final String? refreshToken;
  @JsonKey(name: 'id_token')
  final String idToken;
  @JsonKey(name: 'scope')
  final String? scope;

  const AccessTokenResponse({
    required super.src,
    required super.tokenType,
    super.expiresIn,
    required this.accessToken,
    required this.idToken,
    this.refreshToken,
    this.scope,
  });

  factory AccessTokenResponse.fromJson(Map<String, dynamic> json) =>
      _$AccessTokenResponseFromJson(json);
}
