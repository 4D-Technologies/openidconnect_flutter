import 'package:flutter/material.dart';
import 'package:openidconnect/openidconnect.dart';

import 'identity_view.dart';
import 'credentials.dart';

class PasswordPage extends StatefulWidget {
  @override
  _PasswordPageState createState() => _PasswordPageState();
}

class _PasswordPageState extends State<PasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _userFormKey = GlobalKey<FormState>();

  OpenIdConnectClient? client;
  String discoveryUrl = defaultDiscoveryUrl;
  OpenIdConfiguration? discoveryDocument;

  String userName = "";
  String password = "";
  AuthorizationResponse? identity;

  String? errorMessage = null;

  Future<void> lookupSettings() async {
    _formKey.currentState!.save();
    if (!_formKey.currentState!.validate()) return;

    try {
      final configuration = await OpenIdConnect.getConfiguration(discoveryUrl);
      client = await OpenIdConnectClient.create(
        clientId: defaultClientId,
        discoveryDocumentUrl: discoveryUrl,
        scopes: defaultscopes,
        audiences: defaultAudience,
        clientSecret: defaultClientSecret,
        redirectUrl: defaultRedirectUrl,
        webUseRefreshTokens: true,
        autoRefresh: true,
        encryptionKey: defaultEncryptionKey,
      );
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
    if (client == null) return;
    _userFormKey.currentState!.save();
    if (!_userFormKey.currentState!.validate()) return;

    try {
      final response = await client!
          .loginWithPassword(userName: userName, password: password);

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
        title: const Text('OpenIdConnect Password Flow Example'),
      ),
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
                    decoration: InputDecoration(labelText: "Discovery Url"),
                    keyboardType: TextInputType.url,
                    initialValue: discoveryUrl,
                    onChanged: (value) => discoveryUrl = value,
                    validator: (value) {
                      const errorMessage =
                          "Please enter a valid openid discovery document url";
                      if (value == null || value.isEmpty) return errorMessage;
                      try {
                        Uri.parse(value);
                        return null;
                      } on Exception catch (e) {
                        print(e.toString());
                        return errorMessage;
                      }
                    },
                  ),
                  TextButton.icon(
                    onPressed: lookupSettings,
                    icon: Icon(Icons.search),
                    label: Text("Lookup OpenId Connect Configuration"),
                  ),
                ],
              ),
            ),
            Visibility(
              child: Form(
                key: _userFormKey,
                child: Column(
                  children: [
                    TextFormField(
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(labelText: "User Name"),
                      keyboardType: TextInputType.emailAddress,
                      initialValue: userName,
                      onChanged: (value) => userName = value,
                      validator: (value) {
                        const errorMessage = "Please enter a valid user name";
                        if (value == null || value.isEmpty) return errorMessage;

                        return null;
                      },
                    ),
                    TextFormField(
                      textInputAction: TextInputAction.go,
                      decoration: InputDecoration(labelText: "Password"),
                      keyboardType: TextInputType.visiblePassword,
                      initialValue: password,
                      onChanged: (value) => password = value,
                      validator: (value) {
                        const errorMessage = "Please enter a valid password";
                        if (value == null || value.isEmpty) return errorMessage;

                        return null;
                      },
                    ),
                    TextButton.icon(
                      onPressed: authorize,
                      icon: Icon(Icons.login),
                      label: Text("Login"),
                    ),
                    Visibility(
                      child: Text(errorMessage ?? "",
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge!
                              .copyWith(
                                  color: Theme.of(context).colorScheme.error)),
                      visible: errorMessage != null,
                    ),
                  ],
                ),
              ),
              visible: discoveryDocument != null,
            ),
            Visibility(
              child: identity == null ? Container() : IdentityView(identity!),
              visible: identity != null,
            ),
            Visibility(
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
                icon: Icon(Icons.logout),
                label: Text("Logout"),
              ),
              visible: identity != null,
            ),
          ],
        ),
      ),
    );
  }
}
