part of '../../openidconnect.dart';

/// Authentication lifecycle events emitted by [OpenIdConnectClient].
enum AuthEventTypes { Error, Success, LoggingOut, NotLoggedIn, Refresh }

@immutable
/// Represents a single authentication lifecycle event.
class AuthEvent {
  final AuthEventTypes type;
  final String? message;

  /// Creates a new authentication event.
  const AuthEvent(this.type, {this.message});

  @override
  operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthEvent && other.type == type && other.message == message;
  }

  @override
  int get hashCode => type.hashCode ^ (message?.hashCode ?? 0);
}
