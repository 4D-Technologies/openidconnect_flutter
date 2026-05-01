import 'package:flutter_test/flutter_test.dart';
import 'package:openidconnect_darwin/openidconnect_darwin.dart';
import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';

void main() {
  test('registers Darwin implementation', () {
    OpenIdConnectDarwin.registerWith();

    expect(OpenIdConnectPlatform.instance, isA<OpenIdConnectDarwin>());
  });
}
