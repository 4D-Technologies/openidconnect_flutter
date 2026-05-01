part of '../../openidconnect_platform_interface.dart';

class HttpResponseException implements Exception {
  final String? errorMessage;
  HttpResponseException([this.errorMessage]);

  @override
  String toString() => errorMessage ?? "Unknown";
}
