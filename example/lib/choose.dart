import 'package:flutter/material.dart';
import 'device.dart';
import 'interactive.dart';
import 'password.dart';

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
