import 'package:flutter_test/flutter_test.dart';

import 'package:openidconnect_example/main.dart';

void main() {
  testWidgets('renders the chooser screen with the Duende demo IdP', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Choose Your OpenIdConnect Flow'), findsOneWidget);
    expect(find.text('Identity provider'), findsOneWidget);
    expect(find.text('Duende IdentityServer demo'), findsOneWidget);
    expect(find.text('Choose IdP'), findsOneWidget);
    expect(find.text('Add IdP'), findsOneWidget);

    await tester.tap(find.text('Choose IdP'));
    await tester.pumpAndSettle();
    expect(find.text('SondaHub OIDC playground'), findsOneWidget);
    await tester.tap(find.text('SondaHub OIDC playground'));
    await tester.pumpAndSettle();
    expect(find.text('SondaHub OIDC playground'), findsOneWidget);
    expect(find.text('Interactive Authorization Code PKCE'), findsOneWidget);
    expect(find.text('Device Code'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Client Usage Example'), findsOneWidget);
    expect(find.text('Redirect Loop Result Page'), findsOneWidget);
  });
}
