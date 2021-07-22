import 'package:flutter/material.dart';
import 'package:openidconnect_example/choose.dart';

final defaultDiscoveryUrl =
    "https://account.dev.staccat.io/.well-known/openid-configuration";
final defaultClientId = "Admin";
final defaultClientSecret = "admin321!";
final defaultAudience = "api";
final defaultRedirectUrl = "http://localhost:50335/callback.html";
final defaultscopes = [
  "openid",
  "profile",
  "email",
  "address",
  "offline_access"
];

void main() {
  runApp(MyApp());
}

//Credentials gathered from the playground
//login: dull-moth@example.com
//password: Yawning-Octopus-58

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ChoosePage(),
    );
  }
}
