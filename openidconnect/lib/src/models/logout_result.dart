part of '../../openidconnect.dart';

/// Outcome of a client logout attempt.
enum LogoutStatus {
  /// No persisted identity was present, so logout was a no-op.
  skipped,

  /// Local identity was cleared and remote logout/revocation succeeded.
  success,

  /// Local identity was cleared, but remote logout or token revocation failed.
  remoteFailure,
}

/// Result returned by [OpenIdConnectClient.logout] and
/// [OpenIdConnectClient.logoutInteractive].
///
/// Local identity is always cleared when one was present. [status] and
/// [message] report whether remote logout/revocation also succeeded.
@immutable
class LogoutResult {
  /// Creates a logout result.
  const LogoutResult({
    required this.status,
    required this.message,
    this.redirectUrl,
  });

  /// Whether remote logout/revocation succeeded after local cleanup.
  final LogoutStatus status;

  /// Human-readable status details suitable for logs or UI.
  final String message;

  /// Post-logout redirect URL from RP-initiated logout, if any.
  final String? redirectUrl;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LogoutResult &&
        other.status == status &&
        other.message == message &&
        other.redirectUrl == redirectUrl;
  }

  @override
  int get hashCode => Object.hash(status, message, redirectUrl);
}
