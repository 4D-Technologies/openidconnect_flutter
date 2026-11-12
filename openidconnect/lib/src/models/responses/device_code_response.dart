part of '../../../openidconnect.dart';

/// Represents a response from the device authorization endpoint.
class DeviceCodeResponse {
  final String deviceCode;
  final String userCode;
  final String verificationUrl;
  final String verificationUrlComplete;
  final DateTime expiresAt;
  final int pollingInterval;
  final String? qrCodeUrl;

  DeviceCodeResponse._({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUrl,
    required this.expiresAt,
    required this.pollingInterval,
    required this.verificationUrlComplete,
    this.qrCodeUrl,
  });

  /// Creates a [DeviceCodeResponse] from device authorization endpoint JSON.
  factory DeviceCodeResponse.fromJson(Map<String, dynamic> json) {
    final verificationUrl =
        json['verification_uri'] ?? json['verification_url'];
    final verificationUrlComplete =
        json['verification_uri_complete'] ?? json['verification_url_complete'];
    final expiresIn = json['expires_in'];
    final interval = json['interval'] ?? 5;

    return DeviceCodeResponse._(
      deviceCode: json['device_code'].toString(),
      userCode: json['user_code'].toString(),
      verificationUrl: verificationUrl.toString(),
      expiresAt: DateTime.now().add(
        Duration(seconds: (expiresIn as num).toInt()),
      ),
      pollingInterval: (interval as num).toInt(),
      verificationUrlComplete: verificationUrlComplete.toString(),
      qrCodeUrl: json['qr_code']?.toString(),
    );
  }
}
