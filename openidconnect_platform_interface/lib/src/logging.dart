part of '../openidconnect_platform_interface.dart';

/// Shared logger for the federated OpenIdConnect packages.
///
/// Host apps may replace this instance to integrate with their own logging
/// pipeline. The default uses [ProductionFilter] so error logs remain visible
/// in release builds.
///
/// Calls use only the `message` argument of [Logger.e]/[Logger.w]/[Logger.i]
/// so both `logger` 1.x and 2.x remain compatible for host apps.
Logger openIdConnectLogger = Logger(filter: ProductionFilter());

/// Logs [error] at error level without using logger 2.x-only named arguments.
void logOpenIdConnectError(
  String message,
  Object error, [
  StackTrace? stackTrace,
]) {
  final buffer = StringBuffer(message)
    ..write(': ')
    ..write(error);
  if (stackTrace != null) {
    buffer
      ..write('\n')
      ..write(stackTrace);
  }
  openIdConnectLogger.e(buffer.toString());
}

/// Logs [error] at warning level without using logger 2.x-only named arguments.
void logOpenIdConnectWarning(
  String message, [
  Object? error,
  StackTrace? stackTrace,
]) {
  final buffer = StringBuffer(message);
  if (error != null) {
    buffer
      ..write(': ')
      ..write(error);
  }
  if (stackTrace != null) {
    buffer
      ..write('\n')
      ..write(stackTrace);
  }
  openIdConnectLogger.w(buffer.toString());
}
