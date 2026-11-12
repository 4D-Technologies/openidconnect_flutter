import 'package:material_ui/material_ui.dart';
import 'package:openidconnect_example/client.dart';
import 'package:openidconnect_example/idp_picker.dart';

import 'device.dart';
import 'interactive.dart';
import 'password.dart';
import 'redirectloop_result_page.dart';

class ChoosePage extends StatelessWidget {
  const ChoosePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Your OpenIdConnect Flow')),
      body: Center(
        child: Column(
          children: [
            const IdpPicker(),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const InteractivePage(),
                ),
              ),
              child: const Text('Interactive Authorization Code PKCE'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const DeviceCodePage(),
                ),
              ),
              child: const Text('Device Code'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const PasswordPage(),
                ),
              ),
              child: const Text('Password'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const ClientPage(),
                ),
              ),
              child: const Text('Client Usage Example'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const RedirectLoopResultPage(),
                ),
              ),
              child: const Text('Redirect Loop Result Page'),
            ),
          ],
        ),
      ),
    );
  }
}
