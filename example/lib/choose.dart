import 'package:flutter/material.dart';
import 'package:openidconnect_example/device.dart';
import 'package:openidconnect_example/interactive.dart';
import 'package:openidconnect_example/password.dart';

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
                MaterialPageRoute(
                  builder: (context) => InteractivePage(),
                ),
              ),
              child: Text("Interactive Authorization Code PKCE"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => DeviceCodePage(),
                ),
              ),
              child: Text("Device Code"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PasswordPage(),
                ),
              ),
              child: Text("Password"),
            ),
          ],
        ),
      ),
    );
  }
}
