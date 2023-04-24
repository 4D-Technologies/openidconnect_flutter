import 'package:json_annotation/json_annotation.dart';
import 'package:openidconnect_dart/src/models/json_with_original.dart';

class TokenResponse extends JsonObjectWithOriginal {
  @JsonKey(name: 'token_type')
  final String tokenType;
  @JsonKey(name: 'expires_in', fromJson: durationFromSeconds)
  final Duration? expiresIn;

  const TokenResponse({
    required super.src,
    required this.tokenType,
    required this.expiresIn,
  });
}
