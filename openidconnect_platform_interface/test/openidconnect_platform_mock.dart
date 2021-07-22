import 'package:flutter/services.dart';
import 'package:mockito/mockito.dart';
import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockMethodChannel extends Mock implements MethodChannel {}

class MockOpenIdConnectPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements OpenIdConnectPlatform {}
