import 'package:json_annotation/json_annotation.dart';
import 'package:openidconnect_dart/src/models/json_with_original.dart';

part 'device_code_response.g.dart';

///OAuth 2.0 Device Authorization Grant: https://www.rfc-editor.org/rfc/rfc8628#section-3.2
@JsonSerializable(createToJson: false)
class DeviceCodeResponse extends JsonObjectWithOriginal {
  @JsonKey(name: 'device_code')
  final String deviceCode;
  @JsonKey(name: 'user_code')
  final String userCode;
  @JsonKey(name: 'verification_uri')
  final String verificationUri;
  @JsonKey(name: 'verification_uri_complete')
  final String? verificationUriComplete;
  @JsonKey(name: 'expires_in', fromJson: requiredDurationFromSeconds)
  final Duration expiresIn;
  @JsonKey(name: 'interval')
  final int pollingInterval;

  const DeviceCodeResponse({
    required super.src,
    required this.expiresIn,
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    this.pollingInterval = 5,
    this.verificationUriComplete,
  });

  factory DeviceCodeResponse.fromJson(Map<String, dynamic> json) =>
      _$DeviceCodeResponseFromJson(json);
}
