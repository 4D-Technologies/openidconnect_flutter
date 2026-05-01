import 'package:flutter/widgets.dart';

import 'src/harness_adapter.dart';
import 'src/harness_controller.dart';
import 'src/test_harness_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    TestHarnessApp(
      controller: HarnessController(adapter: OpenIdConnectHarnessAdapter()),
    ),
  );
}
