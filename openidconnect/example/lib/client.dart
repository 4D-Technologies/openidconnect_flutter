import 'package:material_ui/material_ui.dart';
import 'package:openidconnect/openidconnect.dart';

import 'credentials.dart';
import 'identity_view.dart';
import 'idp_catalog.dart';

class ClientPage extends StatefulWidget {
  const ClientPage({super.key});

  @override
  State<ClientPage> createState() => _ClientPageState();
}

class _ClientPageState extends State<ClientPage> {
  late IdpProfile profile;
  OpenIdConnectClient? client;
  OpenIdIdentity? identity;
  String? errorMessage;
  bool _loadedProfile = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedProfile) return;
    _loadedProfile = true;
    profile = IdpCatalog.of(context).selected;
  }

  Future<void> _createClient() async {
    try {
      client = await createExampleClient(profile: profile);
      setState(() {
        identity = client?.identity;
        errorMessage = null;
      });
    } on Exception catch (e) {
      setState(() {
        errorMessage = e.toString();
        client = null;
      });
    }
  }

  Future<void> _login() async {
    if (client == null) return;
    try {
      final result = await client!.loginInteractive(
        context: context,
        title: 'Login',
        userNameHint: profile.usernameHint,
      );
      setState(() {
        identity = result;
        errorMessage = null;
      });
    } on Exception catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    }
  }

  Future<void> _refresh() async {
    if (client == null) return;
    try {
      await client!.refresh();
      setState(() {
        identity = client!.identity;
        errorMessage = null;
      });
    } on Exception catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    }
  }

  Future<void> _logout() async {
    if (client == null) return;
    try {
      await client!.logout();
      setState(() {
        identity = client!.identity;
        errorMessage = null;
      });
    } on Exception catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OpenIdConnectClient Example')),
      body: Center(
        child: Column(
          children: [
            Text(profile.name),
            TextButton.icon(
              onPressed: _createClient,
              icon: const Icon(Icons.search),
              label: const Text('Create client'),
            ),
            Visibility(
              visible: client != null,
              child: TextButton.icon(
                onPressed: _login,
                icon: const Icon(Icons.login),
                label: const Text('Login'),
              ),
            ),
            Visibility(
              visible: identity != null,
              child: TextButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ),
            Visibility(
              visible: identity != null,
              child: identity == null ? Container() : IdentityView(identity!),
            ),
            Visibility(
              visible: errorMessage != null,
              child: SelectableText(errorMessage ?? ''),
            ),
            Visibility(
              visible: identity != null,
              child: TextButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
