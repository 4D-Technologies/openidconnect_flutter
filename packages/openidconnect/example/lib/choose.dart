import 'package:flutter/material.dart';
import 'package:openidconnect_example/client.dart';
import 'device.dart';
import 'interactive.dart';
import 'password.dart';
import 'redirectloop_result_page.dart';

class ChoosePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your OpenIdConnect Flow'),
      ),
      body: Center(
        child: Column(
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => InteractivePage(),
                ),
              ),
              child: Text("Interactive Authorization Code PKCE"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => DeviceCodePage(),
                ),
              ),
              child: Text("Device Code"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => PasswordPage(),
                ),
              ),
              child: Text("Password"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => ClientPage(),
                ),
              ),
              child: Text("Client Usage Example"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => RedirectLoopResultPage(),
                ),
              ),
              child: Text("Redirect Loop Result Page"),
            ),
          ],
        ),
      ),
    );
  }
}
