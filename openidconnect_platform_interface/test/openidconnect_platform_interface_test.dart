import 'package:flutter_test/flutter_test.dart';
import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';

import 'openidconnect_platform_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('allows overriding the platform instance', () {
    final mock = MockOpenIdConnectPlatform();

    OpenIdConnectPlatform.instance = mock;

    expect(OpenIdConnectPlatform.instance, same(mock));
  });
}
