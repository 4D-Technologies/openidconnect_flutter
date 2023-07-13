import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:openidconnect/openidconnect.dart';
import 'credentials.dart';

import 'identity_view.dart';

class InteractivePage extends StatefulWidget {
  @override
  _InteractivePageState createState() => _InteractivePageState();
}

class _InteractivePageState extends State<InteractivePage> {
  final _formKey = GlobalKey<FormState>();

  String discoveryUrl = defaultDiscoveryUrl;
  OpenIdConfiguration? discoveryDocument;
  AuthorizationResponse? identity;
  bool usePopup = true;

  String? errorMessage = null;

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
                onPressed: () async {
                  _formKey.currentState!.save();
                  if (!_formKey.currentState!.validate()) return;

                  try {
                    final configuration =
                        await OpenIdConnect.getConfiguration(discoveryUrl);
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
                },
                icon: Icon(Icons.search),
                label: Text("Lookup OpenId Connect Configuration"),
              ),
              Visibility(
                child: SwitchListTile.adaptive(
                  value: usePopup,
                  title: Text("Use Web Popup"),
                  onChanged: (value) {
                    setState(() {
                      usePopup = value;
                    });
                  },
                ),
                visible: kIsWeb,
              ),
              Visibility(
                child: TextButton.icon(
                  onPressed: () async {
                    try {
                      final response = await OpenIdConnect.authorizeInteractive(
                        context: context,
                        title: "Login",
                        request: await InteractiveAuthorizationRequest.create(
                          clientId: defaultClientId,
                          clientSecret: defaultClientSecret,
                          redirectUrl: defaultRedirectUrl,
                          scopes: defaultscopes,
                          configuration: discoveryDocument!,
                          autoRefresh: false,
                          useWebPopup: usePopup,
                        ),
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
                  },
                  icon: Icon(Icons.login),
                  label: Text("Login"),
                ),
                visible: discoveryDocument != null,
              ),
              Visibility(
                child: identity == null ? Container() : IdentityView(identity!),
                visible: identity != null,
              ),
              Visibility(
                child: SelectableText(errorMessage ?? ""),
                visible: errorMessage != null,
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
      ),
    );
  }
}
