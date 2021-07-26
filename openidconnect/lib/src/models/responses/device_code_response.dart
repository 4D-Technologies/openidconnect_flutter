part of openidconnect;

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

  factory DeviceCodeResponse.fromJson(Map<String, dynamic> json) =>
      DeviceCodeResponse._(
        deviceCode: json["device_code"].toString(),
        userCode: json["user_code"].toString(),
        verificationUrl: json["verification_url"].toString(),
        expiresAt:
            DateTime.now().add(Duration(seconds: json["expires_in"] as int)),
        pollingInterval: (json["interval"] ?? 5) as int,
        verificationUrlComplete: json["verification_uri_complete"].toString(),
        qrCodeUrl: json['qr_code']?.toString(),
      );
}
