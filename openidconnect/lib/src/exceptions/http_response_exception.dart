part of openidconnect;

class HttpResponseException implements Exception {
  final String? errorMessage;
  HttpResponseException([this.errorMessage]);

  @override
  String toString() => errorMessage ?? "Unknown";
}
