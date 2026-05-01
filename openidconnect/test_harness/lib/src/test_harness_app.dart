import 'package:flutter/material.dart';

import 'harness_controller.dart';
import 'harness_models.dart';

class TestHarnessApp extends StatelessWidget {
  const TestHarnessApp({required this.controller, super.key});

  final HarnessController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenID Connect Test Harness',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: HarnessHomePage(controller: controller),
    );
  }
}

class HarnessHomePage extends StatefulWidget {
  const HarnessHomePage({required this.controller, super.key});

  final HarnessController controller;

  @override
  State<HarnessHomePage> createState() => _HarnessHomePageState();
}

class _HarnessHomePageState extends State<HarnessHomePage> {
  late final TextEditingController _discoveryController;
  late final TextEditingController _clientIdController;
  late final TextEditingController _clientSecretController;
  late final TextEditingController _redirectController;
  late final TextEditingController _scopesController;
  late final TextEditingController _titleController;
  late final TextEditingController _postLogoutRedirectController;

  bool _autoRefresh = false;
  bool _useWebPopup = false;

  @override
  void initState() {
    super.initState();
    _discoveryController = TextEditingController();
    _clientIdController = TextEditingController();
    _clientSecretController = TextEditingController();
    _redirectController = TextEditingController();
    _scopesController = TextEditingController(text: 'openid profile email');
    _titleController = TextEditingController(
      text: 'OpenID Connect Test Harness',
    );
    _postLogoutRedirectController = TextEditingController();
  }

  @override
  void dispose() {
    _discoveryController.dispose();
    _clientIdController.dispose();
    _clientSecretController.dispose();
    _redirectController.dispose();
    _scopesController.dispose();
    _titleController.dispose();
    _postLogoutRedirectController.dispose();
    super.dispose();
  }

  HarnessConfig get _config => HarnessConfig(
    discoveryDocumentUrl: _discoveryController.text,
    clientId: _clientIdController.text,
    clientSecret: _clientSecretController.text,
    redirectUrl: _redirectController.text,
    scopesText: _scopesController.text,
    loginTitle: _titleController.text,
    postLogoutRedirectUrl: _postLogoutRedirectController.text,
    autoRefresh: _autoRefresh,
    useWebPopup: _useWebPopup,
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final snapshot = widget.controller.snapshot;
        return Scaffold(
          appBar: AppBar(title: const Text('OpenID Connect Test Harness')),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Use this harness to point the app at the OpenID Foundation conformance suite or any standards-focused OpenID Provider.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Client configuration',
                    child: Column(
                      children: [
                        _HarnessTextField(
                          key: const Key('discovery-url-field'),
                          controller: _discoveryController,
                          label: 'Discovery document URL',
                          hintText:
                              'https://www.certification.openid.net/test/.../.well-known/openid-configuration',
                        ),
                        _HarnessTextField(
                          key: const Key('client-id-field'),
                          controller: _clientIdController,
                          label: 'Client ID',
                          hintText: 'oidc-client-under-test',
                        ),
                        _HarnessTextField(
                          key: const Key('client-secret-field'),
                          controller: _clientSecretController,
                          label: 'Client secret (optional)',
                          obscureText: true,
                        ),
                        _HarnessTextField(
                          key: const Key('redirect-url-field'),
                          controller: _redirectController,
                          label: 'Redirect URI',
                          hintText:
                              'http://localhost:8080/callback.html or openidconnect.harness://callback',
                        ),
                        _HarnessTextField(
                          key: const Key('post-logout-redirect-url-field'),
                          controller: _postLogoutRedirectController,
                          label: 'Post logout redirect URI (optional)',
                          hintText:
                              'Defaults to the redirect URI when left blank.',
                        ),
                        _HarnessTextField(
                          key: const Key('scopes-field'),
                          controller: _scopesController,
                          label: 'Scopes',
                          hintText: 'openid profile email',
                        ),
                        _HarnessTextField(
                          key: const Key('login-title-field'),
                          controller: _titleController,
                          label: 'Interactive flow title',
                        ),
                        SwitchListTile.adaptive(
                          value: _autoRefresh,
                          title: const Text('Enable auto refresh'),
                          subtitle: const Text(
                            'Leave off for deterministic conformance runs unless the plan explicitly needs refresh behavior.',
                          ),
                          onChanged: (value) =>
                              setState(() => _autoRefresh = value),
                        ),
                        SwitchListTile.adaptive(
                          value: _useWebPopup,
                          title: const Text('Use web popup flow'),
                          subtitle: const Text(
                            'Disable for same-tab redirect loops, which are often easier to drive during conformance testing.',
                          ),
                          onChanged: (value) =>
                              setState(() => _useWebPopup = value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        key: const Key('load-discovery-button'),
                        onPressed: snapshot.busy
                            ? null
                            : () => widget.controller.loadDiscovery(_config),
                        icon: const Icon(Icons.public),
                        label: const Text('Load discovery'),
                      ),
                      FilledButton.icon(
                        key: const Key('initialize-client-button'),
                        onPressed: snapshot.busy
                            ? null
                            : () => widget.controller.initializeClient(_config),
                        icon: const Icon(Icons.build_circle_outlined),
                        label: const Text('Initialize client'),
                      ),
                      FilledButton.icon(
                        key: const Key('login-button'),
                        onPressed: snapshot.busy
                            ? null
                            : () => widget.controller.loginInteractive(
                                _config,
                                context,
                              ),
                        icon: const Icon(Icons.login),
                        label: const Text('Start interactive login'),
                      ),
                      FilledButton.icon(
                        key: const Key('logout-button'),
                        onPressed: snapshot.busy
                            ? null
                            : () => widget.controller.logout(),
                        icon: const Icon(Icons.logout),
                        label: const Text('Local logout'),
                      ),
                      FilledButton.icon(
                        key: const Key('rp-logout-button'),
                        onPressed: snapshot.busy
                            ? null
                            : () => widget.controller.logoutInteractive(
                                _config,
                                context,
                              ),
                        icon: const Icon(Icons.exit_to_app),
                        label: const Text('RP-initiated logout'),
                      ),
                      OutlinedButton.icon(
                        key: const Key('clear-identity-button'),
                        onPressed: snapshot.busy
                            ? null
                            : () => widget.controller.clearIdentity(),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Clear stored identity'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (snapshot.busy)
                    const LinearProgressIndicator(key: Key('busy-indicator')),
                  const SizedBox(height: 16),
                  _StatusPanel(snapshot: snapshot),
                  const SizedBox(height: 16),
                  _DiscoveryPanel(snapshot: snapshot),
                  const SizedBox(height: 16),
                  _IdentityPanel(snapshot: snapshot),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.snapshot});

  final HarnessSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Harness status',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            snapshot.statusMessage,
            key: const Key('status-message'),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          Text('Client ready: ${snapshot.clientReady ? 'yes' : 'no'}'),
          Text(
            'Last event: ${snapshot.lastEvent?.type.name ?? 'none'}${snapshot.lastEvent?.message?.isNotEmpty == true ? ' — ${snapshot.lastEvent!.message}' : ''}',
            key: const Key('last-event'),
          ),
          Text(
            'Last logout redirect: ${snapshot.lastRedirect ?? 'none'}',
            key: const Key('last-redirect'),
          ),
        ],
      ),
    );
  }
}

class _DiscoveryPanel extends StatelessWidget {
  const _DiscoveryPanel({required this.snapshot});

  final HarnessSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final configuration = snapshot.configuration;
    return _SectionCard(
      title: 'Discovery metadata',
      child: configuration == null
          ? const Text('Load discovery to inspect the issuer and endpoints.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Issuer: ${configuration.issuer}',
                  key: const Key('issuer-text'),
                ),
                Text(
                  'Authorization endpoint: ${configuration.authorizationEndpoint}',
                ),
                Text('Token endpoint: ${configuration.tokenEndpoint}'),
                Text('UserInfo endpoint: ${configuration.userInfoEndpoint}'),
                Text(
                  'End-session endpoint: ${configuration.endSessionEndpoint ?? 'not advertised'}',
                ),
                Text(
                  'Revocation endpoint: ${configuration.revocationEndpoint ?? 'not advertised'}',
                ),
              ],
            ),
    );
  }
}

class _IdentityPanel extends StatelessWidget {
  const _IdentityPanel({required this.snapshot});

  final HarnessSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final identity = snapshot.identity;
    return _SectionCard(
      title: 'Current identity',
      child: identity == null
          ? const Text('No identity is currently stored.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Subject: ${identity.sub}',
                  key: const Key('identity-subject'),
                ),
                Text(
                  'Expires: ${identity.expiresAt.toUtc().toIso8601String()}',
                ),
                Text('Username: ${identity.userName ?? 'n/a'}'),
                Text('Email: ${identity.email ?? 'n/a'}'),
                Text('Access token: ${_truncate(identity.accessToken)}'),
                Text(
                  'Refresh token: ${identity.refreshToken == null ? 'n/a' : _truncate(identity.refreshToken!)}',
                ),
              ],
            ),
    );
  }

  String _truncate(String value) {
    if (value.length <= 24) return value;
    return '${value.substring(0, 12)}…${value.substring(value.length - 8)}';
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _HarnessTextField extends StatelessWidget {
  const _HarnessTextField({
    required this.controller,
    required this.label,
    this.hintText,
    this.obscureText = false,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: label,
          hintText: hintText,
        ),
      ),
    );
  }
}
