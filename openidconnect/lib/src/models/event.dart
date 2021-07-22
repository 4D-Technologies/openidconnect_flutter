part of openidconnect;

enum AuthEventTypes { Error, Success, Logout, NotLoggedIn, Refresh }

@immutable
class AuthEvent {
  final AuthEventTypes type;
  final String? message;
  const AuthEvent(this.type, {this.message});

  @override
  operator ==(Object o) {
    if (identical(this, o)) return true;
    return o is AuthEvent && o.type == type && o.message == message;
  }

  @override
  int get hashCode => type.hashCode ^ (message?.hashCode ?? 0);
}
