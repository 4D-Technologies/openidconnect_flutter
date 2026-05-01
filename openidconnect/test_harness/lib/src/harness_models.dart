import 'package:openidconnect/openidconnect.dart';

class HarnessConfig {
  const HarnessConfig({
    required this.discoveryDocumentUrl,
    required this.clientId,
    required this.clientSecret,
    required this.redirectUrl,
    required this.scopesText,
    required this.loginTitle,
    required this.postLogoutRedirectUrl,
    required this.autoRefresh,
    required this.useWebPopup,
  });

  final String discoveryDocumentUrl;
  final String clientId;
  final String clientSecret;
  final String redirectUrl;
  final String scopesText;
  final String loginTitle;
  final String postLogoutRedirectUrl;
  final bool autoRefresh;
  final bool useWebPopup;

  String get trimmedDiscoveryDocumentUrl => discoveryDocumentUrl.trim();
  String get trimmedClientId => clientId.trim();
  String? get trimmedClientSecret {
    final value = clientSecret.trim();
    return value.isEmpty ? null : value;
  }

  String? get trimmedRedirectUrl {
    final value = redirectUrl.trim();
    return value.isEmpty ? null : value;
  }

  String get effectiveLoginTitle {
    final value = loginTitle.trim();
    return value.isEmpty ? 'OpenID Connect Test Harness' : value;
  }

  String? get effectivePostLogoutRedirectUrl {
    final logoutValue = postLogoutRedirectUrl.trim();
    if (logoutValue.isNotEmpty) return logoutValue;
    return trimmedRedirectUrl;
  }

  List<String> get scopes {
    final values = scopesText
        .split(RegExp(r'[\s,]+'))
        .map((scope) => scope.trim())
        .where((scope) => scope.isNotEmpty)
        .toList(growable: false);

    return values.isEmpty ? const ['openid'] : values;
  }

  HarnessConfig copyWith({
    String? discoveryDocumentUrl,
    String? clientId,
    String? clientSecret,
    String? redirectUrl,
    String? scopesText,
    String? loginTitle,
    String? postLogoutRedirectUrl,
    bool? autoRefresh,
    bool? useWebPopup,
  }) {
    return HarnessConfig(
      discoveryDocumentUrl: discoveryDocumentUrl ?? this.discoveryDocumentUrl,
      clientId: clientId ?? this.clientId,
      clientSecret: clientSecret ?? this.clientSecret,
      redirectUrl: redirectUrl ?? this.redirectUrl,
      scopesText: scopesText ?? this.scopesText,
      loginTitle: loginTitle ?? this.loginTitle,
      postLogoutRedirectUrl:
          postLogoutRedirectUrl ?? this.postLogoutRedirectUrl,
      autoRefresh: autoRefresh ?? this.autoRefresh,
      useWebPopup: useWebPopup ?? this.useWebPopup,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is HarnessConfig &&
            other.discoveryDocumentUrl == discoveryDocumentUrl &&
            other.clientId == clientId &&
            other.clientSecret == clientSecret &&
            other.redirectUrl == redirectUrl &&
            other.scopesText == scopesText &&
            other.loginTitle == loginTitle &&
            other.postLogoutRedirectUrl == postLogoutRedirectUrl &&
            other.autoRefresh == autoRefresh &&
            other.useWebPopup == useWebPopup;
  }

  @override
  int get hashCode =>
      discoveryDocumentUrl.hashCode ^
      clientId.hashCode ^
      clientSecret.hashCode ^
      redirectUrl.hashCode ^
      scopesText.hashCode ^
      loginTitle.hashCode ^
      postLogoutRedirectUrl.hashCode ^
      autoRefresh.hashCode ^
      useWebPopup.hashCode;
}

class HarnessSnapshot {
  const HarnessSnapshot({
    this.configuration,
    this.identity,
    this.lastEvent,
    this.statusMessage = 'Ready to load discovery metadata.',
    this.lastRedirect,
    this.busy = false,
    this.clientReady = false,
  });

  final OpenIdConfiguration? configuration;
  final OpenIdIdentity? identity;
  final AuthEvent? lastEvent;
  final String statusMessage;
  final String? lastRedirect;
  final bool busy;
  final bool clientReady;

  HarnessSnapshot copyWith({
    OpenIdConfiguration? configuration,
    OpenIdIdentity? identity,
    AuthEvent? lastEvent,
    String? statusMessage,
    String? lastRedirect,
    bool? busy,
    bool? clientReady,
    bool clearIdentity = false,
    bool clearLastEvent = false,
    bool clearLastRedirect = false,
  }) {
    return HarnessSnapshot(
      configuration: configuration ?? this.configuration,
      identity: clearIdentity ? null : (identity ?? this.identity),
      lastEvent: clearLastEvent ? null : (lastEvent ?? this.lastEvent),
      statusMessage: statusMessage ?? this.statusMessage,
      lastRedirect: clearLastRedirect
          ? null
          : (lastRedirect ?? this.lastRedirect),
      busy: busy ?? this.busy,
      clientReady: clientReady ?? this.clientReady,
    );
  }
}
