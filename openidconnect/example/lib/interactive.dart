import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openidconnect/openidconnect.dart';

import 'credentials.dart';
import 'idp_catalog.dart';

import 'identity_view.dart';

class InteractivePage extends StatefulWidget {
  const InteractivePage({super.key});

  @override
  State<InteractivePage> createState() => _InteractivePageState();
}

class _InteractivePageState extends State<InteractivePage> {
  final _formKey = GlobalKey<FormState>();

  late IdpProfile profile;
  late String discoveryUrl;
  OpenIdConfiguration? discoveryDocument;
  OpenIdConnectClient? client;
  AuthorizationResponse? identity;
  bool usePopup = true;
  bool _loadedProfile = false;

  String? errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedProfile) return;
    _loadedProfile = true;
    profile = IdpCatalog.of(context).selected;
    discoveryUrl = profile.discoveryUrl;
  }

  Future<void> lookupSettings() async {
    _formKey.currentState!.save();
    if (!_formKey.currentState!.validate()) return;

    try {
      final configuration = await OpenIdConnect.getConfiguration(discoveryUrl);
      client = await createExampleClient(profile: profile);
      setState(() {
        discoveryDocument = configuration;
        errorMessage = null;
      });
    } on Exception catch (e) {
      setState(() {
        errorMessage = e.toString();
        discoveryDocument = null;
      });
    }
  }

  Future<void> authorize() async {
    try {
      if (client == null) return;

      final response = await client!.loginInteractive(
        context: context,
        title: 'Login',
        userNameHint: profile.usernameHint,
        useWebPopup: usePopup,
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
      appBar: AppBar(
        title: const Text('OpenIdConnect Code Flow with PKCE Example'),
      ),
      body: Center(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            children: [
              TextFormField(
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: 'Discovery Url'),
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
              Visibility(
                visible: kIsWeb,
                child: SwitchListTile.adaptive(
                  value: usePopup,
                  title: const Text('Use Web Popup'),
                  onChanged: (value) {
                    setState(() {
                      usePopup = value;
                    });
                  },
                ),
              ),
              Visibility(
                visible: discoveryDocument != null,
                child: TextButton.icon(
                  onPressed: authorize,
                  icon: const Icon(Icons.login),
                  label: const Text('Login'),
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
      ),
    );
  }
}
