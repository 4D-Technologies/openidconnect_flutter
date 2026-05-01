import 'package:flutter_test/flutter_test.dart';
import 'package:openidconnect_android/openidconnect_android.dart';
import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';

void main() {
  test('registers Android implementation', () {
    OpenIdConnectAndroid.registerWith();

    expect(OpenIdConnectPlatform.instance, isA<OpenIdConnectAndroid>());
  });
}
