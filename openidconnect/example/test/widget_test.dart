import 'package:flutter_test/flutter_test.dart';

import 'package:openidconnect_example/main.dart';

void main() {
  testWidgets('renders the chooser screen', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());

    expect(find.text('Choose Your OpenIdConnect Flow'), findsOneWidget);
    expect(find.text('Interactive Authorization Code PKCE'), findsOneWidget);
    expect(find.text('Device Code'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Client Usage Example'), findsOneWidget);
    expect(find.text('Redirect Loop Result Page'), findsOneWidget);
  });
}
