part of '../../openidconnect.dart';

/// Outcome of a client logout attempt.
enum LogoutStatus {
  /// No identity snapshot was available, so logout was a no-op.
  skipped,

  /// Remote logout/revocation succeeded or was correctly skipped, and local
  /// identity for that session was cleared when it was still present.
  success,

  /// Remote logout or token revocation failed after a real revoke attempt.
  /// Local identity for that session is still cleared when it was present.
  remoteFailure,
}

/// Result returned by [OpenIdConnectClient.logout] and
/// [OpenIdConnectClient.logoutInteractive].
///
/// Local identity is cleared when it still belongs to the session being
/// logged out. [status] and [message] report whether remote
/// logout/revocation also succeeded. RFC 7009 `unsupported_token_type` is
/// reported as [LogoutStatus.success].
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
