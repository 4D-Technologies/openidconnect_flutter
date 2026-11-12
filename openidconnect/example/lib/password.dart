import 'package:material_ui/material_ui.dart';
import 'package:openidconnect/openidconnect.dart';

import 'identity_view.dart';
import 'credentials.dart';
import 'idp_catalog.dart';

class PasswordPage extends StatefulWidget {
  const PasswordPage({super.key});

  @override
  State<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends State<PasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _userFormKey = GlobalKey<FormState>();

  OpenIdConnectClient? client;
  late IdpProfile profile;
  late String discoveryUrl;
  OpenIdConfiguration? discoveryDocument;
  bool _loadedProfile = false;

  late String userName;
  late String password;
  AuthorizationResponse? identity;

  String? errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedProfile) return;
    _loadedProfile = true;
    profile = IdpCatalog.of(context).selected;
    discoveryUrl = profile.discoveryUrl;
    userName = profile.usernameHint ?? '';
    password = profile.passwordHint ?? '';
  }

  Future<void> lookupSettings() async {
    _formKey.currentState!.save();
    if (!_formKey.currentState!.validate()) return;

    try {
      final configuration = await OpenIdConnect.getConfiguration(discoveryUrl);
      client = await createExampleClient(
        profile: profile,
        clientId: profile.resolvedPasswordClientId,
        clientSecret: profile.resolvedPasswordClientSecret,
      );
      setState(() {
        discoveryDocument = configuration;
        errorMessage = profile.supportsPassword
            ? null
            : 'This IdP profile does not advertise password grant. '
                  'You can still try it, or add an IdP whose client allows '
                  'grant_type=password.';
      });
    } on Exception catch (e) {
      setState(() {
        errorMessage = e.toString();
        discoveryDocument = null;
      });
    }
  }

  Future<void> authorize() async {
    if (client == null) return;
    _userFormKey.currentState!.save();
    if (!_userFormKey.currentState!.validate()) return;

    try {
      final response = await client!.loginWithPassword(
        userName: userName,
        password: password,
      );

      setState(() {
        identity = response;
        errorMessage = null;
      });
    } on Exception catch (e) {
      setState(() {
        errorMessage = e.toString();
        identity = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OpenIdConnect Password Flow Example')),
      body: Center(
        child: Column(
          children: [
            Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                children: [
                  TextFormField(
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Discovery Url',
                    ),
                    keyboardType: TextInputType.url,
                    initialValue: discoveryUrl,
                    onChanged: (value) => discoveryUrl = value,
                    validator: (value) {
                      const errorMessage =
                          'Please enter a valid openid discovery document url';
                      if (value == null || value.isEmpty) return errorMessage;
                      try {
                        Uri.parse(value);
                        return null;
                      } on Exception {
                        return errorMessage;
                      }
                    },
                  ),
                  TextButton.icon(
                    onPressed: lookupSettings,
                    icon: const Icon(Icons.search),
                    label: const Text('Lookup OpenId Connect Configuration'),
                  ),
                ],
              ),
            ),
            Visibility(
              visible: discoveryDocument != null,
              child: Form(
                key: _userFormKey,
                child: Column(
                  children: [
                    TextFormField(
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'User Name'),
                      keyboardType: TextInputType.emailAddress,
                      initialValue: userName,
                      onChanged: (value) => userName = value,
                      validator: (value) {
                        const errorMessage = 'Please enter a valid user name';
                        if (value == null || value.isEmpty) {
                          return errorMessage;
                        }

                        return null;
                      },
                    ),
                    TextFormField(
                      textInputAction: TextInputAction.go,
                      decoration: const InputDecoration(labelText: 'Password'),
                      keyboardType: TextInputType.visiblePassword,
                      initialValue: password,
                      onChanged: (value) => password = value,
                      validator: (value) {
                        const errorMessage = 'Please enter a valid password';
                        if (value == null || value.isEmpty) {
                          return errorMessage;
                        }

                        return null;
                      },
                    ),
                    TextButton.icon(
                      onPressed: authorize,
                      icon: const Icon(Icons.login),
                      label: const Text('Login'),
                    ),
                    Visibility(
                      visible: errorMessage != null,
                      child: Text(
                        errorMessage ?? '',
                        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Visibility(
              visible: identity != null,
              child: identity == null ? Container() : IdentityView(identity!),
            ),
            Visibility(
              visible: identity != null,
              child: TextButton.icon(
                onPressed: () async {
                  OpenIdConnect.logout(
                    request: LogoutRequest(
                      idToken: identity!.idToken,
                      configuration: discoveryDocument!,
                    ),
                  );
                  setState(() {
                    identity = null;
                  });
                },
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
