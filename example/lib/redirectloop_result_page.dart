import 'package:flutter/material.dart';
import 'package:openidconnect/openidconnect.dart';

import 'identity_view.dart';
import 'credentials.dart';

class RedirectLoopResultPage extends StatefulWidget {
  @override
  _RedirectLoopResultPageState createState() => _RedirectLoopResultPageState();
}

class _RedirectLoopResultPageState extends State<RedirectLoopResultPage> {
  final _formKey = GlobalKey<FormState>();
  String discoveryUrl = defaultDiscoveryUrl;
  OpenIdConfiguration? discoveryDocument;
  AuthorizationResponse? identity;
  String? errorMessage = null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete startup'),
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
                child: TextButton.icon(
                  onPressed: () async {
                    try {
                      final response = await OpenIdConnect.processStartup(
                        clientId: defaultClientId,
                        clientSecret: defaultClientSecret,
                        scopes: defaultscopes,
                        configuration: discoveryDocument!,
                        redirectUrl: defaultRedirectUrl,
                        autoRefresh: true,
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
                  icon: Icon(Icons.loop),
                  label: Text("Process Startup loop"),
                ),
                visible: discoveryDocument != null,
              ),
              Visibility(
                child: identity == null ? Container() : IdentityView(identity!),
                visible: identity != null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
