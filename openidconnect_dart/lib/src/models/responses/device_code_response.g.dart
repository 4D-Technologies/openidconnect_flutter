// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_code_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeviceCodeResponse _$DeviceCodeResponseFromJson(Map<String, dynamic> json) =>
    DeviceCodeResponse(
      src: readSelf(json, '') as Map<String, dynamic>,
      expiresIn: requiredDurationFromSeconds(json['expires_in'] as int),
      deviceCode: json['device_code'] as String,
      userCode: json['user_code'] as String,
      verificationUri: json['verification_uri'] as String,
      pollingInterval: json['interval'] as int? ?? 5,
      verificationUriComplete: json['verification_uri_complete'] as String?,
    );
