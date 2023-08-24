// import 'package:flutter_test/flutter_test.dart';

// import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';

import 'openidconnect_platform_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final mock = MockOpenIdConnectPlatform();
  OpenIdConnectPlatform.instance = mock;

  //Run tests here
}
