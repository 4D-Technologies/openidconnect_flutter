import 'package:flutter_test/flutter_test.dart';

import 'package:openidconnect/openidconnect.dart';

const TEST_ID_TOKEN =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c";

void main() {
  group("openididentity", () {
    test("save identity", () async {
      final identity = OpenIdIdentity(
        accessToken: "testing_access_token",
        expiresAt: DateTime.now(),
        idToken: TEST_ID_TOKEN,
        tokenType: "Bearer",
      );

      await identity.save();
    });

    test("load identity", () async {
      final identity = OpenIdIdentity(
        accessToken: "testing_access_token",
        expiresAt: DateTime.now(),
        idToken: TEST_ID_TOKEN,
        tokenType: "Bearer",
      );

      await identity.save();

      final loaded = await OpenIdIdentity.load();
      expect(loaded, isNot(null));
    });
  });
}
