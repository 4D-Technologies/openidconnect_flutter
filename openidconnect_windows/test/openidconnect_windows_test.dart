import 'package:flutter_test/flutter_test.dart';
import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';
import 'package:openidconnect_windows/openidconnect_windows.dart';

void main() {
  test('registers Windows implementation', () {
    OpenIdConnectWindows.registerWith();

    expect(OpenIdConnectPlatform.instance, isA<OpenIdConnectWindows>());
  });
}
