// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'access_token.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AccessTokenResponse _$AccessTokenResponseFromJson(Map<String, dynamic> json) =>
    AccessTokenResponse(
      src: readSelf(json, '') as Map<String, dynamic>,
      tokenType: json['token_type'] as String,
      expiresIn: durationFromSeconds(json['expires_in'] as int?),
      accessToken: json['access_token'] as String,
      idToken: json['id_token'] as String,
      refreshToken: json['refresh_token'] as String?,
      scope: json['scope'] as String?,
    );
