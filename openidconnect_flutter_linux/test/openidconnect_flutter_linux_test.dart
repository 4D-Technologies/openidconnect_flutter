import 'package:flutter_test/flutter_test.dart';
import 'package:openidconnect_flutter_linux/openidconnect_flutter_linux.dart';
import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';

void main() {
  test('registers Linux implementation', () {
    OpenIdConnectLinux.registerWith();

    expect(OpenIdConnectPlatform.instance, isA<OpenIdConnectLinux>());
  });
}
