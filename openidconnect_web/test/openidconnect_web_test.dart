import 'package:flutter_test/flutter_test.dart';
import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';
import 'package:openidconnect_web/openidconnect_web.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('registers web implementation', () {
    OpenIdConnectPlatform.instance = OpenIdConnectWeb();

    expect(OpenIdConnectPlatform.instance, isA<OpenIdConnectWeb>());
  });
}
